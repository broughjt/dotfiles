#!/usr/bin/env bash
set -euo pipefail

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
  check_upstream_instructions
  write_agent_instructions
  sync_skills
  write_git_config
  write_fish_config

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

check_upstream_instructions() {
  local vendored="$FILES_DIRECTORY/upstream-codex-agents.md"
  local capture="$HOME/.codex/AGENTS.base.md"

  # The base image ships its own AGENTS.md. Keep the first one we see: after
  # this run the live file is ours, so the capture is the only record of what
  # the image had.
  mkdir -p "$(dirname "$capture")"
  if [ ! -e "$capture" ] && [ -e "$HOME/.codex/AGENTS.md" ]; then
    if cmp -s "$HOME/.codex/AGENTS.md" "$FILES_DIRECTORY/agent-instructions.md"; then
      die "$HOME/.codex/AGENTS.md is already ours and $capture is gone; restore it from a checkpoint, or provision a fresh sprite"
    fi
    info "recording the base image's instructions at $capture"
    cp "$HOME/.codex/AGENTS.md" "$capture"
  fi
  [ -e "$capture" ] || return 0

  # If the image's text has moved, that section was written against something
  # that no longer exists, so stop rather than install it.
  if ! diff -u "$vendored" "$capture" > "$WORKDIR/upstream.diff"; then
    cat "$WORKDIR/upstream.diff" >&2
    die "the base image's agent instructions have changed; re-read them against agents/machines/sprite.md, then re-vendor agents/machines/upstream/codex-agents.md"
  fi
}

write_agent_instructions() {
  local source="$FILES_DIRECTORY/agent-instructions.md"
  local target

  # Claude Code reads CLAUDE.md, Codex reads AGENTS.md, and both get the same
  # file. Codex's copy replaces the base image's rather than merging with it,
  # because machines/sprite.md already says what that file said.
  for target in "$HOME/.claude/CLAUDE.md" "$HOME/.codex/AGENTS.md"; do
    info "writing $target"
    mkdir -p "$(dirname "$target")"
    # install rather than cp: pushed files keep the read-only mode they had in
    # the store, and cp would propagate it to the copy.
    install -m 0644 "$source" "$target"
  done
}

sync_skills() {
  local target
  local shared
  local excludes=()

  # The base image installs its own skills into both agent directories, backed
  # by ~/.sprite-shared/skills. Deriving the exclude list from that directory
  # rather than naming sprite and sprite-api-gateway means --delete below keeps
  # its hands off whatever Fly ships, including anything they add later.
  for shared in "$HOME"/.sprite-shared/skills/*/; do
    [ -d "$shared" ] || continue
    excludes+=("--exclude=/$(basename "$shared")")
  done

  for target in "$HOME/.claude/skills" "$HOME/.codex/skills"; do
    info "syncing skills into $target"
    mkdir -p "$target"
    # --chmod because the pushed tree carries the store's read-only modes, and
    # --delete needs writable directories to remove anything from them.
    rsync --archive --delete --chmod=D755,F644 "${excludes[@]}" \
      "$FILES_DIRECTORY/skills/" "$target/"
  done
}

write_git_config() {
  local config="$HOME/.gitconfig"

  # The base image ships this file naming the committer Sprite
  # <noreply@sprites.dev>, so it is replaced rather than merged. Written in
  # full every run so it cannot drift.
  info "writing $config"
  cat > "$config" <<'EOF'
[user]
	name = Jackson Brough
	email = jacksontbrough@gmail.com
[init]
	defaultBranch = main
EOF
}

write_fish_config() {
  local config="$HOME/.config/fish/conf.d/dotfiles.fish"

  # A conf.d drop-in rather than config.fish, which the base image owns: it
  # sets the prompt and colours and sources /etc/profile.d/languages_env, none
  # of which this needs to touch.
  info "writing $config"
  mkdir -p "$(dirname "$config")"
  # eza is not installed here, so the alias waits for it rather than shadowing
  # ls with a command that does not exist.
  cat > "$config" <<'EOF'
set -g fish_key_bindings fish_vi_key_bindings

if type -q eza
    alias ls "eza --group-directories-first"
end
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

info() {
  echo "info: $*"
}

main "$@"
