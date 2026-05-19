#!/usr/bin/env python3
"""Restore explicit murph state backup bundles."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Any, Iterable, NoReturn

BUNDLES: dict[str, dict[str, Any]] = {
    "secrets-essential": {
        "encrypted": True,
        "directories_0700": [
            "home/jackson/local/secrets",
            "home/jackson/local/secrets/ssh",
            "home/jackson/local/secrets/gnupg",
            "home/jackson/local/secrets/gnupg/private-keys-v1.d",
            "home/jackson/local/secrets/gnupg/openpgp-revocs.d",
            "home/jackson/local/state/gnupg",
            "home/jackson/local/share/keyrings",
        ],
        "files_0600": [
            "home/jackson/local/secrets/ssh/id_ed25519",
        ],
        "files_0644": [
            "home/jackson/local/secrets/ssh/id_ed25519.pub",
        ],
    },
    "secrets-extra": {
        "encrypted": True,
        "directories_0700": [
            "home/jackson/local/secrets",
            "home/jackson/local/secrets/pi",
            "home/jackson/local/secrets/pi/auth",
            "home/jackson/local/secrets/pi/mcp",
            "home/jackson/local/secrets/pi/mcp-oauth",
            "home/jackson/local/secrets/claude-code",
            "home/jackson/local/secrets/claude-code/auth",
            "home/jackson/local/secrets/claude-code/credentials",
            "home/jackson/local/state/claude-code",
            "home/jackson/local/state/claude-code/history",
            "home/jackson/local/state/claude-code/projects",
            "home/jackson/local/state/claude-code/sessions",
            "home/jackson/local/config/discord",
            "home/jackson/local/config/Slack",
            "home/jackson/local/config/spotify",
        ],
        "files_0600": [
            "home/jackson/local/secrets/pi/auth/auth.json",
            "home/jackson/local/secrets/pi/mcp/mcp.json",
            "home/jackson/local/secrets/claude-code/auth/.claude.json",
            "home/jackson/local/secrets/claude-code/auth/.credentials.json",
            "home/jackson/local/state/claude-code/history/history.jsonl",
        ],
        "files_0644": [],
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
        if bundle_name not in BUNDLES:
            die(
                f"unknown bundle {bundle_name!r}; expected one of: "
                + ", ".join(sorted(BUNDLES))
            )
        if bundle_name in seen:
            die(f"bundle specified more than once: {bundle_name}")
        seen.add(bundle_name)
        specs.append((bundle_name, BUNDLES[bundle_name], Path(archive_text)))

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
        chmod_existing((persist / path for path in bundle["directories_0700"]), 0o700)
        chmod_existing((persist / path for path in bundle["files_0600"]), 0o600)
        chmod_existing((persist / path for path in bundle["files_0644"]), 0o644)

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
