#!/usr/bin/env python3
"""Mechanics for handoff repositories: read, check and render arcs."""

from __future__ import annotations

import argparse
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import time
import tomllib
from typing import NoReturn

import tomli_w

REPOSITORY = Path(".scratch/handoff")
START = "start.md"
CHECKS = "checks.toml"
RESULTS = "results.toml"
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
    list_parser.set_defaults(func=command_list)

    check_parser = subparsers.add_parser(
        "check",
        help=f"run {CHECKS}, write {RESULTS}, and report differences since last run",
        description="Exits 0 when every check is true, 1 otherwise.",
    )
    check_parser.add_argument("arc", nargs="?", help="arc (optional when exactly one arc is active)")
    check_parser.set_defaults(func=command_check)

    arguments = parser.parse_args()
    if arguments.repository is None:
        arguments.repository = find_repository(Path(os.getcwd()))
    elif not arguments.repository.is_dir():
        die(f"{arguments.repository} is not a directory")
    arguments.func(arguments)


# List


def command_list(arguments: argparse.Namespace) -> None:
    names = (archived_arcs if arguments.archived else arcs)(arguments.repository)
    for name in names:
        print(name)


# Check


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
class Result:
    outcome: Outcome
    duration: float
    output: str
    exit: int | None = None


@dataclass
class Run:
    host: str
    started: datetime
    duration: float = 0.0
    results: dict[str, Result] = field(default_factory=dict)


def command_check(arguments: argparse.Namespace) -> None:
    arc = resolve_arc(arguments.repository, arguments.arc)
    checks = load_checks(arc / CHECKS)
    previous = committed_results(arguments.repository, arc.name)
    run = run_checks(checks)
    write_results(arc / RESULTS, run)
    report(checks, run, previous)
    ok = all(result.outcome is Outcome.TRUE for result in run.results.values())
    raise SystemExit(0 if ok else 1)


def resolve_arc(repository: Path, name: str | None) -> Path:
    if name is None:
        active = arcs(repository)
        if len(active) != 1:
            die(f"name the arc; active arcs: {', '.join(active) or 'none'}")
        name = active[0]
    arc = repository / name
    if not arc.is_dir():
        die(f"no arc {name} in {repository}")
    return arc


def load_checks(path: Path) -> list[Check]:
    if not path.is_file():
        die(f"no {path}")
    try:
        document = tomllib.loads(path.read_text())
    except tomllib.TOMLDecodeError as error:
        die(f"{path}: {error}")
    checks = []
    for id, entry in document.items():
        if not isinstance(entry, dict):
            die(f"{path}: {id} is not a table")
        unknown = set(entry) - {"claim", "run", "timeout"}
        if unknown:
            die(f"{path}: {id} has unknown keys {', '.join(sorted(unknown))}")
        for key in ("claim", "run"):
            if not isinstance(entry.get(key), str):
                die(f"{path}: {id} needs a string {key}")
        timeout = entry.get("timeout", DEFAULT_TIMEOUT)
        if not isinstance(timeout, (int, float)) or timeout <= 0:
            die(f"{path}: {id} timeout must be a positive number of seconds")
        checks.append(Check(id, entry["claim"], entry["run"], float(timeout)))
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
    # A new session so a timeout can kill the whole process group, not just
    # the shell; an ssh left behind would otherwise keep the pipe open.
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
        return Result(Outcome.TIMEOUT, time.monotonic() - started, tail(output))
    exit = process.returncode
    outcome = {0: Outcome.TRUE, 1: Outcome.FALSE}.get(exit, Outcome.UNKNOWN)
    return Result(outcome, time.monotonic() - started, tail(output), exit)


def tail(output: str) -> str:
    return "\n".join(output.splitlines()[-OUTPUT_LINES:])


def write_results(path: Path, run: Run) -> None:
    document = {
        "run": {
            "host": run.host,
            "started": run.started,
            "duration": round(run.duration, 2),
        },
        "checks": {
            id: {
                "result": result.outcome.value,
                **({} if result.exit is None else {"exit": result.exit}),
                "duration": round(result.duration, 2),
                "output": result.output,
            }
            for id, result in run.results.items()
        },
    }
    path.write_text(tomli_w.dumps(document, multiline_strings=True))


