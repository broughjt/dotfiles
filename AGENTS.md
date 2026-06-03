# Repository guide for coding agents

This is Jackson's personal NixOS/Home Manager dotfiles repository. Optimize for small, idiomatic, well-validated changes that preserve the repository's impermanence model and preference for declarative/store-backed configuration.

## Repository map

- `flake.nix`: top-level flake inputs/outputs, overlays, packages, apps, checks, templates, formatter, and NixOS configurations.
- `nix/modules/default.nix`: registry of reusable NixOS modules. Add new modules here before using them in hosts.
- `nix/hosts/`: host composition:
  - `murph.nix`: full personal laptop/desktop profile.
  - `murph-install.nix`: bootstrap install profile.
  - `tars.nix`: Raspberry Pi host using `nixos-raspberrypi`.
- `nix/modules/home/`: Home Manager and user-facing app modules.
- `nix/modules/hosts/`: host-specific hardware, disk, ZFS, and persistence modules.
- `nix/packages/`: custom derivations and script app packaging.
- `emacs/`, `kak/`: editor configs, generally consumed from the Nix store via wrappers rather than copied into mutable home paths.
- `scripts/`: implementation bodies for flake apps in `nix/packages/scripts.nix`.
- `templates/`: flake templates exposed through `nix/templates.nix`.
- `documentation/`: operator docs, especially `documentation/murph-install.md`.
- `secrets/`: encrypted Vaultix/age secrets only. Do not add plaintext secrets.

## Host and module composition idioms

Modules are plain functions returning NixOS module attrsets. Many home modules use this shape:

```nix
{ config, lib, pkgs, ... }:

let
  user = config.personal.userName;
  localDirectory = config.defaultDirectories.localDirectory;
in
{
  home-manager.users.${user} = { ... };
}
```

Some modules are curried when they need flake-provided overlays/packages, e.g. `import ./home/pi-coding-agent.nix { inherit ...; }`. Register those in `nix/modules/default.nix`.

When adding a new dedicated module:

1. Create `nix/modules/home/<name>.nix` or another appropriate module file.
2. Import/register it in `nix/modules/default.nix`.
3. Add it to the relevant host module list in `nix/hosts/<host>.nix`.
4. If the new file is referenced from the flake before being committed, run `git add -N <file>` so Nix can see it.

`gnomeDesktop` imports `dconf` and `desktopApps`, so changes to `desktop-apps.nix` affect the GNOME host profile transitively.

## Formatting and validation

Always format touched Nix files:

```sh
nix fmt <paths>
```

Primary validation for host changes:

```sh
nix build --no-link .#nixosConfigurations.murph.config.system.build.toplevel
```

Other useful checks:

```sh
nix flake check
nix build --no-link .#checks.x86_64-linux.emacs-byte-compile
nix develop
```

Use the exact host you changed when possible. For package availability or metadata:

```sh
nix eval --raw .#nixosConfigurations.murph.pkgs.<pkg>.version
nix build --no-link --print-out-paths .#nixosConfigurations.murph.pkgs.<pkg>
```

For tmpfiles/impermanence work, inspect generated rules if path escaping or symlinks are non-trivial:

```sh
out=$(nix build --no-link --print-out-paths .#nixosConfigurations.murph.config.system.build.toplevel)
nix path-info -r "$out" | rg 'tmpfiles.d|nixos-tmpfiles'
```

## Impermanence model

`murph` uses ZFS with an ephemeral root and selected persistent state under `/persist`:

- Disk/ZFS layout: `nix/modules/hosts/murph-disko.nix`.
- ZFS rollback/boot behavior: `nix/modules/hosts/murph-zfs.nix`.
- System persistence: `nix/modules/hosts/murph-system-persistence.nix`.
- User persistence: `nix/modules/hosts/murph-user-persistence.nix`.

Do not casually persist whole home directories or broad app trees. Classify state deliberately:

### Store-backed / declarative

Prefer Nix store paths for static configuration, generated config, package wrappers, desktop entries, Emacs/Kak/Ghostty config, Pi packages/skills, and policy-like settings.

Examples:

- Emacs uses `--init-directory ${../../../emacs}` via a wrapper; init files stay in the store.
- Ghostty and Kakoune use wrappers so config is read from store-backed files.
- Git and tmux configs are rendered by Home Manager but read directly from the store rather than via mutable XDG symlinks.
- GNOME structural defaults are in declarative dconf profiles; locked only where they are intended invariants.

### Persisted state

Persist only valuable state, secrets, trust decisions, or state that is hard/annoying to recreate:

- selected app profiles containing login/cookies/local storage
- credentials, SSH/GPG/keyrings, OAuth/auth files
- direnv allow/deny decisions
- shell history and known_hosts-like trust records
- Pi sessions/settings/MCP state chosen as durable
- Emacs backups/auto-saves and known-projects

Persist user state in `environment.persistence."/persist".users.${user}.directories` in `murph-user-persistence.nix`. Use `mode = "0700"` for private profile/auth/state directories. If an app rewrites a file via temp-file + rename, persist the containing directory instead of bind-mounting just the file.

### Ephemeral state

Leave caches, logs, crash reports, sockets, lock files, generated code caches, first-run UI trivia, and other rebuildable state ephemeral. Use `~/local/cache`, unpersisted `~/local/state`, or an app-specific runtime directory.

