#!/usr/bin/env python3
"""Automation for the handoff skills."""

from __future__ import annotations

import argparse
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
import math
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import time
import tomllib
from typing import NoReturn, Self

REPOSITORY = Path(".scratch/handoff")
START = "start.md"
CHECKS = "checks.toml"
ARCHIVE_TAG_PREFIX = "archive/"
DEFAULT_TIMEOUT = 60.0
OUTPUT_LINES = 20


def main() -> None:
    parser = argparse.ArgumentParser(prog="handoff", description=__doc__)
    parser.add_argument(
        "--repository",
        type=Path,
        help=f"handoff repository to use instead of the nearest {REPOSITORY}/",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_parser = subparsers.add_parser("list", help="list active arcs")
    list_parser.add_argument("--archived", action="store_true", help="list archived arcs instead")
    list_parser.set_defaults(func=compose2(handle_list, ListArguments.parse))

    check_parser = subparsers.add_parser(
        "check",
        help=f"run {CHECKS} and report current results without writing files",
        description="Run read-only predicates. Exits 0 when every check is true, 1 otherwise; 2 for usage or checks-file errors.",
    )
    check_parser.add_argument("arc", nargs="?", help="arc (optional when exactly one arc is active)")
    check_parser.set_defaults(func=compose2(handle_check, CheckArguments.parse))

    arguments = parser.parse_args()
    arguments.func(arguments)


@dataclass(frozen=True)
class GlobalArguments:
    repository: Path

    @staticmethod
    def parse(arguments: argparse.Namespace) -> Self:
        repository = arguments.repository or find_repository(Path.cwd())
        if not is_git_repository(repository):
            die(f"{repository} is not a git repository")

        return GlobalArguments(repository)


# List


@dataclass(frozen=True)
class ListArguments:
    repository: Path
    archived: bool

    @staticmethod
    def parse(arguments: argparse.Namespace) -> Self:
        global_arguments = GlobalArguments.parse(arguments)

        archived = arguments.archived
        assert archived is not None

        return ListArguments(global_arguments.repository, archived)


def handle_list(arguments: ListArguments) -> None:
    repository, archived = arguments.repository, arguments.archived
    names = (list_arcs_archived if archived else list_arcs)(repository)
    for name in names:
        print(name)


# Check


@dataclass
class Run:
    host: str
    started: datetime
    duration: float = 0.0
    results: dict[str, Result] = field(default_factory=dict)


@dataclass(frozen=True)
class Result:
    outcome: Outcome
    duration: float
    output: str
    exit: int | None = None


class Outcome(Enum):
    TRUE = "true"
    FALSE = "false"
    UNKNOWN = "unknown"
    TIMEOUT = "timeout"


@dataclass(frozen=True)
class Check:
    id: str
    claim: str
    run: str
    timeout: float = DEFAULT_TIMEOUT


@dataclass(frozen=True)
class CheckArguments:
    repository: Path
    arc: str

    @staticmethod
    def parse(arguments: argparse.Namespace) -> Self:
        global_arguments = GlobalArguments.parse(arguments)
        repository = global_arguments.repository

        match (list_arcs(repository), arguments.arc):
            case ([], _):
                die("there are no active arcs")
            case ([a], None):
                arc = a
            case (arcs, None):
                die(f"specify the arc; active arcs: {', '.join(arcs)}")
            case (arcs, a) if a in arcs:
                arc = a
            case (arcs, a):
                die(f"{a} is not an active arc; active arcs: {', '.join(arcs)}")

        return CheckArguments(repository, arc)


def handle_check(arguments: CheckArguments) -> None:
    repository, arc = arguments.repository, arguments.arc
    checks_path = repository / arc / CHECKS
    if not checks_path.exists():
        die(f"{checks_path} does not exist")
    checks = load_checks(checks_path)
    run = run_checks(checks)
    report(checks, run)
    ok = all(result.outcome is Outcome.TRUE for result in run.results.values())
    raise SystemExit(0 if ok else 1)


def load_checks(path: Path) -> list[Check]:
    try:
        with path.open("rb") as file:
            data = tomllib.load(file)
    except (OSError, ValueError) as error:
        die(f"{path}: {error}")
    return parse_checks(data)


def parse_checks(data: dict) -> list[Check]:
    checks = list()
    for id, entry in data.items():
        if not isinstance(entry, dict):
            die(f"{id} is not a table")
        unknown = set(entry) - {"claim", "run", "timeout"}
        if unknown:
            die(f"{id} has unknown keys {', '.join(sorted(unknown))}")
        claim = entry.get("claim")
        if not isinstance(entry.get("claim"), str):
            die(f"{id}: claim is not a string")
        run = entry.get("run")
        if not isinstance(entry.get("run"), str):
            die(f"{id}: run is not a string")
        timeout = entry.get("timeout", DEFAULT_TIMEOUT)
        if (
            # hahah `isinstance(False, int)` evaluates to `True`
            isinstance(timeout, bool)
            or not isinstance(timeout, (int, float))
            or not math.isfinite(timeout)
            or timeout <= 0
        ):
            die(f"{id} timeout must be a positive number of seconds")
        checks.append(Check(id, claim, run, float(timeout)))
    return checks


def run_checks(checks: list[Check]) -> Run:
    run = Run(host=socket.gethostname(), started=datetime.now().astimezone().replace(microsecond=0))
    started = time.monotonic()
    for check in checks:
        run.results[check.id] = run_check(check)
    run.duration = time.monotonic() - started
    return run


def run_check(check: Check) -> Result:
    """Run one predicate. Exit 0 is true, exit 1 is false, a timeout is
    timeout, and any other exit code is unknown."""
    started = time.monotonic()
    # `start_new_session` so a timeout can kill the whole process group, not
    # just shell
    process = subprocess.Popen(
        ["bash", "-c", check.run],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        errors="replace",
        start_new_session=True,
    )
    try:
        output, _ = process.communicate(timeout=check.timeout)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        output, _ = process.communicate()
        return Result(Outcome.TIMEOUT, time.monotonic() - started, output)
    exit = process.returncode
    outcome = {0: Outcome.TRUE, 1: Outcome.FALSE}.get(exit, Outcome.UNKNOWN)
    return Result(outcome, time.monotonic() - started, output, exit)




def report(checks: list[Check], run: Run) -> None:
    """Report current outcomes, showing output only for non-true results."""
    width = max((len(check.id) for check in checks), default=0)
    for check in checks:
        result = run.results[check.id]
        print(f"{result.outcome.value:<7}  {check.id:<{width}}  {result.duration:5.1f}s  {check.claim}")
        if result.outcome is Outcome.TIMEOUT:
            print(f"         after {check.timeout:g}s")
        elif result.outcome is not Outcome.TRUE:
            print(f"         exit {result.exit}")
        if result.outcome is not Outcome.TRUE and result.output:
            print("         output:")
            # TODO: Tail here, not during `Result` construction
            for line in result.output.splitlines():
                print(f"           {line}")
    counts = {outcome: 0 for outcome in Outcome}
    for result in run.results.values():
        counts[result.outcome] += 1
    summary = ", ".join(f"{count} {outcome.value}" for outcome, count in counts.items() if count)
    print(f"{summary or 'no checks'}; {run.duration:.1f}s on {run.host}")


# Utilities


def compose2(g, f):
    return lambda x: g(f(x))


def die(message: str) -> NoReturn:
    print(f"handoff: {message}", file=sys.stderr)
    raise SystemExit(2)


def find_repository(path: Path) -> Path:
    """Starting from `path`, walk up the filesystem tree looking for a
    .scratch/handoff/ directory, similar to how git looks for a .git/ directory.

    Also works inside .scratch/handoff/ itself.
    """
    for directory in (path, *path.parents):
        if directory.parts[-2:] == REPOSITORY.parts and is_git_repository(directory):
            return directory
        candidate = directory / REPOSITORY
        if candidate.is_dir() and is_git_repository(candidate):
            return candidate
    die(f"no {REPOSITORY}/ at or above {path}")


def list_arcs(repository: Path) -> list[str]:
    """Get the list of active arcs, which we encode as top-level directories
    holding a start file."""
    return sorted(path.name for path in repository.iterdir() if is_arc(path))


def list_arcs_archived(repository: Path) -> list[str]:
    tags = subprocess.run(
        ["git", "-C", str(repository), "tag", "--list", f"{ARCHIVE_TAG_PREFIX}*"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.split()
    return sorted(tag.removeprefix(ARCHIVE_TAG_PREFIX) for tag in tags)


def is_arc(path: Path) -> bool:
    return path.is_dir() and (path / START).is_file()


def is_git_repository(path: Path) -> bool:
    # TODO: Apparently .git can be a file pointing elsewhere, so this probably
    # needs to become more sophisticated
    return (path / ".git").is_dir()


def tail(output: str) -> str:
    return "\n".join(output.splitlines()[-OUTPUT_LINES:])


# Run the thing


if __name__ == "__main__":
    main()