def committed_results(repository: Path, name: str) -> Run | None:
    """The results file as of the last commit, which is what "previous
    results" means: an uncommitted file in the working tree is a run that
    handoff-update has not recorded yet."""
    shown = subprocess.run(
        ["git", "-C", str(repository), "show", f"HEAD:{name}/{RESULTS}"],
        capture_output=True,
        text=True,
    )
    if shown.returncode != 0:
        return None
    document = tomllib.loads(shown.stdout)
    run = Run(host=document["run"]["host"], started=document["run"]["started"], duration=document["run"]["duration"])
    for id, entry in document["checks"].items():
        run.results[id] = Result(Outcome(entry["result"]), entry["duration"], entry["output"], entry.get("exit"))
    return run


def report(checks: list[Check], run: Run, previous: Run | None) -> None:
    """One line per check. Output is shown only for a check that is not true
    or has flipped since the last commit, because for a check that
    still holds, a changed output is noise (timestamps, PIDs)."""
    if previous is not None:
        print(f"previous results: {previous.host}, {previous.started:%Y-%m-%d %H:%M}")
    width = max(len(check.id) for check in checks)
    for check in checks:
        result = run.results[check.id]
        before = previous.results.get(check.id) if previous is not None else None
        print(f"{result.outcome.value:<7}  {check.id:<{width}}  {result.duration:5.1f}s  {check.claim}")
        flipped = before is not None and before.outcome is not result.outcome
        notes = []
        if flipped:
            notes.append(f"was {before.outcome.value} on {previous.started:%Y-%m-%d}")
        elif before is None and previous is not None:
            notes.append("new since the last commit")
        if result.outcome is Outcome.TIMEOUT:
            notes.append(f"after {check.timeout:g}s")
        elif result.outcome is Outcome.UNKNOWN:
            notes.append(f"exit {result.exit}")
        for note in notes:
            print(f"         {note}")
        if flipped and before.output:
            print_block("before:", before.output)
        if (flipped or result.outcome is not Outcome.TRUE) and result.output:
            print_block("after:" if flipped else "output:", result.output)
    counts = {outcome: 0 for outcome in Outcome}
    for result in run.results.values():
        counts[result.outcome] += 1
    summary = ", ".join(f"{count} {outcome.value}" for outcome, count in counts.items() if count)
    print(f"{summary or 'no checks'}; {run.duration:.1f}s on {run.host}")


def print_block(label: str, text: str) -> None:
    print(f"         {label}")
    for line in text.splitlines():
        print(f"           {line}")


# Utilities


def die(message: str) -> NoReturn:
    print(f"handoff: {message}", file=sys.stderr)
    raise SystemExit(2)


def find_repository(path: Path) -> Path:
    """Starting from `path`, walk up the filesystem tree looking for a
    .scratch/handoff/ directory, similar to how git looks for a .git/ directory.

    Also works inside .scratch/handoff/ itself.
    """
    for directory in (path, *path.parents):
        if directory.parts[-2:] == REPOSITORY.parts:
            return directory
        candidate = directory / REPOSITORY
        if candidate.is_dir():
            return candidate
    die(f"no {REPOSITORY}/ at or above {path}")


def arcs(repository: Path) -> list[str]:
    """Get the list of active arcs, which we encode as top-level directories
    holding a start file."""
    return sorted(
        child.name
        for child in repository.iterdir()
        if child.is_dir() and (child / START).is_file()
    )


def archived_arcs(repository: Path) -> list[str]:
    tags = subprocess.run(
        ["git", "-C", str(repository), "tag", "--list", f"{ARCHIVE_TAG_PREFIX}*"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.split()
    return sorted(tag.removeprefix(ARCHIVE_TAG_PREFIX) for tag in tags)


# Run the thing

if __name__ == "__main__":
    main()
