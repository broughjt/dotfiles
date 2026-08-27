#!/usr/bin/env bash
set -euo pipefail

# The half of sprite-provision that runs inside the sprite. It is pushed there
# by scripts/sprite-provision.sh along with the files/ tree it installs from.
# Everything here resolves against the sprite's own PATH; no murph store path
# exists on this machine.

NIX_INSTALL_URL="https://nixos.org/nix/install"

PAYLOAD_DIRECTORY=$(cd "$(dirname "$0")" && pwd)
FILES_DIRECTORY="$PAYLOAD_DIRECTORY/files"

main() {
  # Detect whether this is indeed a sprite. Every sprite has this directory;
  # nothing else does. Running on something which isn't a sprite would be bad.
  [ -d /.sprite ] || die "this is not a sprite"

  WORKDIR=$(mktemp -d -t sprite-provision.XXXXXX)
  trap 'rm -rf "$WORKDIR"' EXIT

  install_nix
  write_nix_conf
  write_nixpkgs_config
  link_nix_binaries
  write_agent_instructions

  info "done"
}

install_nix() {
  if [ -e "$HOME/.nix-profile/bin/nix" ]; then
    info "nix is already installed"
    return 0
  fi

  # Single-user mode: one user owns the store and there is no daemon, which is
  # what a sprite can support -- it has no systemd to run a daemon under.
  #
  # The installer creates /nix, but chowns it to $USER, which isn't usually set
  # in a sprite. The chown fails on the empty name, and the mkdir it already ran
  # leaves /nix owned by root--which every later attempt misreads as a rival
  # single-user installation. id -un avoids the whole thing.
  if [ ! -d /nix ]; then
    info "creating /nix owned by $(id -un)"
    sudo install -d -m 0755 -o "$(id -un)" -g "$(id -gn)" /nix
  fi

  local installer="$WORKDIR/nix-install.sh"
  info "downloading the Nix installer from $NIX_INSTALL_URL"
  curl --fail --location --show-error --silent --output "$installer" "$NIX_INSTALL_URL"

  # --no-channel-add: channels are disabled on murph as well. write_nix_conf
  #   points <nixpkgs> at the flake registry instead.
  # --no-modify-profile: the installer appends to ~/.profile, which only login
  #   shells read, and `sprite exec` runs neither a login nor an interactive
  #   shell. link_nix_binaries handles PATH in a way both can see.
  # </dev/null: provisioning is never interactive, so refuse the installer any
  #   stdin to prompt on rather than depending on what `sprite exec` hands us.
  info "installing single-user Nix"
  sh "$installer" --no-daemon --no-channel-add --no-modify-profile < /dev/null
}

write_nix_conf() {
  local conf="$HOME/.config/nix/nix.conf"

  info "writing $conf"
  mkdir -p "$(dirname "$conf")"
  # Written in full every run rather than edited, so the file cannot drift.
  #
  # nix-path points <nixpkgs> at the flake registry so that `nix-shell -p`
  # works without a channel, matching murph's NIX_PATH=nixpkgs=flake:nixpkgs.
  #
  # accept-flake-config lets the dotfiles flake offer its own extra caches
  # instead of duplicating the substituter list from nix/nix-config.nix here.
  cat > "$conf" <<'EOF'
experimental-features = nix-command flakes
accept-flake-config = true
nix-path = nixpkgs=flake:nixpkgs
EOF
}

write_nixpkgs_config() {
  local config="$HOME/.config/nixpkgs/config.nix"

  # Not to be confused with nix.conf above. That configures Nix itself, while
  # this configures nixpkgs evaluation, and `allowUnfree` only exists
  # here. Matches `nixpkgsConfig` in nix/nix-config.nix.
  info "writing $config"
  mkdir -p "$(dirname "$config")"
  cat > "$config" <<'EOF'
{ allowUnfree = true; }
EOF
}

link_nix_binaries() {
  local bin_dir="$HOME/.local/bin"
  local target

  # `sprite exec` runs with a fixed PATH and reads no shell startup file, so a
  # profile snippet would never be seen from murph. ~/.local/bin is already
  # first on that PATH and on an interactive shell's, so linking here reaches
  # `sprite exec`, `sprite console`, and agents running inside the sprite.
  info "linking Nix binaries into $bin_dir"
  mkdir -p "$bin_dir"
  # Matching nix and nix-* rather than the whole profile keeps a later
  # `nix profile install` from quietly linking unrelated binaries in here.
  for target in "$HOME"/.nix-profile/bin/nix "$HOME"/.nix-profile/bin/nix-*; do
    [ -e "$target" ] || continue
    ln -sfn "$target" "$bin_dir/$(basename "$target")"
  done
}

write_agent_instructions() {
  local target="$HOME/.claude/CLAUDE.md"

  # Assembled by nix/packages/agent-instructions.nix from the same fragments
  # murph's copy is built from, with machines/sprite.md as the machine section.
  # Claude Code reads CLAUDE.md rather than AGENTS.md.
  info "writing $target"
  mkdir -p "$(dirname "$target")"
  # install rather than cp: pushed files keep the read-only mode they had in
  # the store, and cp would propagate it to the copy.
  install -m 0644 "$FILES_DIRECTORY/CLAUDE.md" "$target"
}

die() {
  echo "error: $*" >&2
  exit 1
}

info() {
  echo "info: $*"
}

main "$@"