If an app mixes durable profile data with bulky cache subdirectories, prefer an explicit profile location plus symlinks from cache-like subtrees back to `~/local/cache/<app>`, as in `nix/modules/home/todoist-electron.nix`.

## Home directory and XDG layout

`nix/modules/home/directories.nix` defines defaults:

- home: `/home/${config.personal.userName}`
- repositories: `~/repositories`
- local: `~/local`
- scratch: `~/scratch`
- share: `~/share`

`nix/modules/home/linux.nix` sets XDG paths:

- `XDG_BIN_HOME=~/local/bin`
- `XDG_CONFIG_HOME=~/local/config`
- `XDG_CACHE_HOME=~/local/cache`
- `XDG_DATA_HOME=~/local/share`
- `XDG_STATE_HOME=~/local/state`

It injects these into systemd user services, Home Manager activation, session variables, and PAM for the personal user. Preserve this model when adding software.

Special local subtrees:

- `~/local/secrets`: secret material.
- `~/local/hacks`: narrowly persisted mutable files/trust decisions that do not fit clean declarative config.
- `~/local/cache`: ephemeral caches.
- `~/local/state`: app state; individual subtrees may or may not be persisted.
- `~/share`, `~/repositories`, `~/scratch`: user-facing data that is persisted on `murph`.

## App/package module patterns

When adding an app, first inspect how it writes state. For desktop/Electron apps, running briefly with isolated `HOME`/XDG dirs under `xvfb-run` is often useful.

Prefer dedicated modules for apps with wrappers, tmpfiles, activation scripts, or persistence decisions. Keep `desktop-apps.nix` for simple package lists/fonts only.

Common patterns:

- `pkgs.symlinkJoin` + `pkgs.makeWrapper` for wrapped packages.
- Patch desktop files or systemd/dbus service files when upstream Exec paths would bypass the wrapper.
- `systemd.tmpfiles.rules` for boot-time directory/symlink creation.
- `system.activationScripts.<name>.deps = [ "persist-files" ];` for switch-time migration/repair after impermanence mounts are established.
- Add environment variables to `systemd.services."user@${uid}"`, `systemd.services."home-manager-${user}"`, and `home.sessionVariables` when both services and shells need them.
- Use `lib.escapeShellArg` inside shell snippets and escape spaces in tmpfiles paths with `lib.replaceStrings [ " " ] [ "\\x20" ]`.

## Secrets

Agenix decrypts encrypted secret files from `secrets/*.age`; shared Home Manager secret wiring lives in modules such as `nix/modules/home/pi-web-minimal-agenix-home.nix`. Never commit plaintext secrets.

Persistent identity backup/restore scripts intentionally include only selected SSH and GPG state. If adding new irreplaceable secret state, update:

- `scripts/backup_murph_secrets.py`
- `scripts/restore_murph_secrets.py`
- `documentation/murph-install.md`

Do not broaden secret backups without explaining why.

## Custom packages, apps, checks, and templates

- Add custom derivations under `nix/packages/`.
- Expose packages/apps through `flake.nix` when they should be runnable via `nix run` or buildable as flake outputs.
- `nix/packages/scripts.nix` wraps scripts as `writeShellApplication` outputs with explicit runtime inputs.
- `nix/checks.nix` currently contains the Emacs byte-compile check.
- `nix/templates.nix` exposes templates under `templates/`.

When packaging Node/npm tools, follow the existing `buildNpmPackage` pattern and include fixed hashes. Package-generated Pi skills can be materialized into the Nix store, as with `todoist-cli-pi-skill`.

Manually pinned upstream packages that should receive automated update PRs are tracked by `.github/ci/update-package.py` and `.github/workflows/update-packages.yml`. If adding or renaming one, expose it as a buildable flake package when practical, add/update its updater spec and workflow matrix entry, and validate with `nix run nixpkgs#actionlint -- .github/workflows/update-packages.yml` plus a package build.

## Emacs conventions

Emacs packages are Nix-managed; `package.el` installation is disabled. Init/config files live under `emacs/` and are loaded through the wrapped Emacs package in `nix/modules/home/emacs.nix`.

State is explicitly redirected:

- persisted: backups, auto-saves, known-projects
- ephemeral: eln-cache, auto-save-list, transient/custom/bookmarks unless explicitly persisted later

Run byte-compile validation after Emacs Lisp changes:

```sh
nix build --no-link .#checks.x86_64-linux.emacs-byte-compile
```

## Installation scripts and destructive operations

Be careful with install/disko/ZFS scripts. `install-murph` is destructive and targets a specific NVMe disk. Do not run destructive installer commands unless the user explicitly asks and understands the consequences.

`documentation/murph-install.md` is the source of operational install/restore instructions; keep it in sync with changes to scripts, persistence, and secret backup contents.

## Style expectations

- Make minimal, targeted edits.
- Keep comments explaining non-obvious persistence, wrapper, and store-backed-config choices.
- Prefer narrow persistence over convenience.
- Avoid creating legacy dotfiles in `$HOME`; route through XDG or explicit wrappers.
- Preserve ownership/mode hygiene for secrets and private state.
- Validate with Nix builds, and report commands run plus any skipped checks.
