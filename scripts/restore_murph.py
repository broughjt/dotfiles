#!/usr/bin/env python3
"""Restore murph backup files."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Any, Iterable, NoReturn

USER_UID = 1000
USERS_GID = 100


def die(message: str) -> NoReturn:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def chown_tree(path: Path, uid: int, gid: int) -> None:
    if not path.exists():
        return
    try:
        os.lchown(path, uid, gid)
    except OSError:
        pass
    if not path.is_dir() or path.is_symlink():
        return
    for root, dirs, files in os.walk(path):
        root_path = Path(root)
        for name in dirs:
            try:
                os.lchown(root_path / name, uid, gid)
            except OSError:
                pass
        for name in files:
            try:
                os.lchown(root_path / name, uid, gid)
            except OSError:
                pass


def chmod_existing(paths: Iterable[Path], mode: int) -> None:
    for path in paths:
        try:
            if path.exists() or path.is_symlink():
                os.chmod(path, mode)
        except OSError:
            pass


def main() -> None:
    try:
        bundles_path = Path(os.environ["MURPH_BUNDLES_JSON"])
    except KeyError as error:
        die(f"could not read bundle path from environment: {error}")

    try:
        bundles: dict[str, dict[str, Any]] = json.loads(bundles_path.read_text())
    except OSError as error:
        die(f"could not read bundle definitions from {bundles_path}: {error}")
    except json.JSONDecodeError as error:
        die(f"could not parse bundle definitions from {bundles_path}: {error}")

    parser = argparse.ArgumentParser(
        prog="restore-murph",
        description="Restore murph backup files.",
    )
    parser.add_argument(
        "--bundle",
        required=True,
        action="append",
        nargs=2,
        metavar=("NAME", "ARCHIVE"),
        help="state bundle and archive to restore; may be specified multiple times",
    )
    parser.add_argument(
        "mountpoint",
        type=Path,
        nargs="?",
        default=Path("/mnt"),
        help="installed system mountpoint (default: /mnt)",
    )
    args = parser.parse_args()

    seen: set[str] = set()
    specs: list[tuple[str, dict[str, Any], Path]] = []
    for bundle_name, archive_text in args.bundle:
        if bundle_name not in bundles:
            die(
                f"unknown bundle {bundle_name!r}; expected one of: "
                + ", ".join(sorted(bundles))
            )
        if bundle_name in seen:
            die(f"bundle specified more than once: {bundle_name}")
        seen.add(bundle_name)
        specs.append((bundle_name, bundles[bundle_name], Path(archive_text)))

    if os.geteuid() != 0:
        die("run as root so restored files can be owned and permissioned correctly")

    required_commands = {"tar"}
    if any(bundle["encrypted"] for _, bundle, _ in specs):
        required_commands.add("age")
    missing_commands = [command for command in sorted(required_commands) if shutil.which(command) is None]
    if missing_commands:
        die("missing required command(s) on PATH: " + ", ".join(missing_commands))

    persist = args.mountpoint / "persist"
    if not persist.is_dir():
        die(f"persist directory does not exist: {persist}")

    for _, _, archive in specs:
        if not archive.is_file():
            die(f"archive does not exist: {archive}")

    for bundle_name, bundle, archive in specs:
        if bundle["encrypted"]:
            print(f"info: decrypting and extracting {bundle_name} archive {archive} into {persist}")
            age = subprocess.Popen(["age", "--decrypt", str(archive)], stdout=subprocess.PIPE)
            assert age.stdout is not None
            tar = subprocess.Popen(
                ["tar", "--extract", "--gzip", "--file", "-", "--directory", str(persist)],
                stdin=age.stdout,
            )
            age.stdout.close()
            tar_status = tar.wait()
            age_status = age.wait()
            if age_status != 0 or tar_status != 0:
                die(f"{bundle_name} restore failed (age={age_status}, tar={tar_status})")
        else:
            print(f"info: extracting {bundle_name} archive {archive} into {persist}")
            subprocess.run(
                ["tar", "--extract", "--gzip", "--file", str(archive), "--directory", str(persist)],
                check=True,
            )

    chown_tree(persist / "home/jackson", USER_UID, USERS_GID)
    for bundle_name, bundle, _ in specs:
        restore = bundle["restore"]
        chmod_existing((persist / path for path in restore["directories_0700"]), 0o700)
        chmod_existing((persist / path for path in restore["files_0600"]), 0o600)
        chmod_existing((persist / path for path in restore["files_0644"]), 0o644)

        if bundle_name == "secrets-essential":
            ssh_dir = persist / "etc/ssh"
            if ssh_dir.exists():
                chown_tree(ssh_dir, 0, 0)
                chmod_existing(ssh_dir.glob("ssh_host_*_key"), 0o600)
                chmod_existing(ssh_dir.glob("ssh_host_*_key.pub"), 0o644)

        if bundle_name == "secrets-extra":
            oauth_dir = persist / "home/jackson/local/secrets/pi/mcp-oauth"
            if oauth_dir.exists():
                chmod_existing(oauth_dir.rglob("tokens.json"), 0o600)

            claude_credentials_dir = persist / "home/jackson/local/secrets/claude-code/credentials"
            if claude_credentials_dir.exists():
                chmod_existing((path for path in claude_credentials_dir.rglob("*") if path.is_file()), 0o600)

            claude_state_dir = persist / "home/jackson/local/state/claude-code"
            if claude_state_dir.exists():
                chmod_existing((path for path in claude_state_dir.rglob("*") if path.is_dir()), 0o700)
                chmod_existing((path for path in claude_state_dir.rglob("*") if path.is_file()), 0o600)

    restored = ", ".join(bundle_name for bundle_name, _, _ in specs)
    print(f"info: restore complete for {restored}")


if __name__ == "__main__":
    main()
