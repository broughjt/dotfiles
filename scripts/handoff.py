#!/usr/bin/env python3
"""Automation for the handoff skills."""

from __future__ import annotations

import argparse
import sys

SUBCOMMANDS = ("start", "check", "log", "lint", "commit", "archive", "show")


def main() -> None:
    parser = argparse.ArgumentParser(prog="handoff", description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    for name in SUBCOMMANDS:
        subparsers.add_parser(name)
    arguments = parser.parse_args()
    print(f"handoff {arguments.command}: not implemented", file=sys.stderr)
    raise SystemExit(2)


if __name__ == "__main__":
    main()
