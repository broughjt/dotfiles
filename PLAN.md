# Plan: split `flake.nix` into multiple files

## Goal

Refactor the monolithic `flake.nix` into smaller Nix files while preserving the current public flake interface and behavior:

- `nixosModules.*`
- `nixosConfigurations.murph`
- `nixosConfigurations.tars`
- `vaultix`
- `templates.*`
- per-system `devShells.default`
- per-system `checks.emacs-byte-compile`

## Proposed file layout

Use a `nix/` directory, but keep final output wiring in `flake.nix` rather than adding a separate `nix/outputs.nix`.

```text
flake.nix                         # description, nixConfig, inputs, and final outputs wiring
nix/
  modules/
    default.nix                   # exports the `nixosModules` attrset
    personal.nix
    nix-settings.nix
    linux-base.nix
    docker.nix
    tailscale.nix
    home/
      directories.nix
      linux.nix
      gnome-desktop.nix
      dconf.nix
      gh.nix
      gpg.nix
      pass.nix
      vaultix-secrets.nix
      pi-coding-agent.nix
      kakoune.nix
      emacs.nix
    hosts/
      murph-hardware.nix
      tars-hardware.nix
      tars-access.nix
      tars-base.nix
  hosts/
    murph.nix                     # builds `nixosConfigurations.murph`
    tars.nix                      # builds `nixosConfigurations.tars`
  packages/
    emacs.nix                     # `configureEmacsPackage`
    pi-web-minimal.nix
    pi-system-prompt.nix
  templates.nix
  pkgs.nix                        # shared per-system package-set constructor
  shell.nix                       # `devShells.default`
  checks.nix                      # per-system checks
  formatter.nix                   # `formatter` for `nix fmt`
```

## Refactor approach

1. **Keep `flake.nix` as the stable entry point and output assembler**
   - Leave `description`, `nixConfig`, and `inputs` in `flake.nix`.
   - Keep the final `outputs` wiring in `flake.nix`.
   - Import extracted helper/package/module/host/template/per-system files from inside the `outputs` body.
   - Do not add `nix/outputs.nix`.

2. **Extract package/helper functions first**
   - Move Emacs package construction to `nix/packages/emacs.nix`:
     - `configureEmacsPackage`
   - Move Pi package derivations to separate package files:
     - `piWebMinimalPackage`
     - `piSystemPromptPackage` (available but disabled by default)
   - Carefully update relative paths, e.g. `../../emacs`, `../../pi/pi-web-minimal-package-lock.json`.

3. **Extract NixOS/Home Manager modules**
   - Move each current `nixosModules` member into an equivalent file.
   - Use the approved public module renames listed below.
   - Use closures from `nix/modules/default.nix` to pass dependencies like `home-manager`, `emacs-overlay`, `llm-agents-nix`, `vaultix`, `nixos-raspberrypi`, and package helpers.
   - This factory-style `default.nix` keeps exported modules self-contained and avoids requiring downstream users to remember extra `specialArgs`.
   - Keep cross-module imports equivalent to the existing `rec` attrset, e.g. `gnomeDesktop` imports `dconf`, `tarsBase` imports its component modules.

4. **Extract host configuration assembly**
   - Move the `nixosSystem` calls into:
     - `nix/hosts/murph.nix`
     - `nix/hosts/tars.nix`
   - Keep module lists identical and in the same order unless there is a clear reason to change them.
   - Preserve existing `specialArgs` behavior:
     - `murph`: `{ inherit inputs self; }`
     - `tars`: current `inputs`-based special args and Raspberry Pi system constructor behavior.

5. **Extract templates and per-system outputs**
   - Move `templates` to `nix/templates.nix`, updating paths to `../templates/...`.
   - Keep `flake-utils.lib.eachDefaultSystem` wiring inline in `flake.nix`.
   - Split per-system output definitions into `nix/shell.nix` for `devShells.default`, `nix/checks.nix` for checks, and `nix/formatter.nix` for `nix fmt`.
   - Put shared per-system `pkgs` construction in `nix/pkgs.nix`.

6. **Wire everything in `flake.nix`**
   - Import package helpers.
   - Build `nixosModules`.
   - Build `nixosConfigurations` using those modules.
   - Configure `vaultix` after `nixosConfigurations` are available.
   - Import templates from `nix/templates.nix`.
   - Use `flake-utils.lib.eachDefaultSystem` inline to merge per-system outputs from `nix/shell.nix`, `nix/checks.nix`, and `nix/formatter.nix`.

7. **Validate after refactor**
   - Run Nix formatting on changed Nix files.
   - Run at least:
     ```sh
     nix flake check
     nix eval .#nixosConfigurations.murph.config.system.build.toplevel.drvPath
     nix eval .#nixosConfigurations.tars.config.system.build.toplevel.drvPath
     nix flake show
     ```
   - If `nix flake check` is too slow or requires unavailable resources, run narrower evaluations and report what was/was not validated.

## Compatibility constraints

- Do not change flake inputs or `flake.lock`.
- Do not rename public output attributes except for the approved `nixosModules` renames listed below.
- Do not change NixOS/Home Manager option values.
- Preserve comments where practical, especially explanatory comments around Vaultix and Pi package config.
- Prefer small, mechanical moves over semantic cleanup.

## Approved `nixosModules` public names

Most current names remain unchanged. The approved renames are:

| Current name | New name |
|---|---|
| `packageManager` | `nixSettings` |
| `userLinux` | `linuxBase` |
| `defaultDirectories` | `homeDirectories` |
| `homeLinuxGraphical` | `gnomeDesktop` |
| `vaultixConfiguration` | `vaultixSecrets` |
| `piConfiguration` | `piCodingAgent` |
| `kakouneConfiguration` | `kakoune` |
| `emacsConfiguration` | `emacs` |

The resulting `nixosModules` attrset should be:

```text
personal
nixSettings
tarsHardware
tarsAccess
tarsBase
murphHardware
linuxBase
docker
homeDirectories
homeLinux
gnomeDesktop
dconf
gh
gpg
pass
vaultixSecrets
piCodingAgent
kakoune
tailscale
emacs
```

## Resolved design decisions

1. Use the proposed `nix/` directory layout with the edits captured above.
2. Use one file per current `nixosModules` member.
3. Rename only the explicitly approved `nixosModules` attributes above.
4. Use a `nix/modules/default.nix` factory that closes over flake inputs/helper functions and returns a self-contained `nixosModules` attrset.
5. Keep output wiring in `flake.nix`; do not create `nix/outputs.nix` or `nix/dev.nix`.
6. Use `nix flake check` as the main validation even if it performs the Emacs byte-compile check.
7. Allow tiny cleanup improvements that improve readability without changing behavior.

## Remaining questions before implementation

None. With the decisions above, this refactor should be implementable cleanly in one pass.
