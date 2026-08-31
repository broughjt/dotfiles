# Case install

`case` is a Hetzner Cloud VM intended as an environment for coding agents. The
idea is that a single `nixosConfigurations.case` should serve as configuration
for a fleet of `case` VMs. Adding a new `case` VM shouldn't require any
configuration changes to this git repository. Everything in the following list
can be maintained statefully outside of Nix, which is why this works.

| State | Where it comes from |
| --- | --- |
| Hostname | Hetzner metadata, via cloud-init, from `hcloud server create --name` |
| Network address, IPv6, interface name | Hetzner metadata, via cloud-init |
| SSH host keys | Generated during the install |
| Tailnet identity | A pre-auth key staged with `nixos-anywhere --extra-files` |
| Agent credentials | Copied from murph after the install (see below) |

## One-time setup

Obtain an API key following <https://docs.hetzner.com/cloud/api/getting-started/generating-api-token/>. Then create a "context" and register murph's public SSH key.

```sh
hcloud context create personal   # paste an API token from the Cloud Console
hcloud ssh-key create --name murph --public-key-from-file ~/local/secrets/ssh/id_ed25519.pub
```

Create a Tailscale auth key that is **reusable** and **pre-approved** at
<https://login.tailscale.com/admin/settings/keys>, and save it:

```sh
pass insert case/tailscale-authkey
```

This key is what lets a new VM join the tailnet unattended. `case` closes public
SSH and trusts only `tailscale0`, so a VM installed without it has no route in
and has to be recovered through the Hetzner console or rescue system.

## Install

```sh
nix run .#installCase -- case1 2>&1 | tee ~/scratch/case-install.log
```

The install prints thousands of lines and will outrun the terminal scrollback,
so run with `tee` to keep a copy of the output. Ghostty can also dump its buffer
to a file with `ctrl+shift+j`, bound in `nix/modules/home/ghostty.nix`.

The script prints the type, location and monthly price and asks before creating
anything. 

Defaults are `cx23` (2 vCPU / 4 GB) in `fsn1`. It then waits for SSH, stages the
auth key at `/var/lib/tailscale-authkey`, and runs `nixos-anywhere`. We target
Falkenstein because US locations cost roughly six times as much. Also, there
aren't any arm64 CAX instance types in the US apparently. Use `hcloud location
list` to see the other location options.

To install onto a server that already exists:

```sh
nix run .#installCase -- case1 --target 1.2.3.4 2>&1 | tee ~/scratch/case-install.log
```

Do not pass `--build-on-remote`: murph and `case` are both x86_64, so building
locally and copying the closure is faster and does not need RAM on a 4 GB VM.

## After the install

The VM should appear on the tailnet under the name it was created with. Check
from murph:

```sh
tailscale status | grep case1
ssh case1
```

### Credentials

Three tools need authenticating: `gh` (the GitHub CLI, for API access and git
pushes), `claude`, and `codex`. `case` keeps the upstream default paths rather
than murph's `~/local` layout:

| Tool | Path on `case` | Path on murph |
| --- | --- | --- |
| `gh` | `~/.config/gh/hosts.yml` | keyring, **not** a file -- see below |
| `claude` | `~/.claude/.credentials.json` | `~/local/state/claude-code/.credentials.json` |
| `codex` | `~/.codex/auth.json` | `~/local/state/codex/auth.json` |

None of these credentials are bound to a machine: they are bearer tokens with no
device key or hardware attestation, so copying them technically works. Whether
it is a good idea differs per tool.

**`gh` -- do not copy, and the file would not work anyway.** On murph the token
is in the GNOME keyring (`gh auth status` reports `(keyring)`), so
`~/local/config/gh/hosts.yml` holds no credential. `case` is headless and has no
keyring, so `gh` there falls back to writing the token into `hosts.yml`.
Transfer therefore has to go through `gh` itself:

```sh
gh auth token | ssh case1 'gh auth login --with-token'
```

Better still, give the fleet its own credential. murph's token carries the
`repo` scope -- read/write to every repository -- and one token shared across
every VM cannot be revoked for one machine alone. A fine-grained PAT scoped to
the repositories a `case` VM actually needs is independently revocable and
smaller in blast radius:

```sh
ssh case1 'gh auth login --with-token'   # paste the PAT, then Ctrl-D
```

A PAT also lets `case` push over HTTPS, which is worth weighing against
`programs.gh`'s `git_protocol = "ssh"`: with HTTPS the VM needs no outbound SSH
key at all.

**`claude` and `codex` -- prefer logging in on the VM.** Both store an OAuth
access token *and* a refresh token (`claude`: `refreshToken`,
`refreshTokenExpiresAt`; `codex`: `tokens.refresh_token`, `last_refresh`).
Copying one refresh token to a second machine means both hold the same
credential, and if the provider rotates refresh tokens on use, whichever machine
refreshes first silently invalidates the other -- which surfaces later as a
random logout on murph rather than as an error on `case`. Rotation is not
confirmed for either provider, so treat it as a risk to avoid rather than a
certainty.

```sh
ssh case1
claude          # follow the browser prompt
codex login
```

`codex login` uses a localhost callback on port 1455, so it only completes over
a forwarded port:

```sh
ssh -L 1455:localhost:1455 case1
```

If the per-VM login tax becomes real at fleet scale, the answer is a separate
account or credential issued to the fleet, not murph's own credential copied
around.

`gh auth status` verifies the first. There is no confirmed non-interactive check
for `claude` or `codex`; run each once and see that it starts.

## Updating

```sh
nixos-rebuild switch --flake .#case --target-host root@case1
```

## Recovery

In order of preference:

1. **Tailnet SSH** — the normal path.
2. **Hetzner console** (`https://console.hetzner.cloud`) if the VM boots but
   never joins the tailnet. The console's password reset works through the QEMU
   guest agent, which `case/hardware.nix` enables for exactly this reason. Note
   that `users.mutableUsers = false`, so a password set this way is reverted by
   the next `nixos-rebuild switch`; it is a way in, not a lasting change.
3. **Rescue system** if it does not boot at all:

   ```sh
   hcloud server enable-rescue case1
   hcloud server reset case1
   ```

   That boots a separate Linux with its own root access, so it needs no password
   on the installed system. Mount the disk, fix, `hcloud server disable-rescue`,
   reboot.

Rebuilding from scratch is usually cheaper than any of these:

```sh
hcloud server delete case1
nix run .#installCase -- case1
```

## Removing a VM

```sh
ssh case1 'sudo tailscale logout'   # drops the node from the tailnet
hcloud server delete case1
```

If the VM is already gone, remove the stale node in the Tailscale admin console
instead. Making the auth key **ephemeral** as well as reusable would let
Tailscale drop nodes on its own once they stop responding, at the cost of the
tailnet forgetting a VM that is merely rebooting; set
`services.tailscale.authKeyParameters.ephemeral` in `case/access.nix` if the
fleet ever churns enough to want that.

Nothing in this repository needs to change to add or remove a VM.
