#!/usr/bin/env python3
"""Backup murph files"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
from typing import Any, NoReturn

PERSIST = Path("/persist")


def die(message: str) -> NoReturn:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


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
        prog="backup-murph",
        description="Backup murph files",
    )
    parser.add_argument(
        "--bundle",
        required=True,
        action="append",
        choices=[*sorted(bundles), "all"],
        help="state bundle to back up; may be specified multiple times, or use 'all'",
    )
    parser.add_argument("destination", type=Path, help="directory where archives and manifests are written")
    args = parser.parse_args()

    selected = set(bundles) if "all" in args.bundle else set(args.bundle)
    selected_configs = [(name, bundles[name]) for name in selected]

    if os.geteuid() != 0:
        die("run as root so all persisted state is readable")

    required_commands = {"tar"}
    if any(bundle["encrypted"] for _, bundle in selected_configs):
        required_commands.add("age")
    missing_commands = [command for command in sorted(required_commands) if shutil.which(command) is None]
    if missing_commands:
        die("missing required command(s) on PATH: " + ", ".join(missing_commands))

    destination: Path = args.destination
    if not destination.is_dir():
        die(f"destination is not a directory: {destination}")
    if not PERSIST.is_dir():
        die(f"{PERSIST} does not exist")

    paths_by_bundle: dict[str, list[str]] = {}
    for bundle_name, bundle in selected_configs:
        paths: list[str] = []
        for path in bundle["backup_paths"]:
            if (PERSIST / path).exists():
                paths.append(path)
            else:
                print(f"warning: skipping missing {PERSIST / path} for {bundle_name}", file=sys.stderr)
        if not paths:
            die(f"no backup paths exist for {bundle_name}")
        paths_by_bundle[bundle_name] = paths

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

    outputs: list[tuple[Path, Path]] = []
    for bundle_name, bundle in selected_configs:
        paths = paths_by_bundle[bundle_name]
        encrypted = bundle["encrypted"]
        base = f"murph-{bundle_name}-{host}-{timestamp}"
        archive = destination / f"{base}{bundle['archive_suffix']}"
        manifest = destination / f"{base}.MANIFEST.txt"

        archive_key = "encrypted_archive" if encrypted else "archive"
        lines = [
            f"murph {bundle_name} backup",
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

        print(f"Creating {bundle_name} archive: {archive}")
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

            os.chmod(archive, int(bundle["archive_mode"], 8))

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

        outputs.append((archive, manifest))

    print("Wrote:")
    for archive, manifest in outputs:
        print(f"  {archive}")
        print(f"  {manifest}")


if __name__ == "__main__":
    main()
