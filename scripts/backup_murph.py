#!/usr/bin/env python3
"""Create explicit murph state backup bundles."""

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
DOTFILES = Path("/home/jackson/repositories/dotfiles")

BUNDLES = {
    "secrets": {
        "encrypted": True,
        "archive_suffix": ".tar.gz.age",
        "archive_mode": 0o600,
        "paths": [
            "etc/ssh",
            "home/jackson/local/secrets/ssh",
            "home/jackson/local/secrets/pi/auth",
            "home/jackson/local/secrets/pi/mcp",
            "home/jackson/local/secrets/pi/mcp-oauth",
            "home/jackson/local/secrets/gnupg",
            "home/jackson/local/state/gnupg",
            "home/jackson/local/share/keyrings",
        ],
        "notes": [
            "Encrypted with age --passphrase.",
            "Extract into /mnt/persist during install.",
        ],
    },
    "convenience": {
        "encrypted": False,
        "archive_suffix": ".tar.gz",
        "archive_mode": 0o644,
        "paths": [
            "home/jackson/repositories",
            "home/jackson/share",
            "home/jackson/scratch",
            "home/jackson/.mozilla/firefox",
            "home/jackson/local/hacks/ssh/known_hosts",
            "home/jackson/local/hacks/fish/fish_history",
            "home/jackson/local/hacks/gh/hosts",
            "home/jackson/local/hacks/tmux/resurrect",
            "home/jackson/local/hacks/emacs/projects",
            "home/jackson/local/hacks/pi/settings",
            "home/jackson/local/state/emacs/backups",
            "home/jackson/local/state/emacs/auto-saves",
            "home/jackson/local/state/pi/sessions",
            "home/jackson/local/state/pi/mcp",
            "home/jackson/local/share/direnv/allow",
            "home/jackson/local/share/direnv/deny",
        ],
        "notes": [
            "This archive is not encrypted.",
            "It may still contain private browsing, shell, project, and personal-file state.",
            "Extract into /mnt/persist during install.",
        ],
    },
}


def die(message: str) -> NoReturn:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    parser = argparse.ArgumentParser(
        prog="backup-murph",
        description="Create explicit murph state backup bundles.",
    )
    parser.add_argument(
        "--bundle",
        required=True,
        choices=sorted(BUNDLES),
        help="state bundle to back up",
    )
    parser.add_argument("destination", type=Path, help="directory where archive and manifest are written")
    args = parser.parse_args()

    bundle = BUNDLES[args.bundle]
    encrypted = bundle["encrypted"]

    if os.geteuid() != 0:
        die("run as root so all persisted state is readable")

    required_commands = ["tar"] + (["age"] if encrypted else [])
    missing_commands = [command for command in required_commands if shutil.which(command) is None]
    if missing_commands:
        die("missing required command(s) on PATH: " + ", ".join(missing_commands))

    destination: Path = args.destination
    if not destination.is_dir():
        die(f"destination is not a directory: {destination}")
    if not PERSIST.is_dir():
        die(f"{PERSIST} does not exist")

    paths: list[str] = []
    for path in bundle["paths"]:
        if (PERSIST / path).exists():
            paths.append(path)
        else:
            print(f"warning: skipping missing {PERSIST / path}", file=sys.stderr)
    if not paths:
        die("no backup paths exist")

    timestamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    host = socket.gethostname()
    base = f"murph-{args.bundle}-{host}-{timestamp}"
    archive = destination / f"{base}{bundle['archive_suffix']}"
    manifest = destination / f"{base}.MANIFEST.txt"

    lines = [
        f"murph {args.bundle} backup",
        f"created_utc={timestamp}",
        f"host={host}",
    ]
    if shutil.which("git") is not None and (DOTFILES / ".git").exists():
        try:
            revision = subprocess.run(
                ["git", "-C", str(DOTFILES), "rev-parse", "HEAD"],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
            ).stdout.strip()
        except subprocess.CalledProcessError:
            revision = ""
        if revision:
            lines.append(f"dotfiles_rev={revision}")

    archive_key = "encrypted_archive" if encrypted else "archive"
    lines.extend(
        [
            "",
            f"{archive_key}={archive.name}",
            "archive_contents_relative_to=/persist",
            f"encrypted={str(encrypted).lower()}",
            "",
            "paths:",
        ]
    )
    lines.extend(f"  {path}" for path in paths)
    lines.extend(["", "notes:"])
    lines.extend(f"  - {note}" for note in bundle["notes"])
    manifest.write_text("\n".join(lines) + "\n")

    print(f"Creating {args.bundle} archive: {archive}")
    try:
        if encrypted:
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
        else:
            subprocess.run(
                [
                    "tar",
                    "--create",
                    "--gzip",
                    "--file",
                    str(archive),
                    "--directory",
                    str(PERSIST),
                    *paths,
                ],
                check=True,
            )

        os.chmod(archive, bundle["archive_mode"])

        digest = hashlib.sha256()
        with archive.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
        with manifest.open("a") as handle:
            handle.write(f"{digest.hexdigest()}  {archive.name}\n")
        os.chmod(manifest, 0o644)

        uid = os.environ.get("SUDO_UID")
        gid = os.environ.get("SUDO_GID")
        if uid is not None and gid is not None:
            try:
                uid_int = int(uid)
                gid_int = int(gid)
            except ValueError:
                pass
            else:
                for path in (archive, manifest):
                    try:
                        os.chown(path, uid_int, gid_int)
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
