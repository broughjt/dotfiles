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
hcloud context create context1   # paste an API token from the Cloud Console
hcloud ssh-key create --name murph --public-key-from-file ~/local/secrets/ssh/id_ed25519.pub
```

Create a Tailscale auth key that is **reusable**, **pre-approved** and
**ephemeral** at <https://login.tailscale.com/admin/settings/keys>, and save it:

```sh
pass insert case/tailscale-authkey
```

This key is what lets a new VM join the tailnet unattended. `case` closes public
SSH and trusts only `tailscale0`, so a VM installed without it has no route in
and has to be recovered through the Hetzner console or rescue system.

### Tailscale SSH

Regular SSH asks "which key do you have?" Tailscale SSH asks "which tailnet node
are you?" `tailscaled` takes over port 22 on the tailnet address and accepts
callers on the strength of the identity supplied by the tailnet. Any SSH client
on a device running Tailscale can then log in without normal SSH keys (e.g. the
iPhone). The rules for which devices are allowed to SSH into which other devices
is determined by a part of the tailnet policy file. The default behavior is to
deny any Tailscale SSH connections. Since tailscale is our only route into the
`case` VMs, we need to grant access before installing.

The visual editor in Tailscale does not expose the `users` field, so the policy
has to be edited as a file regardless. It lives in this repository at
`tailscale/policy.hujson` and is applied from a checkout:

```sh
nix run .#applyTailnetPolicy               # diff, validate, confirm, apply
nix run .#applyTailnetPolicy -- --dry-run  # everything except the write
nix run .#applyTailnetPolicy -- --fetch    # reseed the file from the console
```

The `accept` bit in its `ssh` block is what we need to access `case` VMs.

```json
"ssh": [
  {
    "action": "accept",
    "src":    ["autogroup:member"],
    "dst":    ["autogroup:self"],
    "users":  ["autogroup:nonroot", "root"]
  }
]
```

Tailscale's default ships that rule with `"action": "check"`, which works but
forces a periodic browser re-authentication, a poor fit for a phone.

The credential is an **OAuth client** carrying the `policy_file` scope, from
<https://login.tailscale.com/admin/settings/oauth>, stored as two entries:

```sh
pass insert tailscale/policy-oauth-client-id
pass insert tailscale/policy-oauth-secret
```

## Install

```sh
nix run .#installCase -- <name> 2>&1 | tee ~/scratch/<name>-install.log
```

The `<name>` field is used for the hostname, the tailnet name, and Hetzner's
name for the server by, so use the same name for the rest of this guide.

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
nix run .#installCase -- <name> --target 1.2.3.4 2>&1 | tee ~/scratch/<name>-install.log
```

Do not pass `--build-on-remote`: murph and `case` are both x86_64, so building
locally and copying the closure is faster and does not need RAM on a 4 GB VM.

## After the install

The VM should appear on the tailnet under the name it was created with. Check
from murph:

```sh
tailscale status | grep <name>
ssh <name>
```

### Credentials

The `gh` cli and both `claude` and `codex` all need to have authentication set
up.

| Tool | Credential | Path on `case` |
| --- | --- | --- |
| `gh` | classic PAT | `~/.config/gh/token` |
| `claude` | login on the VM | `~/.claude/.credentials.json` |
| `codex` | login on the VM | `~/.codex/auth.json` |

**Once per fleet.** Create a classic GitHub token at
<https://github.com/settings/tokens> (a fine-grained one reaches a single
account or organisation, and we need access to several). Make a new one for the
fleet rather than copying murph's, so either can be revoked without breaking the
other, and give it an expiration. Two scopes beyond `repo` are worth setting
deliberately:

- `read:org`, so `gh` can resolve organisation membership and list org
  repositories.
- `workflow`, without which a push is rejected the moment it touches a file
  under `.github/workflows/`, with `refusing to allow a Personal Access Token
  to create or update workflow`. Nothing else about the push fails, so it
  surfaces only when an agent happens to edit a workflow.

```sh
pass insert case/github-pat
```

**Once per VM.**

```sh
pass show case/github-pat | ssh <name> 'umask 077; mkdir -p ~/.config/gh; cat > ~/.config/gh/token'
ssh -t <name> claude    # then /login, and click through the first-run prompts
ssh -L 1455:localhost:1455 <name> 'codex login'
```

Verify all three:

```sh
ssh <name> 'gh auth status'
ssh <name> 'gh api repos/<owner>/<repo>/collaborators --jq length'
ssh <name> 'codex login status'
ssh <name> 'claude -p "reply with ok"'
```

`gh auth status` only proves the token authenticates. The second command names a
repository agents will work in and asks for something push-gated, which is what
actually fails when the token is wrong; `gh repo view` and `git ls-remote`
answer from any token at all against a public repository.

## Updating

```sh
nixos-rebuild switch --flake .#case --target-host root@<name>
```

## Recovery

`case` is reachable only over the tailnet, so `tailscaled` is the single path
back in and a daemon that will not start is a lost VM. `case/access.nix`
therefore gives `tailscaled` a bounded `TimeoutStopSec`, a `RestartSec`, and
`StartLimitAction=reboot` after five failed starts in half an hour. **A `case`
VM that reboots itself is expected behaviour, not a fault**: it means
`tailscaled` failed repeatedly and the reboot is clearing whatever held the TUN
device. `/var/lib/tailscale` is ordinary disk state here, so the node rejoins at
the same address. Check `journalctl -b -1 -u tailscaled` after one.

This was added 2026-09-01, after `tailscaled` deadlocked (its own `ipnlocal`
watchdog reported it), exited, and then failed to restart twice, taking
`tailscale0` down and leaving the VM unreachable while it was otherwise
healthy. Note that `WatchdogSec` is not usable here: `tailscaled` sends
`READY=1` through `sd_notify` but never `WATCHDOG=1`, so a systemd watchdog
would kill a healthy daemon.

In order of preference:

1. **Tailnet SSH** — the normal path.
2. **Hetzner console** (`https://console.hetzner.cloud`) if the VM boots but
   never joins the tailnet. The console's password reset works through the QEMU
   guest agent, which `case/hardware.nix` enables for exactly this reason. Note
   that `users.mutableUsers = false`, so a password set this way is reverted by
   the next `nixos-rebuild switch`; it is a way in, not a lasting change.
3. **Rescue system** if it does not boot at all:

   ```sh
   hcloud server enable-rescue <name>
   hcloud server reset <name>
   ```

   That boots a separate Linux with its own root access, so it needs no password
   on the installed system. Mount the disk, fix, `hcloud server disable-rescue`,
   reboot.

Rebuilding from scratch is usually cheaper than any of these:

```sh
hcloud server delete <name>
nix run .#installCase -- <name>
```

## Removal

```sh
hcloud server delete <name>
```

Tailscale will remove the ephemeral node 30 to 60 minutes after its last
activity. Delete the node in the admin console if you want it gone sooner.
