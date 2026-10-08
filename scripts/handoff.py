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
START = "start.toml"
CHECKS = "checks.toml"
ARCHIVE_TAG_PREFIX = "archive/"
DEFAULT_TIMEOUT = 60.0
OUTPUT_LINES = 20
STATE_FILES = ("arc.md", "tasks.md", "do-not-reopen.md", "open-questions.md", "review.md")


@dataclass(frozen=True)
class ReadFirst:
    path: str
    reason: str


@dataclass(frozen=True)
class Start:
    next: str
    workflow: str
    read_first: tuple[ReadFirst, ...]


def parse_start(data: dict) -> Start:
    def fields(table: dict, required: set[str], context: str) -> None:
        if not isinstance(table, dict):
            raise ValueError(f"{context} must be a table")
        if set(table) != required:
            raise ValueError(f"{context} requires exactly these fields: {', '.join(sorted(required))}")

    def text(value: object, context: str) -> str:
        if not isinstance(value, str) or not value.strip():
            raise ValueError(f"{context} must be a nonempty string")
        return value

    fields(data, {"next", "workflow", "read_first"}, "start")
    next_action = text(data["next"], "next")
    workflow = text(data["workflow"], "workflow")
    parse_reference(workflow)
    if not isinstance(data["read_first"], list):
        raise ValueError("read_first must be an array of tables")
    reads = []
    for index, entry in enumerate(data["read_first"]):
        context = f"read_first[{index}]"
        fields(entry, {"path", "reason"}, context)
        path = text(entry["path"], f"{context}.path")
        parse_reference(path)
        reads.append(ReadFirst(path, text(entry["reason"], f"{context}.reason")))
    return Start(next_action, workflow, tuple(reads))


def parse_reference(reference: str) -> tuple[str, Path]:
    scope, separator, relative = reference.partition(":")
    path = Path(relative)
    if (
        not separator or scope not in {"arc", "handoff", "project"}
        or not relative or path.is_absolute() or ".." in path.parts or not path.parts
    ):
        raise ValueError(f"{reference!r}: expected arc:, handoff: or project: followed by a relative file path without '..'")
    return scope, path


def resolve_reference(reference: str, arc: Path, repository: Path) -> Path:
    scope, relative = parse_reference(reference)
    if scope == "arc":
        root = arc
    elif scope == "handoff":
        root = repository
    else:
        # Discover the enclosing project, not the nested handoff repository.
        result = subprocess.run(
            ["git", "-C", str(repository.resolve().parent), "rev-parse", "--show-toplevel"],
            capture_output=True, text=True,
        )
        if result.returncode:
            raise ValueError(f"{reference}: no enclosing project repository found")
        root = Path(result.stdout.strip())
    return root / relative


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

    lint_parser = subparsers.add_parser(
        "lint",
        help="check arc structure without running predicates or changing files",
        description="Exits 0 for a valid arc, 1 for lint errors, 2 for usage errors.",
    )
    lint_parser.add_argument("arc", nargs="?", help="arc (optional when exactly one arc is active)")
    lint_parser.set_defaults(func=compose2(handle_lint, LintArguments.parse))

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
    arc_arguments: ArcArguments

    @staticmethod
    def parse(arguments: argparse.Namespace) -> Self:
        return CheckArguments(ArcArguments.parse(arguments))


def handle_check(arguments: CheckArguments) -> None:
    repository, arc = arguments.arc_arguments.repository, arguments.arc_arguments.arc
    checks_path = repository / arc / CHECKS
    try:
        with checks_path.open("rb") as file:
            checks = parse_checks(tomllib.load(file))
    except (OSError, ValueError) as error:
        die(f"{checks_path}: {error}")
    run = run_checks(checks)
    report(checks, run)
    ok = all(result.outcome is Outcome.TRUE for result in run.results.values())
    raise SystemExit(0 if ok else 1)


def parse_checks(data: dict) -> list[Check]:
    checks = list()
    for id, entry in data.items():
        if not isinstance(entry, dict):
            raise ValueError(f"{id} is not a table")
        unknown = set(entry) - {"claim", "run", "timeout"}
        if unknown:
            raise ValueError(f"{id} has unknown keys {', '.join(sorted(unknown))}")
        claim = entry.get("claim")
        if not isinstance(entry.get("claim"), str):
            raise ValueError(f"{id}: claim is not a string")
        run = entry.get("run")
        if not isinstance(entry.get("run"), str):
            raise ValueError(f"{id}: run is not a string")
        timeout = entry.get("timeout", DEFAULT_TIMEOUT)
        if (
            # hahah `isinstance(False, int)` evaluates to `True`
            isinstance(timeout, bool)
            or not isinstance(timeout, (int, float))
            or not math.isfinite(timeout)
            or timeout <= 0
        ):
            raise ValueError(f"{id} timeout must be a positive number of seconds")
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
    id_width = max([len("ID"), *(len(check.id) for check in checks)])
    claim_width = max([len("CLAIM"), *(len(check.claim) for check in checks)])
    duration_width = max([len("DURATION"), *(len(f"{result.duration:.1f}s") for result in run.results.values())])
    print(f"{'ID':<{id_width}}  {'CLAIM':<{claim_width}}  {'RESULT':<7}  {'DURATION':>{duration_width}}")
    for check in checks:
        result = run.results[check.id]
        duration = f"{result.duration:.1f}s"
        print(f"{check.id:<{id_width}}  {check.claim:<{claim_width}}  {result.outcome.value:<7}  {duration:>{duration_width}}")
        if result.outcome is Outcome.TIMEOUT:
            print(f"         after {check.timeout:g}s")
        elif result.outcome is not Outcome.TRUE:
            print(f"         exit {result.exit}")
        if result.outcome is not Outcome.TRUE and result.output:
            print("         output:")
            for line in result.output.splitlines()[-OUTPUT_LINES:]:
                print(f"           {line}")
    counts = {outcome: 0 for outcome in Outcome}
    for result in run.results.values():
        counts[result.outcome] += 1
    summary = ", ".join(f"{count} {outcome.value}" for outcome, count in counts.items() if count)
    print(f"\nhost: {run.host}, duration: {run.duration:.1f}s, summary: {summary or 'no checks'}")


