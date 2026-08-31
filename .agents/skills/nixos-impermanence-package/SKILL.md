---
name: nixos-impermanence-package
description: Add packages/apps to this NixOS dotfiles repo and configure impermanence. Use when installing new packages, desktop apps, CLIs, or developer tools and deciding what should be store-backed/declarative, persisted statefully, or left ephemeral.
---

# NixOS Impermanence Package Setup

Use this skill when adding or changing installed packages/apps in this dotfiles repo, especially when the user asks to configure persistence/impermanence.

## First: read the local patterns

`AGENTS.md` is the source for this repository's conventions. Read its
*Impermanence model*, *Home directory and XDG layout* and *App/package module
patterns* sections before editing; this skill does not restate them.

Then read the modules you are about to imitate:

- `nix/modules/home/directories.nix` and `nix/modules/home/local-directory.nix`
  for the XDG and `~/local` layout.
- `nix/modules/home/impermanence/` for user persistence. Every file there is a
  worked example; `murph.nix` composes them.
- The module most similar to the requested app:
  - graphical app: `nix/modules/home/firefox.nix`, `nix/modules/home/vlc.nix`
  - CLI config: `nix/modules/home/gh.nix`
  - an app whose state needs splitting: `nix/modules/home/claude-code.nix`,
    `nix/modules/home/emacs.nix`, `nix/modules/home/gpg.nix`
- `nix/modules/default.nix` and `nix/hosts/murph.nix` if adding a new module.

## Module shape

An app is normally **two** modules, and keeping them apart is the point:

1. A portable Home Manager module, `nix/modules/home/<app>.nix`. It configures
   the app and nothing else. It must not mention `/persist`, `~/local`, or
   impermanence, so that a host without any of those can import it unchanged.
   Where the app's state location is a decision rather than a fact, declare an
   option defaulting to the app's *native* location, as
   `nix/modules/home/emacs.nix` does with `emacs.hacksDirectory`.
2. An impermanence mixin, `nix/modules/home/impermanence/<app>.nix`. It sets
   that option to the `~/local` path and persists the result. Both halves of
   one decision live together, so a host that omits the mixin gets the app at
   its native location with no persistence.

Register both in `nix/modules/default.nix` (`home<App>` and
`home<App>Impermanence`), add the portable module to the host's
`home-manager.users.<user>.imports`, and add the mixin to
`nix/modules/home/impermanence/murph.nix`.

Reach for a NixOS module only when something genuinely has to happen at system
activation or boot. `systemd.tmpfiles.rules` and
`system.activationScripts.<name>.deps = [ "persist-files" ]` are system-level
tools; a Home Manager module creates its directories with
`home.activation.<name> = lib.hm.dag.entryBefore [ "checkLinkTargets" ]` instead.

## Investigation workflow

1. **Find the package and entry points**
   - Check package availability/version, for example:
     - `nix eval --raw .#nixosConfigurations.murph.pkgs.<pkg>.version`
     - `nix build --no-link --print-out-paths .#nixosConfigurations.murph.pkgs.<pkg>`
   - Inspect `bin/`, `share/applications/*.desktop`, wrappers, and package metadata.

2. **Identify where the app writes**
   - Prefer docs/source inspection if available.
   - For desktop/Electron apps, run briefly with temporary isolated XDG dirs, often under `xvfb-run`, then inspect created files:
     ```bash
     rm -rf /tmp/app-run
     mkdir -p /tmp/app-run/{home,config,cache,state,share}
     nix shell nixpkgs#xvfb-run -c bash -lc '
       timeout 8s env \
         HOME=/tmp/app-run/home \
         XDG_CONFIG_HOME=/tmp/app-run/config \
         XDG_CACHE_HOME=/tmp/app-run/cache \
         XDG_STATE_HOME=/tmp/app-run/state \
         XDG_DATA_HOME=/tmp/app-run/share \
         xvfb-run -a <app> <safe flags>
     ' || true
     find /tmp/app-run -mindepth 1 -printf '%y %M %u:%g %s %p -> %l\n' | sort
     ```
   - For Electron apps, test whether `--user-data-dir=<dir>` relocates the profile.
   - Inspect generated JSON/config/database names to infer durable vs cache state. Do not persist logs/crash/cache just because they are in a profile.

