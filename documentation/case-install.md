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
| Credentials | Issued to the fleet and staged after the install (see below) |

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

The `gh` cli and both `claude` and `codex` all need to have authentication set
up.

| Tool | Credential | Path on `case` | Targeted by |
| --- | --- | --- | --- |
| `gh` | fine-grained PAT | `~/.config/gh/token` | `gh.tokenFile` |
| `claude` | `claude setup-token` | `~/.claude/oauth-token` | `claudeCode.oauthTokenFile` |
| `codex` | login on the VM | `~/.codex/auth.json` | `codex` itself |

**Once per fleet.** Create a **fine-grained** PAT at
<https://github.com/settings/personal-access-tokens>, scoped to one owner and to
the relevant repositories. For permissions, set `Contents: Read and write` for
fetch and push, `Metadata: Read`, which is selected for you, and `Pull requests:
Read and write` if agents are expected to open PRs. `claude setup-token` mints a
long-lived credential distinct intended for use on headless machines.

```sh
pass insert case/github-pat
claude setup-token
pass insert case/claude-oauth-token
```

**Once per VM.**

```sh
pass show case/github-pat | ssh case1 'install -D -m 0600 /dev/stdin ~/.config/gh/token'
pass show case/claude-oauth-token | ssh case1 'install -D -m 0600 /dev/stdin ~/.claude/oauth-token'
ssh -L 1455:localhost:1455 case1 'codex login'
```

`codex` is logged in on the VM because its callback is on localhost port 1455,
so the flow completes only over a forwarded port. Both non-interactive flags are
dead ends: `--device-auth` is blocked on a University of Utah enterprise
account, and `--with-access-token` requires an agent identity JWT rather than a
ChatGPT one.

Verify all three:

```sh
ssh case1 'gh auth status'
ssh case1 'codex login status'
ssh case1 'claude -p "reply with ok"'
```

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

## Removal

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
