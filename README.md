<p align="center">
  <img src="assets/is-this-your-homework-larry.png" alt="Is this your homework, Larry?" width="760">
</p>

<h1 align="center">Are these your dotfiles, Larry?</h1>

<p align="center">
  <a href="https://nixos.org"><img alt="NixOS unstable" src="https://img.shields.io/badge/NixOS-unstable-5277C3?style=flat-square&logo=nixos&logoColor=white"></a>
  <a href="https://github.com/nix-community/home-manager"><img alt="Home Manager" src="https://img.shields.io/badge/Home_Manager-enabled-7E7EFF?style=flat-square"></a>
  <a href="https://github.com/nix-community/disko"><img alt="disko" src="https://img.shields.io/badge/disko-ZFS-41439A?style=flat-square"></a>
</p>

A personal NixOS flake for my machines, development templates, agent tooling,
and the small amount of ceremony required to make an impermanent workstation
feel like home again.

> [!IMPORTANT]
> This repository is infrastructure, not a distribution. It contains hardcoded
> users, hardware, disks, SSH/GPG assumptions, and opinions. Steal ideas freely;
> do not run it blindly unless you are me or you enjoy reinstalling computers.

---

## At a glance

| Area | Choice |
| --- | --- |
| OS | NixOS unstable flakes |
| System config | NixOS modules + Home Manager |
| Workstation | GNOME, PipeWire, Firefox, Ghostty |
| Shell/editor | fish, tmux, Emacs |
| Storage | disko-managed encrypted ZFS |
| Persistence | impermanence with explicit state bundles |
| Secrets | Vaultix / age |
| Agents | Pi Coding Agent, Claude Code, Context7/Exa helpers |

## Hosts

- `murph` — primary workstation profile.
- `murph-install` — smaller bootstrap profile used by the installer.
- `tars` — Raspberry Pi profile via `nixos-raspberrypi`.

```sh
# Build a host without switching.
nix build .#nixosConfigurations.murph.config.system.build.toplevel

# Switch the current machine to murph.
sudo nixos-rebuild switch --flake .#murph
```

## Useful commands

```sh
# Enter the development shell.
nix develop

# Run checks / formatter.
nix flake check
nix fmt

# Destructive workstation installer. Read the warning below first.
nix run github:broughjt/dotfiles#installMurph -- --help

# Backup/restore murph state bundles.
nix run .#backupMurph -- --help
nix run .#restoreMurph -- --help

# Print the Pi agent system prompt used by this repo.
nix run .#piPrintSystemPrompt
```

> [!WARNING]
> `installMurph` is intentionally specific to my workstation and its disk ID.
> It partitions, formats, and installs using `disko-install`. Read
> [`INSTALL.md`](INSTALL.md), [`INSTALL2.md`](INSTALL2.md), and
> [`scripts/install-murph.sh`](scripts/install-murph.sh) before touching it.

## Templates

This flake also ships project starters:

```sh
nix flake init -t github:broughjt/dotfiles#rust
nix flake init -t github:broughjt/dotfiles#python
nix flake init -t github:broughjt/dotfiles#haskell
nix flake init -t github:broughjt/dotfiles#rocq
nix flake init -t github:broughjt/dotfiles#typst-homework
```

## Repository map

```text
emacs/          Store-backed Emacs init files
nix/hosts/      Flake host entry points
nix/modules/    NixOS and Home Manager modules
nix/packages/   Local package/app definitions
pi/             Pi Coding Agent instructions and package locks
scripts/        Installer, backup, restore, and utility scripts
secrets/        Encrypted Vaultix secrets
templates/      Reusable flake templates
```

## Philosophy

The goal is not to hide NixOS complexity behind a framework. The goal is to
make system state legible: every durable file should be either declared here,
encrypted here, or consciously restored from a named backup bundle.

If a reboot makes it disappear, that was probably the point.