3. **Classify what it writes** into store-backed, persisted and ephemeral, per
   `AGENTS.md`. Measure before building machinery to split a tree: narrow
   persistence that misses the bulk is worse than none.

4. **Choose module placement**
   - A package needing no configuration goes in the profile it belongs to:
     `home/linux.nix` for portable CLI tools, `home/gnome-desktop.nix` for
     graphical apps and fonts.
   - Anything with configuration or persistence decisions gets the two modules
     described above.

5. **Declare persistence** in the mixin. Keep a comment beside each entry
   saying what is persisted and what is deliberately left ephemeral; the
   comment is how the next reader knows the classification was actually done.

6. **Add the package** to `home.packages` in the portable module. Custom
   derivations go under `nix/packages/`, exposed as flake packages when
   practical. Manually pinned upstream packages (for example `fetchFromGitHub`
   with a fixed tag/rev) are bumped by hand; a pin drifts silently until
   someone looks.

## Implementation patterns to copy

### A redirectable option in the portable module

```nix
options.myApp.stateDirectory = lib.mkOption {
  type = lib.types.str;
  default = "${config.xdg.stateHome}/my-app";
  defaultText = lib.literalExpression ''"''${config.xdg.stateHome}/my-app"'';
  description = "Directory for durable my-app state.";
};
```

Private state has to be private before anything is written into it:

```nix
home.activation.myAppDirectories = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
  run install -d -m 0700 ${lib.escapeShellArg config.myApp.stateDirectory}
'';
```

### The matching mixin

Impermanence wants home-relative paths and silently accepts some wrong absolute
ones, so every path goes through `nix/lib/to-home-relative-path.nix`, which
asserts the path is inside the home directory. `home.persistence` itself needs
no import: the NixOS impermanence module injects its Home Manager counterpart
into `home-manager.sharedModules`.

```nix
{ config, lib, ... }:

let
  toHomeRelativePath = import ../../../lib/to-home-relative-path.nix { inherit config lib; };
in
{
  # Credentials and history. The completion cache beside them is regenerable
  # and deliberately not persisted.
  home.persistence.main.directories = [
    {
      directory = toHomeRelativePath config.myApp.stateDirectory;
      mode = "0700";
    }
  ];

  myApp.stateDirectory = "${config.defaultDirectories.localDirectory}/state/my-app";
}
```

If an app rewrites a file via temp-file + rename, persist the containing
directory rather than bind-mounting the file. `impermanence/fish.nix` and
`impermanence/ssh.nix` both give a directory to a single file for this reason.

## Validation checklist

Before final response:

- Run `nix fmt` on touched Nix files.
- If you added/changed a manually pinned upstream package, build it and record the pinned version in the change description; nothing bumps it for you.
- Build the affected host:
  ```bash
  nix build --no-link .#nixosConfigurations.murph.config.system.build.toplevel
  ```
- Check that the portable module stayed portable:
  ```bash
  rg -n 'persist|localDirectory|/local/' nix/modules/home/<app>.nix
  ```
  Prose hits are fine — several modules mention persistence in a comment
  explaining what they deliberately leave alone. A hit in a *path the module
  actually uses* is the failure, and belongs in
  `nix/modules/home/impermanence/<app>.nix` instead. `directories.nix` and
  `local-directory.nix` are the layout modules and legitimately own these names.
- If adding a new file and the build says it is not tracked by Git, run `git add -N <file>` and build again.
- Optionally inspect generated tmpfiles rules for path escaping/symlinks:
  ```bash
  out=$(nix build --no-link --print-out-paths .#nixosConfigurations.murph.config.system.build.toplevel)
  nix path-info -r "$out" | rg 'tmpfiles.d|nixos-tmpfiles'
  rg -n '<app-name>' /nix/store/*tmpfiles.d* -S
  ```
- If practical, run the wrapped app with temporary dirs to confirm state lands where expected.

## Final response expectations

Summarize:

- files changed
- package/module added
- persistence path(s)
- which state is declarative/store-backed, persisted, and ephemeral
- validation commands run

Keep the response concise, but include enough context for the user to verify the impermanence choices.
