# Repository guide for coding agents

This is Jackson's personal NixOS/Home Manager dotfiles repository. Optimize for small, idiomatic, well-validated changes that preserve the repository's impermanence model and preference for declarative/store-backed configuration.

## Repository map

- `flake.nix`: top-level flake inputs/outputs, overlays, packages, apps, checks, templates, formatter, and NixOS configurations.
- `nix/modules/default.nix`: registry of reusable NixOS modules. Add new modules here before using them in hosts.
- `nix/hosts/`: host composition:
  - `murph.nix`: full personal laptop/desktop profile.
  - `murph-install.nix`: bootstrap install profile.
- `nix/modules/home/`: Home Manager and user-facing app modules.
- `nix/modules/hosts/`: host-specific hardware, disk, ZFS, and persistence modules, in one directory per host (`murph/`).
- `nix/packages/`: custom derivations and script app packaging.
- `emacs/`: editor config, generally consumed from the Nix store via a wrapper rather than copied into mutable home paths.
- `agents/skills/`: user-global Agent Skills shared by Claude Code and Codex. `claude-code.nix` passes the tree to `programs.claude-code.skills`; `codex.nix` links each skill individually into `CODEX_HOME/skills`, leaving Codex's own bundled cache at `skills/.system` alone. Codex reads three user-scope skill roots: `CODEX_HOME/skills` (marked deprecated upstream but still read), `~/.agents/skills`, and `skills/.system`. We deliberately use the deprecated one so no `~/.agents` directory has to exist. Skills that only make sense inside this repository belong in `.agents/skills/` (exposed to Claude Code through the `.claude/skills` symlink) instead — note that top-level `agents/` is user-global and dotted `.agents/` is repository-scoped.
- `agents/instructions/` and `agents/machines/`: user-global agent instructions, split so the same portable text serves every machine. `preamble.md` and `conventions.md` are the portable halves; `machines/<host>.md` is the `## This machine` section between them. `nix/modules/home/agent-instructions.nix` declares the `agentInstructions` options and concatenates the three in that order; the host names its own section through `agentInstructions.machineFile`, which has no default so a host that gives agents instructions has to describe itself. `claude-code.nix` passes the assembled text to Home Manager's `programs.claude-code.context`, which writes it as `CLAUDE.md` inside `configDir` (Claude Code reads `CLAUDE.md`, not `AGENTS.md`); `codex.nix` passes the same text to its own `codex` options, which write it as `AGENTS.md` inside `codex.configDirectory`. Guidance specific to this repository belongs in the root `AGENTS.md` instead.
- `scripts/`: implementation bodies for flake apps in `nix/packages/scripts.nix`.
- `templates/`: flake templates exposed through `nix/templates.nix`.
- `documentation/`: operator docs, especially `documentation/murph-install.md`.
- `certificates/`: public CA certificates read from the store, such as the University of Utah RADIUS root pinned by `nix/modules/utah-wireless.nix`. Keeps `nix/` holding only Nix.

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

Some modules are curried when they need flake-provided overlays/packages, e.g. `import ./home/emacs.nix { inherit emacsOverlays emacsHome; }`. Register those in `nix/modules/default.nix`.

Files under `nix/modules/home/` are a mix of two module classes, and the distinction matters more than the directory name suggests:

- **NixOS modules** that reach into `home-manager.users.${user}` from outside. They live at the system level because they need `systemd.tmpfiles.rules` or `system.activationScripts`. Only a NixOS host can import them.
- **Home Manager modules** proper, such as `git.nix`, `fish.nix`, `directories.nix`, `emacs.nix` and `claude-code.nix`. A host imports these into `home-manager.users.<user>.imports`, and they work unchanged on NixOS, nix-darwin, and hosts without impermanence.

Prefer the second class. Reach for the first only when something genuinely has to happen at system activation or boot, before the user's Home Manager generation is applied. Registry entries for Home Manager modules are named `home*` (`homeGit`, `homeClaudeCode`).

A Home Manager module also has no business knowing about murph's `~/local` layout. Default to where the application natively puts its files and let the host's composition redirect it: `claude-code.nix` leaves `programs.claude-code.configDir` at its upstream `~/.claude` default, and `home/impermanence/claude-code.nix` points it at `~/local/state/claude-code` and persists that one directory. A redirect lives wherever the choice belongs, which is often not the host file: `ssh.identityFile` is set by `nix/modules/local-directory.nix`, `ssh.knownHostsFile` by `nix/modules/hosts/murph/base.nix`, and the two agent config directories by their impermanence mixins. Check for an upstream Home Manager module before writing wrappers, tmpfiles rules, or activation scripts by hand. Upstream is not always usable: `programs.claude-code` has a `configDir` option and is used in full, while `programs.codex` hardcodes `~/.codex` or `${xdg.configHome}/codex` and its `settings` option would render `config.toml` from the store, which cannot work because Codex writes per-project trust decisions into that file. `codex.nix` therefore declares its own options.

Do not pair a `systemd.tmpfiles` rule with an activation script that does the same thing. `systemd-tmpfiles-resetup.service` carries an `X-Restart-Triggers` on the rules, so `nixos-rebuild switch` re-applies them; the rules alone are enough at both boot and switch.

When adding a new dedicated module:

1. Create `nix/modules/home/<name>.nix` or another appropriate module file.
2. Import/register it in `nix/modules/default.nix`.
3. Add it to the relevant host module list in `nix/hosts/<host>.nix`.
4. If the new file is referenced from the flake before being committed, run `git add -N <file>` so Nix can see it.

`gnomeDesktop` imports `dconf`, so changes to `dconf.nix` affect the GNOME host profile transitively.

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

