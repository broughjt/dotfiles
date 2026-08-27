## This machine

- A fly.io sprite: persistent Ubuntu 26.04 VM.
- Nix is installed in single-user mode, with the store owned by the login user.
  There is no `nix-daemon`.
- Flake evaluation cannot read `$HOME`, so unfree packages need `--impure`: `nix
  run --impure nixpkgs#<package>`. `nix-shell` and `nix develop` do not.
- There is no systemd. A process that must outlive the command that started it
  has to be registered with `sprite-env services create`, or it will die when
  the sprite pauses.
