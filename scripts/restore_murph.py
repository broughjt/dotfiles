#!/usr/bin/env python3
"""Restore explicit murph state backup bundles."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Iterable, NoReturn

BUNDLES = {
    "secrets": {
        "encrypted": True,
        "directories_0700": [
            "home/jackson/local/secrets",
            "home/jackson/local/secrets/ssh",
            "home/jackson/local/secrets/pi",
            "home/jackson/local/secrets/pi/auth",
            "home/jackson/local/secrets/pi/mcp",
            "home/jackson/local/secrets/pi/mcp-oauth",
            "home/jackson/local/secrets/gnupg",
            "home/jackson/local/secrets/gnupg/private-keys-v1.d",
            "home/jackson/local/secrets/gnupg/openpgp-revocs.d",
            "home/jackson/local/state/gnupg",
            "home/jackson/local/share/keyrings",
            "home/jackson/local/config/discord",
            "home/jackson/local/config/Slack",
            "home/jackson/local/config/spotify",
        ],
        "files_0600": [
            "home/jackson/local/secrets/ssh/id_ed25519",
            "home/jackson/local/secrets/pi/auth/auth.json",
            "home/jackson/local/secrets/pi/mcp/mcp.json",
        ],
        "files_0644": [
            "home/jackson/local/secrets/ssh/id_ed25519.pub",
        ],
    },
    "convenience": {
        "encrypted": False,
        "directories_0700": [
            "home/jackson/local/config/mozilla/firefox",
            "home/jackson/local/hacks/fish/fish_history",
            "home/jackson/local/hacks/ssh/known_hosts",
            "home/jackson/local/hacks/gh/hosts",
            "home/jackson/local/hacks/tmux/resurrect",
            "home/jackson/local/hacks/tmux/resurrect/resurrect",
            "home/jackson/local/hacks/emacs/projects",
            "home/jackson/local/hacks/pi/settings",
            "home/jackson/local/state/emacs/backups",
            "home/jackson/local/state/emacs/auto-saves",
            "home/jackson/local/state/pi/sessions",
            "home/jackson/local/state/pi/mcp",
            "home/jackson/local/share/direnv/allow",
            "home/jackson/local/share/direnv/deny",
        ],
        "files_0600": [
            "home/jackson/local/hacks/ssh/known_hosts/known_hosts",
            "home/jackson/local/hacks/fish/fish_history/fish_history",
            "home/jackson/local/hacks/gh/hosts/hosts.yml",
            "home/jackson/local/hacks/emacs/projects/projects.eld",
            "home/jackson/local/hacks/pi/settings/settings.json",
            "home/jackson/local/state/pi/mcp/mcp-cache.json",
            "home/jackson/local/state/pi/mcp/mcp-onboarding.json",
            "home/jackson/local/state/pi/mcp/settings-package-seeded",
        ],
        "files_0644": [],
    },
}

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
    parser = argparse.ArgumentParser(
        prog="restore-murph",
        description="Restore explicit murph state backup bundles.",
    )
    parser.add_argument(
        "--bundle",
        required=True,
        choices=sorted(BUNDLES),
        help="state bundle to restore",
    )
    parser.add_argument("archive", type=Path, help="archive created by backup-murph")
    parser.add_argument(
        "mountpoint",
        type=Path,
        nargs="?",
        default=Path("/mnt"),
        help="installed system mountpoint (default: /mnt)",
    )
    args = parser.parse_args()

    bundle = BUNDLES[args.bundle]
    encrypted = bundle["encrypted"]

    if os.geteuid() != 0:
        die("run as root so restored files can be owned and permissioned correctly")

    required_commands = ["tar"] + (["age"] if encrypted else [])
    missing_commands = [command for command in required_commands if shutil.which(command) is None]
    if missing_commands:
        die("missing required command(s) on PATH: " + ", ".join(missing_commands))

    archive: Path = args.archive
    persist = args.mountpoint / "persist"
    if not archive.is_file():
        die(f"archive does not exist: {archive}")
    if not persist.is_dir():
        die(f"persist directory does not exist: {persist}")

    if encrypted:
        print(f"info: decrypting and extracting {archive} into {persist}")
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
            die(f"restore failed (age={age_status}, tar={tar_status})")
    else:
        print(f"info: extracting {archive} into {persist}")
        subprocess.run(
            ["tar", "--extract", "--gzip", "--file", str(archive), "--directory", str(persist)],
            check=True,
        )

    chown_tree(persist / "home/jackson", USER_UID, USERS_GID)
    chmod_existing((persist / path for path in bundle["directories_0700"]), 0o700)
    chmod_existing((persist / path for path in bundle["files_0600"]), 0o600)
    chmod_existing((persist / path for path in bundle["files_0644"]), 0o644)

    if args.bundle == "secrets":
        oauth_dir = persist / "home/jackson/local/secrets/pi/mcp-oauth"
        if oauth_dir.exists():
            chmod_existing(oauth_dir.rglob("tokens.json"), 0o600)

        ssh_dir = persist / "etc/ssh"
        if ssh_dir.exists():
            chown_tree(ssh_dir, 0, 0)
            chmod_existing(ssh_dir.glob("ssh_host_*_key"), 0o600)
            chmod_existing(ssh_dir.glob("ssh_host_*_key.pub"), 0o644)

    print(f"info: {args.bundle} restore complete")


if __name__ == "__main__":
    main()
