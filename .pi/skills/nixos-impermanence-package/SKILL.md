---
name: nixos-impermanence-package
description: Add packages/apps to this NixOS dotfiles repo and configure impermanence. Use when installing new packages, desktop apps, CLIs, or developer tools and deciding what should be store-backed/declarative, persisted statefully, or left ephemeral.
---

# NixOS Impermanence Package Setup

Use this skill when adding or changing installed packages/apps in this dotfiles repo, especially when the user asks to configure persistence/impermanence.

## First: read the local patterns

Before editing, inspect the relevant existing modules. At minimum, read:

- `.
- `nix/modules/home/directories.nix` and `nix/modules/home/linux.nix` for the XDG/local directory layout.
- `nix/modules/hosts/murph-user-persistence.nix` for user impermanence declarations.
- The module most similar to the requested app:
  - desktop bundle: `nix/modules/home/desktop-apps.nix`
  - dedicated desktop app: `nix/modules/home/firefox.nix`, `nix/modules/home/vlc.nix`
  - CLI config: `nix/modules/home/gh.nix`
  - complex app-specific state split: `nix/modules/home/pi-coding-agent.nix`, `nix/modules/home/claude-code.nix`, `nix/modules/home/emacs.nix`, `nix/modules/home/gpg.nix`
- `nix/modules/default.nix` and the target host such as `nix/hosts/murph.nix` if adding a new dedicated module.

## Repository conventions

The home layout intentionally avoids default dot-directories where possible:

- `config.defaultDirectories.localDirectory` is usually `~/local`.
- XDG dirs are set to `~/local/{config,cache,share,state}`.
- Secrets usually live under `~/local/secrets/...` with `0700` parents and `0600` files.
- Narrow mutable configuration/trust decisions sometimes live under `~/local/hacks/...`.
- User data meant for humans lives under `~/share`, `~/repositories`, or `~/scratch` as appropriate.

## Desired classification model

For every app, explicitly decide which state belongs in each bucket:

### 1. Store-backed / declarative

Prefer the Nix store for static config, packages, wrappers, generated config files, desktop entries, and bundled plugins/extensions/skills.

Common patterns:

- Use Home Manager `programs.*` options when they produce good declarative config.
- Use `home.file` / `xdg.configFile` for static config only when the app can read it read-only.
- Use a wrapper via `pkgs.symlinkJoin` + `pkgs.makeWrapper` or `pkgs.writeShellScriptBin` when the app needs flags/env vars to use the desired directories.
- For apps that do not respect XDG, set app-specific env vars or command-line flags if available.

### 2. Persisted state

Persist only state that is valuable, hard to recreate, or represents an explicit user/security decision:

- login sessions, auth tokens, credentials, keyrings
- browser/app profiles if they contain cookies, local storage, logins, extension state, or offline app data
- user preferences that are not otherwise declarative
- trust/allow decisions such as direnv allow/deny
- histories/projects/sessions the user expects to survive rollback/reboot
- app databases that are canonical or expensive to rebuild

Persist with the narrowest subtree that is safe. Use `environment.persistence."/persist".users.${user}.directories` in `nix/modules/hosts/murph-user-persistence.nix` for host persistence, with `mode = "0700"` for private app state.

Important: if an app rewrites a file via temp-file + rename, persist the containing directory rather than a single file bind mount. Existing examples: fish history, GnuPG keybox/trustdb.

### 3. Ephemeral state

Leave rebuildable/noisy state ephemeral, normally under `~/local/cache`, an ephemeral app runtime dir, or unpersisted XDG locations:

- HTTP/GPU/code/font caches
- logs, crash reports, sentry/minidump data
- sockets, locks, singleton files
- generated thumbnails/blob storage when not required for offline user data
- first-run prompts or local UI state the user does not care about
- updater downloads for apps managed by Nix

If an app mixes durable profile data and cache data in one directory, consider pointing the whole profile at a persisted location and symlinking cache subdirectories back to `~/local/cache/<app>`, as in `nix/modules/home/browser-tools.nix`.

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
   - For Electron apps, test whether `--user-data-dir=<dir>` relocates the profile. Use it to keep profile state explicit.
   - Inspect generated JSON/config/database names to infer durable vs cache state. Do not persist logs/crash/cache just because they are in a profile.

3. **Choose module placement**
   - Small, stateless desktop apps may stay in `desktop-apps.nix`.
   - Apps with wrappers, tmpfiles, activation scripts, or persistence decisions should get a dedicated `nix/modules/home/<app>.nix`.
   - Add dedicated modules to `nix/modules/default.nix` and the target host module list.

4. **Implement directory setup**
   - Use `systemd.tmpfiles.rules` to create ephemeral directories and symlinks at boot.
   - Use a `system.activationScripts.<name>` with `deps = [ "persist-files" ];` when a switch must repair/migrate directories before the next boot's tmpfiles run.
   - Escape spaces in tmpfiles paths, e.g. `tmpfilesEscape = lib.replaceStrings [ " " ] [ "\\x20" ];`.
   - Use `install -d -m <mode> -o ${user} -g users <path>` in activation scripts for ownership/mode repair.

5. **Declare impermanence**
   - Add persisted user directories to `nix/modules/hosts/murph-user-persistence.nix`.
   - Keep comments near each persistence entry explaining what is being persisted and what is intentionally ephemeral.
   - Use `0700` for profiles, auth, credentials, and other private state.

6. **Add the package**
   - Add the app/package/wrapper to `home-manager.users.${user}.home.packages` in the relevant module.
   - If adding overlays, follow existing overlay patterns and do not duplicate overlays unnecessarily.
   - If adding a custom derivation under `nix/packages/`, expose it as a buildable flake package when practical.
   - For every manually pinned upstream package (for example `fetchFromGitHub` with a fixed tag/rev), make an explicit update-automation decision: add/update `.github/ci/update-package.py` plus `.github/workflows/update-packages.yml`, or document why CI updates are intentionally not appropriate.

## Implementation patterns to copy

### Dedicated wrapped package

```nix
let
  user = config.personal.userName;
  localDirectory = config.defaultDirectories.localDirectory;
  appStateDir = "${localDirectory}/state/my-app";

  myAppPackage = pkgs.symlinkJoin {
    name = "my-app-local-state";
    paths = [ pkgs.my-app ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f "$out/bin/my-app"
      makeWrapper ${pkgs.my-app}/bin/my-app "$out/bin/my-app" \
        --set MY_APP_STATE ${lib.escapeShellArg appStateDir}
    '';
  };
in
{
  systemd.tmpfiles.rules = [
    "d ${appStateDir} 0700 ${user} users -"
  ];

  home-manager.users.${user}.home.packages = [ myAppPackage ];
}
```

### Persisted profile with ephemeral cache subdirs

Use this when an app stores durable profile files and caches together:

```nix
let
  profileDir = "${localDirectory}/state/my-app/profile";
  cacheDir = "${localDirectory}/cache/my-app";
  ephemeralDirs = [ "Cache" "Code Cache" "Crashpad" "logs" ];
  tmpfilesEscape = lib.replaceStrings [ " " ] [ "\\x20" ];
in
{
  system.activationScripts.prepareMyAppProfile = {
    deps = [ "persist-files" ];
    text = ''
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg profileDir}
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg cacheDir}
    ''
    + lib.concatMapStringsSep "\n" (name: ''
      install -d -m 0700 -o ${user} -g users ${lib.escapeShellArg "${cacheDir}/${name}"}
      rm -rf ${lib.escapeShellArg "${profileDir}/${name}"}
      ln -sfn ${lib.escapeShellArg "${cacheDir}/${name}"} ${lib.escapeShellArg "${profileDir}/${name}"}
    '') ephemeralDirs;
  };

  systemd.tmpfiles.rules = [
    "d ${profileDir} 0700 ${user} users -"
    "d ${cacheDir} 0700 ${user} users -"
  ]
  ++ map (name: "d ${tmpfilesEscape "${cacheDir}/${name}"} 0700 ${user} users -") ephemeralDirs
  ++ map (name: "L+ ${tmpfilesEscape "${profileDir}/${name}"} - - - - ${tmpfilesEscape "${cacheDir}/${name}"}") ephemeralDirs;
}
```

Add a matching persistence entry:

```nix
{
  directory = "local/state/my-app/profile";
  mode = "0700";
}
```

## Validation checklist

Before final response:

- Run `nix fmt` on touched Nix files.
- If you added/changed a manually pinned upstream package, verify the update-automation decision. When CI-updated, run `nix run nixpkgs#actionlint -- .github/workflows/update-packages.yml` and, when practical, `nix shell nixpkgs#python3 nixpkgs#nodejs nixpkgs#git -c .github/ci/update-package.py <package>`.
- Build the affected host:
  ```bash
  nix build --no-link .#nixosConfigurations.murph.config.system.build.toplevel
  ```
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