- Disk/ZFS layout: `nix/modules/hosts/murph/disko.nix`.
- ZFS rollback/boot behavior: `nix/modules/hosts/murph/zfs.nix`.
- System persistence: `nix/modules/hosts/murph/system-persistence.nix`.
- User persistence: `nix/modules/home/impermanence/`, one mixin per app, composed by `murph.nix` in that directory.

Do not casually persist whole home directories or broad app trees. Classify state deliberately, but measure before building machinery to split a tree: `CODEX_HOME` is persisted whole, caches included, because the four subdirectories Codex offers no configuration knob for came to 3.3 MB, two of them were empty, and the redirects missed the 89 MB `.tmp` plugin staging directory entirely. Narrow persistence that misses the bulk is worse than none, because it reads as though the classification was done.

### Store-backed / declarative

Prefer Nix store paths for static configuration, generated config, package wrappers, desktop entries, Emacs/Kak/Ghostty config, agent skills, and policy-like settings.

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
- Emacs backups/auto-saves and known-projects

Persist user state with `home.persistence.main.directories` in a per-app mixin under `nix/modules/home/impermanence/`, and add the mixin to `impermanence/murph.nix`. The NixOS `environment.persistence` is for system state only, in `nix/modules/hosts/murph/system-persistence.nix`.

A mixin owns both halves of a decision: it redirects the path if the app should not use its native location, and it persists the result. That keeps the portable module free of any `/persist` or `~/local` knowledge, so a host without impermanence simply omits the mixin. `home.persistence` needs no import — the NixOS impermanence module injects its Home Manager counterpart into `home-manager.sharedModules`. Impermanence wants home-relative paths and silently accepts some wrong absolute ones, so run every path through `nix/lib/to-home-relative-path.nix`, which asserts the path is inside the home directory. Use `mode = "0700"` for private profile/auth/state directories. If an app rewrites a file via temp-file + rename, persist the containing directory instead of bind-mounting just the file.

### Ephemeral state

Leave caches, logs, crash reports, sockets, lock files, generated code caches, first-run UI trivia, and other rebuildable state ephemeral. Use `~/local/cache`, unpersisted `~/local/state`, or an app-specific runtime directory.

## Home directory and XDG layout

`nix/modules/home/directories.nix` defines defaults:

- home: `/home/${config.personal.userName}`
- repositories: `~/repositories`
- local: `~/local`
- scratch: `~/scratch`
- share: `~/share`

The `~/local` layout is a pair of modules a host opts into, one per module
graph. `nix/modules/home/local-directory.nix` sets Home Manager's `xdg.*`
paths; `nix/modules/local-directory.nix` states the same layout for PAM, the
systemd user manager and tmpfiles, which evaluate outside Home Manager. A host
selects both together, as `murph` and `murph-install` do:

- `XDG_BIN_HOME=~/local/bin`
- `XDG_CONFIG_HOME=~/local/config`
- `XDG_CACHE_HOME=~/local/cache`
- `XDG_DATA_HOME=~/local/share`
- `XDG_STATE_HOME=~/local/state`

Adopting the layout is a preference about home directory organisation, and is
independent of impermanence: a host with an ordinary root filesystem can adopt
it, and an impermanent host could persist the stock directories instead. So it
is a third selectable concept beside the portable application leaves and the
impermanence mixins.

The platform profiles state no layout. `nix/modules/linux.nix` and
`nix/modules/home/linux.nix` can be imported by a host that keeps the stock
directories, and modules that would otherwise hardcode a `~/local` path take a
nullable option instead, defaulting to the application's own location.
`ssh.identityFile` and `ssh.knownHostsFile` default to OpenSSH's `~/.ssh`, and
the host redirects them.

Special local subtrees:

- `~/local/secrets`: secret material.
- `~/local/hacks`: narrowly persisted mutable files/trust decisions that do not fit clean declarative config.
- `~/local/cache`: ephemeral caches.
- `~/local/state`: app state; individual subtrees may or may not be persisted.
- `~/share`, `~/repositories`, `~/scratch`: user-facing data that is persisted on `murph`.

There are no top-level compatibility exceptions in `$HOME`. Codex's skills are
linked into `CODEX_HOME/skills` rather than `~/.agents/skills` specifically to
keep it that way.

## App/package module patterns

When adding an app, first inspect how it writes state. For desktop/Electron apps, running briefly with isolated `HOME`/XDG dirs under `xvfb-run` is often useful.

Prefer dedicated modules for apps with wrappers, tmpfiles, activation scripts, or persistence decisions. A package needing none of that goes in the profile it belongs to: `home/linux.nix` for portable CLI tools, `home/gnome-desktop.nix` for graphical apps and fonts.

Common patterns:

- `pkgs.symlinkJoin` + `pkgs.makeWrapper` for wrapped packages.
- Patch desktop files or systemd/dbus service files when upstream Exec paths would bypass the wrapper.
- `systemd.tmpfiles.rules` for boot-time directory/symlink creation.
- `system.activationScripts.<name>.deps = [ "persist-files" ];` for switch-time migration/repair after impermanence mounts are established. System state only, in `nix/modules/hosts/murph/`; user state is declared by Home Manager modules that have no activation ordering to express.
- Add environment variables to `systemd.services."user@${uid}"`, `systemd.services."home-manager-${user}"`, and `home.sessionVariables` when both services and shells need them.
- Use `lib.escapeShellArg` inside shell snippets and escape spaces in tmpfiles paths with `lib.replaceStrings [ " " ] [ "\\x20" ]`.

## Secrets

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

When packaging Node/npm tools, follow the existing `buildNpmPackage` pattern and include fixed hashes.

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
