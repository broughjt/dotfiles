#!/usr/bin/env python3
"""Restore murph SSH and GnuPG secrets."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Iterable, NoReturn

USER_UID = 1000
USERS_GID = 100
SYSTEM_SSH_HOST_KEY_FILES = [
    "ssh_host_ed25519_key",
    "ssh_host_ed25519_key.pub",
    "ssh_host_rsa_key",
    "ssh_host_rsa_key.pub",
]


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


def chown_existing(paths: Iterable[Path], uid: int, gid: int) -> None:
    for path in paths:
        try:
            if path.exists() or path.is_symlink():
                os.lchown(path, uid, gid)
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
        prog="restore-murph-secrets",
        description="Restore murph SSH and GnuPG secrets.",
    )
    parser.add_argument("archive", type=Path, help="murph secrets archive created by backup-murph-secrets")
    parser.add_argument(
        "mountpoint",
        type=Path,
        nargs="?",
        default=Path("/mnt"),
        help="installed system mountpoint (default: /mnt)",
    )
    args = parser.parse_args()

    if os.geteuid() != 0:
        die("run as root so restored files can be owned and permissioned correctly")

    missing_commands = [command for command in ("age", "tar") if shutil.which(command) is None]
    if missing_commands:
        die("missing required command(s) on PATH: " + ", ".join(missing_commands))

    persist = args.mountpoint / "persist"
    if not persist.is_dir():
        die(f"persist directory does not exist: {persist}")
    if not args.archive.is_file():
        die(f"archive does not exist: {args.archive}")

    print(f"info: decrypting and extracting secrets archive {args.archive} into {persist}")
    age = subprocess.Popen(["age", "--decrypt", str(args.archive)], stdout=subprocess.PIPE)
    assert age.stdout is not None
    tar = subprocess.Popen(
        ["tar", "--extract", "--gzip", "--file", "-", "--directory", str(persist)],
        stdin=age.stdout,
    )
    age.stdout.close()
    tar_status = tar.wait()
    age_status = age.wait()
    if age_status != 0 or tar_status != 0:
        die(f"secrets restore failed (age={age_status}, tar={tar_status})")

    home_dir = persist / "home/jackson"
    local_dir = home_dir / "local"
    secrets_dir = local_dir / "secrets"
    ssh_secrets_dir = secrets_dir / "ssh"
    gpg_secrets_dir = secrets_dir / "gnupg"

    chown_existing((home_dir, local_dir, secrets_dir), USER_UID, USERS_GID)
    chown_tree(ssh_secrets_dir, USER_UID, USERS_GID)
    chown_tree(gpg_secrets_dir, USER_UID, USERS_GID)

    chmod_existing(
        (
            persist / path
            for path in [
                "home/jackson/local/secrets",
                "home/jackson/local/secrets/ssh",
                "home/jackson/local/secrets/gnupg",
                "home/jackson/local/secrets/gnupg/private-keys-v1.d",
                "home/jackson/local/secrets/gnupg/openpgp-revocs.d",
            ]
        ),
        0o700,
    )
    if ssh_secrets_dir.exists():
        chmod_existing((path for path in ssh_secrets_dir.glob("*") if path.is_file()), 0o600)
        chmod_existing(ssh_secrets_dir.glob("*.pub"), 0o644)

    if gpg_secrets_dir.exists():
        chmod_existing((path for path in gpg_secrets_dir.rglob("*") if path.is_dir()), 0o700)
        chmod_existing((path for path in gpg_secrets_dir.rglob("*") if path.is_file()), 0o600)

    ssh_dir = persist / "etc/ssh"
    if ssh_dir.exists():
        chown_existing((ssh_dir,), 0, 0)
        chown_existing((ssh_dir / name for name in SYSTEM_SSH_HOST_KEY_FILES), 0, 0)
        chmod_existing((ssh_dir / name for name in SYSTEM_SSH_HOST_KEY_FILES if not name.endswith(".pub")), 0o600)
        chmod_existing((ssh_dir / name for name in SYSTEM_SSH_HOST_KEY_FILES if name.endswith(".pub")), 0o644)

    print("info: secrets restore complete")


if __name__ == "__main__":
    main()
