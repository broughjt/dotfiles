#!/usr/bin/env python3
"""Back up murph SSH and GnuPG secrets."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
from typing import NoReturn

PERSIST = Path("/persist")
BACKUP_PATHS = [
    "etc/ssh/ssh_host_ed25519_key",
    "etc/ssh/ssh_host_ed25519_key.pub",
    "etc/ssh/ssh_host_rsa_key",
    "etc/ssh/ssh_host_rsa_key.pub",
    "home/jackson/local/secrets/ssh",
    "home/jackson/local/secrets/gnupg",
    "home/jackson/local/state/gnupg/pubring.kbx",
    "home/jackson/local/state/gnupg/trustdb.gpg",
]


def die(message: str) -> NoReturn:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    parser = argparse.ArgumentParser(
        prog="backup-murph-secrets",
        description="Back up murph SSH and GnuPG secrets.",
    )
    parser.add_argument("destination", type=Path, help="directory where the archive and manifest are written")
    args = parser.parse_args()

    if os.geteuid() != 0:
        die("run as root so all persisted secrets are readable")

    missing_commands = [command for command in ("age", "tar") if shutil.which(command) is None]
    if missing_commands:
        die("missing required command(s) on PATH: " + ", ".join(missing_commands))

    destination: Path = args.destination
    if not destination.is_dir():
        die(f"destination is not a directory: {destination}")
    if not PERSIST.is_dir():
        die(f"{PERSIST} does not exist")

    paths: list[str] = []
    for path in BACKUP_PATHS:
        if (PERSIST / path).exists():
            paths.append(path)
        else:
            print(f"warning: skipping missing {PERSIST / path}", file=sys.stderr)
    if not paths:
        die("no secret paths exist to back up")

    timestamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    host = socket.gethostname()
    revision = os.environ.get("MURPH_DOTFILES_REVISION", "")
    nar_hash = os.environ.get("MURPH_DOTFILES_NAR_HASH", "")

    uid = os.environ.get("SUDO_UID")
    gid = os.environ.get("SUDO_GID")
    chown_to_sudo_user: tuple[int, int] | None = None
    if uid is not None and gid is not None:
        try:
            chown_to_sudo_user = (int(uid), int(gid))
        except ValueError:
            pass

    base = f"murph-secrets-{host}-{timestamp}"
    archive = destination / f"{base}.tar.gz.age"
    manifest = destination / f"{base}.MANIFEST.txt"

    lines = [
        "murph secrets backup",
        f"created_utc={timestamp}",
        f"host={host}",
    ]
    if revision:
        lines.append(f"dotfiles_rev={revision}")
    if nar_hash:
        lines.append(f"dotfiles_nar_hash={nar_hash}")
    lines.extend(
        [
            "",
            f"encrypted_archive={archive.name}",
            "archive_contents_relative_to=/persist",
            "encrypted=true",
            "",
            "paths:",
        ]
    )
    lines.extend(f"  {path}" for path in paths)
    lines.extend(
        [
            "",
            "notes:",
            "  - Encrypted with age --passphrase.",
            "  - Contains only selected SSH host keys, SSH client keys, and GnuPG identity state.",
            "  - Extract into /mnt/persist during install.",
        ]
    )
    manifest.write_text("\n".join(lines) + "\n")

    print(f"Creating secrets archive: {archive}")
    try:
        with archive.open("wb") as output:
            tar = subprocess.Popen(
                [
                    "tar",
                    "--create",
                    "--gzip",
                    "--file",
                    "-",
                    "--directory",
                    str(PERSIST),
                    *paths,
                ],
                stdout=subprocess.PIPE,
            )
            assert tar.stdout is not None
            age = subprocess.Popen(["age", "--passphrase"], stdin=tar.stdout, stdout=output)
            tar.stdout.close()
            age_status = age.wait()
            tar_status = tar.wait()
        if tar_status != 0 or age_status != 0:
            die(f"archive creation failed (tar={tar_status}, age={age_status})")

        os.chmod(archive, 0o600)

        digest = hashlib.sha256()
        with archive.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
        with manifest.open("a") as handle:
            handle.write(f"{digest.hexdigest()}  {archive.name}\n")
        os.chmod(manifest, 0o644)

        if chown_to_sudo_user is not None:
            for path in (archive, manifest):
                try:
                    os.chown(path, *chown_to_sudo_user)
                except OSError:
                    pass
    except Exception:
        archive.unlink(missing_ok=True)
        manifest.unlink(missing_ok=True)
        raise

    print("Wrote:")
    print(f"  {archive}")
    print(f"  {manifest}")


if __name__ == "__main__":
    main()
