# Vaultix secrets

Encrypted `*.age` files and `cache/` entries are intended to be committed.

Do not commit plaintext secrets or local identity/private-key files. The Vaultix edit/renc identity is configured as a string path in `flake.nix` so it is not copied into the Nix store.

Initial Pi web-search secrets:

```sh
nix run .#vaultix.app.x86_64-linux.edit -- ./secrets/exa-api-key.age
nix run .#vaultix.app.x86_64-linux.edit -- ./secrets/context7-api-key.age
nix run .#vaultix.app.x86_64-linux.renc
```