# Lint


@dataclass(frozen=True)
class LintArguments:
    arc_arguments: ArcArguments

    @staticmethod
    def parse(arguments: argparse.Namespace) -> Self:
        return LintArguments(ArcArguments.parse(arguments))


@dataclass(frozen=True)
class Diagnostic:
    path: Path
    message: str


def handle_lint(arguments: LintArguments) -> None:
    repository, arc = arguments.arc_arguments.repository, arguments.arc_arguments.arc
    diagnostics = lint_arc(repository / arc)
    for diagnostic in diagnostics:
        print(f"{diagnostic.path}: {diagnostic.message}")
    print(f"{arc}: {len(diagnostics)} lint errors")
    raise SystemExit(1 if diagnostics else 0)


def lint_arc(arc: Path, repository: Path | None = None) -> list[Diagnostic]:
    """Check working-tree structure; prose and results schemas remain unvalidated."""
    diagnostics = []
    repository = repository or arc.parent

    def require_file(path: Path) -> bool:
        if path.is_file():
            return True
        diagnostics.append(Diagnostic(path, "expected a regular file"))
        return False

    for name in STATE_FILES:
        require_file(arc / name)
    start_path = arc / START
    if require_file(start_path):
        try:
            with start_path.open("rb") as file:
                start = parse_start(tomllib.load(file))
        except (OSError, ValueError) as error:
            diagnostics.append(Diagnostic(start_path, str(error)))
        else:
            for reference in (start.workflow, *(read.path for read in start.read_first)):
                try:
                    path = resolve_reference(reference, arc, repository)
                    if not path.is_file():
                        diagnostics.append(Diagnostic(start_path, f"{reference}: expected a regular file at {path}"))
                except (OSError, ValueError) as error:
                    diagnostics.append(Diagnostic(start_path, str(error)))
    checks_path = arc / CHECKS
    if require_file(checks_path):
        try:
            with checks_path.open("rb") as file:
                parse_checks(tomllib.load(file))
        except (OSError, ValueError) as error:
            diagnostics.append(Diagnostic(checks_path, str(error)))

    log = arc / "log"
    if not log.exists():
        return diagnostics  # A new arc doesn't need to have a log yet.
    if not log.is_dir():
        diagnostics.append(Diagnostic(log, "expected a directory"))
        return diagnostics

    try:
        entries = sorted(log.iterdir())
    except OSError as error:
        diagnostics.append(Diagnostic(log, str(error)))
        return diagnostics
    for entry in entries:
        name = entry.name
        # We need to check that the string is ASCII because `isdigit` accepts
        # Unicode digits. For example, superscript ² satisfies `isdigit` but
        # int("²") fails.
        if not (name.isascii() and name.isdigit()):
            diagnostics.append(Diagnostic(entry, "expected a positive numeric checkpoint directory name"))
            continue
        # Ah, a typical canonicity problem of string representations of data
        # types: "1" and "01" both represent 1. To avoid this, we require the
        # absence of leading zeros.
        if name.startswith("0"):
            diagnostics.append(Diagnostic(entry, "expected a positive checkpoint number without leading zeros"))
            continue
        if not entry.is_dir():
            diagnostics.append(Diagnostic(entry, "expected a directory"))
            continue
        require_file(entry / "entry.md")
        results_path = entry / "results.toml"
        if require_file(results_path):
            try:
                with results_path.open("rb") as file:
                    tomllib.load(file)
            except (OSError, ValueError) as error:
                diagnostics.append(Diagnostic(results_path, str(error)))

    return diagnostics


# Utilities


@dataclass(frozen=True)
class ArcArguments:
    repository: Path
    arc: str

    @staticmethod
    def parse(arguments: argparse.Namespace) -> Self:
        global_arguments = GlobalArguments.parse(arguments)
        repository = global_arguments.repository

        # Explicit names select directories; consumers validate their contents.
        if arguments.arc is not None:
            arc_name = arguments.arc
            if not arc_name or arc_name in (".", "..", ".git") or Path(arc_name).name != arc_name:
                die("specify a top-level arc directory name")
            if not (repository / arc_name).is_dir():
                die(f"{arc_name} is not a directory in {repository}")
            return ArcArguments(repository, arc_name)

        match list_arcs(repository):
            case []:
                die("there are no active arcs")
            case [a]:
                arc = a
            case arcs:
                die(f"specify the arc; active arcs: {', '.join(arcs)}")

        return ArcArguments(repository, arc)


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
    result = subprocess.run(
        ["git", "-C", str(path), "rev-parse", "--show-toplevel"],
        capture_output=True, text=True,
    )
    return result.returncode == 0 and Path(result.stdout.strip()).resolve() == path.resolve()


# Run the thing


if __name__ == "__main__":
    main()
