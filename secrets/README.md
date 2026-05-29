# Secrets

Raw `.age` files are managed by agenix. Recipient rules live in `secrets.nix`.

```sh
cd secrets
nix run github:ryantm/agenix -- -e exa-api-key.age -i ~/local/secrets/ssh/id_ed25519
nix run github:ryantm/agenix -- -e context7-api-key.age -i ~/local/secrets/ssh/id_ed25519
```

On hosts where the same identity is available as `~/.ssh/id_ed25519`, the
explicit `-i ...` can be omitted.
