## This machine

- A fly.io sprite: persistent Ubuntu 26.04 VM.
- Nix is installed in single-user mode, with the store owned by the login user.
  There is no `nix-daemon`.
- Flake evaluation cannot read `$HOME`, so unfree packages need `--impure`: `nix
  run --impure nixpkgs#<package>`. `nix-shell` and `nix develop` do not.
- Get tools from Nix, not from the language shims in `/.sprite/bin`.
- No systemd. A process that must outlive the command that started it has to be
  registered with `sprite-env services create`, or it dies when the sprite
  pauses.
- Use the `sprite` skill for services, checkpoints, and system configuration.
  Platform details are in `/.sprite/llm.txt` and `/.sprite/llm-dev.txt`.
- Sprite URLs can be made public. Never create an HTTP endpoint that exposes
  environment variables, credentials, or file contents.
- Reach external APIs through the gateway at `api.sprites.dev`, which injects
  credentials; never use a raw API key. The `sprite-api-gateway` skill has the
  details.
