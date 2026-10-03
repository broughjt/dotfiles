#!/usr/bin/env python3
"""Mechanics for handoff repositories: read, check and render arcs."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import subprocess
import sys
from typing import NoReturn

REPOSITORY = Path(".scratch/handoff")
START = "start.md"
ARCHIVE_TAG_PREFIX = "archive/"


def main() -> None:
    parser = argparse.ArgumentParser(prog="handoff", description=__doc__)
    parser.add_argument(
        "--repository",
        type=Path,
        help=f"handoff repository to use instead of the nearest {REPOSITORY}/",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_parser = subparsers.add_parser("list", help="list active arcs, one slug per line")
    list_parser.add_argument("--archived", action="store_true", help="list archived arcs instead")
    list_parser.set_defaults(func=command_list)

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


# Utilities


def die(message: str) -> NoReturn:
    print(f"handoff: {message}", file=sys.stderr)
    raise SystemExit(1)


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
