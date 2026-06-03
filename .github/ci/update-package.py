#!/usr/bin/env python3
"""Update one manually packaged upstream project.

Updates the four packages whose upstream versions are pinned manually in
nix/packages, refreshes local package-lock files where needed, computes the new
npmDepsHash, and writes GitHub Actions outputs used by the PR workflow.

"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import urlopen

FAKE_HASH = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
ROOT = Path(__file__).resolve().parents[2]


@dataclass(frozen=True)
class PackageSpec:
    name: str
    nix_file: Path
    owner: str
    repo: str
    flake_attr: str
    tag_prefix: str = "v"
    branch: str | None = None
    lock_file: Path | None = None


PACKAGES: dict[str, PackageSpec] = {
    "pi-web-minimal": PackageSpec(
        name="pi-web-minimal",
        nix_file=ROOT / "nix/packages/pi-web-minimal.nix",
        owner="drsh4dow",
        repo="pi-web-minimal",
        branch="main",
        flake_attr="pi-web-minimal",
        lock_file=ROOT / "pi/pi-web-minimal-package-lock.json",
    ),
    "pi-mcp-adapter": PackageSpec(
        name="pi-mcp-adapter",
        nix_file=ROOT / "nix/packages/pi-mcp-adapter.nix",
        owner="nicobailon",
        repo="pi-mcp-adapter",
        flake_attr="pi-mcp-adapter",
        lock_file=ROOT / "pi/pi-mcp-adapter-package-lock.json",
    ),
    "pi-subagents": PackageSpec(
        name="pi-subagents",
        nix_file=ROOT / "nix/packages/pi-subagents.nix",
        owner="nicobailon",
        repo="pi-subagents",
        flake_attr="pi-subagents",
        lock_file=ROOT / "pi/pi-subagents-package-lock.json",
    ),
    "todoist-cli": PackageSpec(
        name="todoist-cli",
        nix_file=ROOT / "nix/packages/todoist-cli.nix",
        owner="Doist",
        repo="todoist-cli",
        flake_attr="todoist-cli",
    ),
}


@dataclass(frozen=True)
class Latest:
    version: str
    rev: str


def run(cmd: list[str], *, cwd: Path = ROOT, check: bool = True) -> subprocess.CompletedProcess[str]:
    print("+", " ".join(cmd), flush=True)
    result = subprocess.run(
        cmd,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if result.stdout:
        print(result.stdout, end="")
    if check and result.returncode != 0:
        raise subprocess.CalledProcessError(result.returncode, cmd, result.stdout)
    return result


def write_output(name: str, value: str) -> None:
    output = os.environ.get("GITHUB_OUTPUT")
    if not output:
        print(f"{name}={value}")
        return
    with open(output, "a", encoding="utf-8") as f:
        if "\n" in value:
            f.write(f"{name}<<EOF\n{value}\nEOF\n")
        else:
            f.write(f"{name}={value}\n")


def read_current_version(spec: PackageSpec) -> str:
    match = re.search(r'\bversion\s*=\s*"([^"]+)";', spec.nix_file.read_text())
    if not match:
        raise RuntimeError(f"Could not find version in {spec.nix_file}")
    return match.group(1)


def version_key(version: str) -> tuple[tuple[int | str, ...], str]:
    parts: list[int | str] = []
    for part in re.split(r"([0-9]+)", version):
        if not part:
            continue
        parts.append(int(part) if part.isdigit() else part)
    return tuple(parts), version


def latest_tag(spec: PackageSpec) -> Latest:
    result = run(
        ["git", "ls-remote", "--tags", f"https://github.com/{spec.owner}/{spec.repo}.git"],
        check=True,
    )
    revs_by_version: dict[str, str] = {}
    prefix = re.escape(spec.tag_prefix)
    tag_re = re.compile(rf"refs/tags/{prefix}(.+?)(\^\{{\}})?$")
    for line in result.stdout.splitlines():
        if not line.strip():
            continue
        rev, ref = line.split("\t", 1)
        match = tag_re.search(ref)
        if not match:
            continue
        version, peeled = match.groups()
        if not re.fullmatch(r"\d+(?:\.\d+)+", version):
            continue
        # Prefer peeled refs for annotated tags; otherwise keep lightweight refs.
        if peeled or version not in revs_by_version:
            revs_by_version[version] = rev
    if not revs_by_version:
        raise RuntimeError(f"No {spec.tag_prefix}* tags found for {spec.owner}/{spec.repo}")
    version = max(revs_by_version, key=version_key)
    return Latest(version=version, rev=revs_by_version[version])


def fetch_json(url: str) -> dict[str, object]:
    print(f"GET {url}", flush=True)
    with urlopen(url) as response:  # noqa: S310 - fixed GitHub URLs from package specs
        return json.loads(response.read().decode())


def latest_branch(spec: PackageSpec) -> Latest:
    assert spec.branch is not None
    result = run(
        [
            "git",
            "ls-remote",
            f"https://github.com/{spec.owner}/{spec.repo}.git",
            f"refs/heads/{spec.branch}",
        ]
    )
    rev = result.stdout.split()[0]
    package_json = fetch_json(
        f"https://raw.githubusercontent.com/{spec.owner}/{spec.repo}/{rev}/package.json"
    )
    version = str(package_json["version"])
    return Latest(version=version, rev=rev)


def get_latest(spec: PackageSpec) -> Latest:
    if spec.branch:
        return latest_branch(spec)
    return latest_tag(spec)


def source_hash(spec: PackageSpec, rev: str) -> str:
    result = run(
        ["nix", "flake", "prefetch", "--json", f"github:{spec.owner}/{spec.repo}/{rev}"]
    )
    data = json.loads(result.stdout[result.stdout.find("{") :])
    return str(data["hash"])


def replace_one(path: Path, pattern: str, replacement: str) -> None:
    text = path.read_text()
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise RuntimeError(f"Expected one match for {pattern!r} in {path}, found {count}")
    path.write_text(new_text)


def update_nix_file(spec: PackageSpec, latest: Latest, src_hash: str) -> None:
    replace_one(spec.nix_file, r'\bversion\s*=\s*"[^"]+";', f'version = "{latest.version}";')
    if re.search(r'\brev\s*=\s*"[^"]+";', spec.nix_file.read_text()):
        replace_one(spec.nix_file, r'\brev\s*=\s*"[^"]+";', f'rev = "{latest.rev}";')
    replace_one(spec.nix_file, r'\bhash\s*=\s*"sha256-[^"]+";', f'hash = "{src_hash}";')
    replace_one(
        spec.nix_file,
        r'\bnpmDepsHash\s*=\s*"sha256-[^"]+";',
        f'npmDepsHash = "{FAKE_HASH}";',
    )


def refresh_lock_file(spec: PackageSpec, rev: str) -> None:
    if spec.lock_file is None:
        return

    upstream_lock_url = (
        f"https://raw.githubusercontent.com/{spec.owner}/{spec.repo}/{rev}/package-lock.json"
    )
    try:
        print(f"GET {upstream_lock_url}", flush=True)
        with urlopen(upstream_lock_url) as response:  # noqa: S310 - fixed GitHub URL
            spec.lock_file.write_bytes(response.read())
            return
    except HTTPError as exc:
        if exc.code != 404:
            raise
        print("No upstream package-lock.json; generating one with npm", flush=True)

    with tempfile.TemporaryDirectory(prefix=f"{spec.name}-") as tmp:
        checkout = Path(tmp) / "src"
        run(
            [
                "git",
                "clone",
                "--depth",
                "1",
                f"https://github.com/{spec.owner}/{spec.repo}.git",
                str(checkout),
            ],
            cwd=Path(tmp),
        )
        run(["git", "fetch", "--depth", "1", "origin", rev], cwd=checkout)
        run(["git", "checkout", "--detach", "FETCH_HEAD"], cwd=checkout)
        run(["npm", "install", "--package-lock-only", "--ignore-scripts"], cwd=checkout)
        generated = checkout / "package-lock.json"
        if not generated.exists():
            raise RuntimeError(f"{spec.owner}/{spec.repo}@{rev} did not generate package-lock.json")
        shutil.copyfile(generated, spec.lock_file)


def compute_npm_deps_hash(spec: PackageSpec) -> str:
    result = run(["nix", "build", "--no-link", f".#packages.x86_64-linux.{spec.flake_attr}"], check=False)
    if result.returncode == 0:
        raise RuntimeError("Build unexpectedly succeeded with fake npmDepsHash")
    matches = re.findall(r"got:\s+(sha256-[A-Za-z0-9+/=]+)", result.stdout)
    if not matches:
        raise RuntimeError("Could not find computed npmDepsHash in nix build output")
    return matches[-1]


def git_has_changes() -> bool:
    return run(["git", "diff", "--quiet"], check=False).returncode != 0


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", choices=sorted(PACKAGES))
    args = parser.parse_args()

    spec = PACKAGES[args.package]
    current_version = read_current_version(spec)
    latest = get_latest(spec)

    write_output("package", spec.name)
    write_output("current_version", current_version)
    write_output("new_version", latest.version)

    if current_version == latest.version:
        print(f"{spec.name} is already at {current_version}")
        write_output("updated", "false")
        return

    src_hash = source_hash(spec, latest.rev)
    update_nix_file(spec, latest, src_hash)
    refresh_lock_file(spec, latest.rev)
    if spec.lock_file:
        # Normalize JSON formatting before computing npmDepsHash; the lock file
        # bytes are part of the fixed-output derivation.
        parsed = json.loads(spec.lock_file.read_text())
        spec.lock_file.write_text(json.dumps(parsed, indent=2) + "\n")
    npm_hash = compute_npm_deps_hash(spec)
    replace_one(
        spec.nix_file,
        r'\bnpmDepsHash\s*=\s*"sha256-[^"]+";',
        f'npmDepsHash = "{npm_hash}";',
    )

    run(["nix", "fmt", str(spec.nix_file.relative_to(ROOT))])

    if not git_has_changes():
        write_output("updated", "false")
        return

    write_output("updated", "true")
    write_output("branch", f"update/{spec.name}")
    write_output("title", f"{spec.name}: {current_version} -> {latest.version}")
    write_output(
        "body",
        f"Automated update of `{spec.name}` from `{current_version}` to `{latest.version}`.",
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001 - show concise GitHub Actions error
        print(f"::error::{exc}", file=sys.stderr)
        raise
