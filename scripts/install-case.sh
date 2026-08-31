# Provision a `case` VM on Hetzner Cloud and install NixOS onto it.
#
# One `nixosConfigurations.case` serves every `case` VM: the hostname comes from
# Hetzner's metadata by way of cloud-init, so adding a VM changes no file in
# this repository. The one thing a VM cannot derive is its tailnet identity, so
# a Tailscale pre-auth key is staged into the installed system with
# --extra-files. Without it the VM boots with no route in, because `case` closes
# public SSH and trusts only tailscale0.
#
# The key is read from the password store rather than a file, which is the
# pattern nixos-anywhere's own secrets documentation uses. Nothing on murph
# reads it from disk; only this script consumes it, once, per install.

set -euo pipefail

server_type=${CASE_SERVER_TYPE:-cx23}
location=${CASE_LOCATION:-fsn1}
image=${CASE_IMAGE:-debian-13}
ssh_key=${CASE_SSH_KEY:-murph}
authkey_entry=${CASE_TAILSCALE_AUTHKEY:-case/tailscale-authkey}
flake=${CASE_FLAKE:-@DOTFILES_FLAKE@}

usage() {
  cat <<'USAGE'
Usage:
  install-case <name>              Create a Hetzner Cloud VM and install NixOS
  install-case <name> --target IP  Install onto a server that already exists

Creating a server costs money. The script prints the type, location and price
and asks before it does so.

Environment:
  CASE_SERVER_TYPE              default cx23   (2 vCPU / 4 GB)
  CASE_LOCATION                 default fsn1   (Falkenstein; arm64 lives here too)
  CASE_IMAGE                    default debian-13 (only ever kexec'd away)
  CASE_SSH_KEY                  default murph  (name of the key in hcloud)
  CASE_TAILSCALE_AUTHKEY        default case/tailscale-authkey (a pass entry)
USAGE
}

if [ $# -lt 1 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  usage
  exit 1
fi

name=$1
shift
target=""
while [ $# -gt 0 ]; do
  case $1 in
    --target)
      target=${2:-}
      shift 2
      ;;
    *)
      echo "install-case: unknown argument '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# Only stdout is discarded, so the secret stays off the terminal while gpg's own
# diagnostics reach stderr. A failure here is as often a gpg problem as a
# missing entry, and the two need different fixes.
if ! pass show "$authkey_entry" >/dev/null; then
  echo >&2
  echo "install-case: could not read '$authkey_entry' from the password store." >&2
  echo "If the entry does not exist, create a reusable, pre-approved key at" >&2
  echo "https://login.tailscale.com/admin/settings/keys and run:" >&2
  echo "    pass insert $authkey_entry" >&2
  echo "If gpg reported a key error above, check that 'command -v gpg' is your" >&2
  echo "wrapped gpg rather than an unwrapped one earlier on PATH." >&2
  echo "CASE_TAILSCALE_AUTHKEY selects a different entry." >&2
  exit 1
fi

if [ -z "$target" ]; then
  # Check authentication before printing anything about creating a server, so a
  # missing token reads as a missing token rather than as a failure halfway
  # through the confirmation.
  if ! hcloud server list >/dev/null 2>&1; then
    echo "install-case: hcloud is not authenticated." >&2
    echo "HCLOUD_CONFIG is currently: ${HCLOUD_CONFIG:-unset}" >&2
    if [ -z "${HCLOUD_CONFIG:-}" ]; then
      echo "Unset means hcloud reads ~/.config/hcloud/cli.toml. This repository" >&2
      echo "points HCLOUD_CONFIG at \$XDG_CONFIG_HOME instead, and that variable" >&2
      echo "only reaches shells started after a fresh login. Log out and back in," >&2
      echo "or export it for this shell." >&2
    else
      echo "Run 'hcloud context create personal' and paste an API token." >&2
    fi
    exit 1
  fi

  echo "About to create a Hetzner Cloud server. This costs money."
  echo "  name:     $name"
  echo "  type:     $server_type"
  echo "  location: $location"
  echo "  image:    $image (replaced by the NixOS install)"
  # Cosmetic; never let a pricing lookup abort the run.
  hcloud server-type describe "$server_type" -o json 2>/dev/null |
    python3 -c "
import json, sys
t = json.load(sys.stdin)
p = [p for p in t['prices'] if p['location'] == '$location']
if p:
    print('  price:    EUR %.2f/month' % float(p[0]['price_monthly']['gross']))
" 2>/dev/null || true
  printf 'Continue? [y/N] '
  read -r reply
  case $reply in
    y | Y) ;;
    *)
      echo "Aborted."
      exit 1
      ;;
  esac

  hcloud server create \
    --name "$name" \
    --type "$server_type" \
    --image "$image" \
    --location "$location" \
    --ssh-key "$ssh_key"

  target=$(hcloud server ip "$name")
  echo "install-case: server $name is at $target"
fi

echo "install-case: waiting for SSH on $target"
until ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
  -o UserKnownHostsFile=/dev/null "root@$target" true 2>/dev/null; do
  sleep 5
done

# nixos-anywhere copies this tree onto the installed system verbatim. The key
# is read by tailscaled-autoconnect.service, which runs as root, so root
# ownership and 0600 are what it wants.
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
install -d -m 0755 "$staging/var/lib"
# Create the file before writing to it so the key is never briefly world
# readable. `pass show` prints the whole entry; the secret is its first line.
install -m 0600 /dev/null "$staging/var/lib/tailscale-authkey"
pass show "$authkey_entry" | head -n 1 > "$staging/var/lib/tailscale-authkey"

nixos-anywhere \
  --flake "$flake#case" \
  --target-host "root@$target" \
  --extra-files "$staging"

echo
echo "install-case: $name installed. It should appear on the tailnet as '$name'."
echo "Agent credentials are not installed yet; see documentation/case-install.md."
