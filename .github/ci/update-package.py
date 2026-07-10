#!/usr/bin/env python3
"""Update one manually packaged upstream project.

Updates packages whose upstream versions are pinned manually in nix/packages,
refreshes local package-lock files where needed, computes npmDepsHash for npm
packages, and writes GitHub Actions outputs used by the PR workflow.

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
    npm_deps: bool = True
    npm_omit_dev: bool = True
    version_file: str | None = None
    version_regex: str | None = None
    unstable_version: bool = False


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
    "pi-theme-sync": PackageSpec(
        name="pi-theme-sync",
        nix_file=ROOT / "nix/packages/pi-theme-sync.nix",
        owner="sherif-fanous",
        repo="pi-theme-sync",
        flake_attr="pi-theme-sync",
        npm_deps=False,
    ),
    "pi-agent-browser-native": PackageSpec(
        name="pi-agent-browser-native",
        nix_file=ROOT / "nix/packages/pi-agent-browser-native.nix",
        owner="fitchmultz",
        repo="pi-agent-browser-native",
        flake_attr="pi-agent-browser-native",
        lock_file=ROOT / "pi/pi-agent-browser-native-package-lock.json",
        npm_omit_dev=False,
    ),
    "emacs-lean4-mode": PackageSpec(
        name="emacs-lean4-mode",
        nix_file=ROOT / "nix/packages/emacs-lean4-mode.nix",
        owner="ultronozm",
        repo="lean4-mode",
        branch="eglot",
        flake_attr="emacs-lean4-mode",
        npm_deps=False,
        unstable_version=True,
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


def fetch_text(url: str) -> str:
    print(f"GET {url}", flush=True)
    with urlopen(url) as response:  # noqa: S310 - fixed GitHub URLs from package specs
        return response.read().decode()


def fetch_json(url: str) -> dict[str, object]:
    return json.loads(fetch_text(url))


def github_commit_date(spec: PackageSpec, rev: str) -> str:
    data = fetch_json(f"https://api.github.com/repos/{spec.owner}/{spec.repo}/commits/{rev}")
    commit = data["commit"]
    if not isinstance(commit, dict):
        raise RuntimeError(f"Unexpected commit response for {spec.owner}/{spec.repo}@{rev}")
    committer = commit["committer"]
    if not isinstance(committer, dict):
        raise RuntimeError(f"Unexpected commit committer response for {spec.owner}/{spec.repo}@{rev}")
    date = str(committer["date"])
    return date[:10]


def latest_branch_version(spec: PackageSpec, rev: str) -> str:
    if spec.version_file is None:
        if spec.unstable_version:
            return f"0-unstable-{github_commit_date(spec, rev)}-{rev[:7]}"
        package_json = fetch_json(
            f"https://raw.githubusercontent.com/{spec.owner}/{spec.repo}/{rev}/package.json"
        )
        return str(package_json["version"])

    text = fetch_text(
        f"https://raw.githubusercontent.com/{spec.owner}/{spec.repo}/{rev}/{spec.version_file}"
    )
    regex = spec.version_regex or r"(.+)"
    match = re.search(regex, text, flags=re.MULTILINE)
    if not match:
        raise RuntimeError(f"Could not find version in {spec.owner}/{spec.repo}:{spec.version_file}")
    version = match.group(1)
    if spec.unstable_version:
        version = f"{version}-unstable-{github_commit_date(spec, rev)}-{rev[:7]}"
    return version


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
    return Latest(version=latest_branch_version(spec, rev), rev=rev)


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
    if spec.npm_deps:
        replace_one(
            spec.nix_file,
            r'\bnpmDepsHash\s*=\s*"sha256-[^"]+";',
            f'npmDepsHash = "{FAKE_HASH}";',
        )


def refresh_lock_file(spec: PackageSpec, rev: str) -> None:
    if spec.lock_file is None:
        return

    def needs_regeneration(lock_file: bytes) -> bool:
        data = json.loads(lock_file)
        packages = data.get("packages", {})
        if not isinstance(packages, dict):
            return False
        for package in packages.values():
            if not isinstance(package, dict) or "resolved" not in package:
                continue
            resolved = str(package["resolved"])
            is_git_dependency = resolved.startswith(
                ("git+", "git://", "github:", "gitlab:", "bitbucket:")
            )
            if not is_git_dependency and "integrity" not in package:
                return True
        return False

    def fill_missing_integrity(lock_file: Path) -> None:
        data = json.loads(lock_file.read_text())
        packages = data.get("packages", {})
        if not isinstance(packages, dict):
            return
        for package_path, package in packages.items():
            if not isinstance(package, dict) or "resolved" not in package:
                continue
            resolved = str(package["resolved"])
            is_git_dependency = resolved.startswith(
                ("git+", "git://", "github:", "gitlab:", "bitbucket:")
            )
            if is_git_dependency or "integrity" in package:
                continue
            package_name = package_path.rsplit("node_modules/", 1)[-1]
            integrity = run(
                ["npm", "view", f"{package_name}@{package['version']}", "dist.integrity"]
            ).stdout.strip()
            if not integrity:
                raise RuntimeError(f"Could not find npm integrity for {package_name}")
            package["integrity"] = integrity
        lock_file.write_text(json.dumps(data, indent=2) + "\n")

    def generate_lock_file() -> None:
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
            fill_missing_integrity(checkout / "package-lock.json")
            # Match each package's buildNpmPackage dependency set and repair
            # upstream lockfiles that omit integrity for registry dependencies.
            npm_install_command = [
                "npm",
                "install",
                "--package-lock-only",
                "--ignore-scripts",
            ]
            if spec.npm_omit_dev:
                npm_install_command.append("--omit=dev")
            run(npm_install_command, cwd=checkout)
            generated = checkout / "package-lock.json"
            if not generated.exists():
                raise RuntimeError(
                    f"{spec.owner}/{spec.repo}@{rev} did not generate package-lock.json"
                )
            if needs_regeneration(generated.read_bytes()):
                raise RuntimeError(
                    f"{spec.owner}/{spec.repo}@{rev} generated a lockfile with missing integrity"
                )
            shutil.copyfile(generated, spec.lock_file)

    upstream_lock_url = (
        f"https://raw.githubusercontent.com/{spec.owner}/{spec.repo}/{rev}/package-lock.json"
    )
    try:
        print(f"GET {upstream_lock_url}", flush=True)
        with urlopen(upstream_lock_url) as response:  # noqa: S310 - fixed GitHub URL
            upstream_lock = response.read()
        if not needs_regeneration(upstream_lock):
            spec.lock_file.write_bytes(upstream_lock)
            return
        print("Upstream lockfile is missing integrity; regenerating with npm", flush=True)
    except HTTPError as exc:
        if exc.code != 404:
            raise
        print("No upstream package-lock.json; generating one with npm", flush=True)

    generate_lock_file()


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
    if spec.npm_deps:
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
