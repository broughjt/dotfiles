# Apply this repository's copy of the tailnet policy file to Tailscale.
#
# The policy file is the one input capable of locking every host out of the
# tailnet at once, and it used to live only in the admin console: no history, no
# review, no second copy. `case` sharpens that, because Tailscale SSH is its
# only route in and the grant lives in this file, so a bad edit leaves nothing
# but the Hetzner console. Everything below exists for that reason -- the diff,
# the validate call, the confirmation prompt, and the If-Match precondition that
# refuses to clobber a console edit made since the fetch.
#
# Credential: an OAuth client carrying the `policy_file` scope, from the Trust
# credentials page of the admin console. A personal API access token cannot take
# its place: those are fully-permitted rather than scoped, and expire within 90
# days, which for a tool run a few times a year means always expired. The client
# ID and the secret are distinct values, and the secret is not a bearer token,
# so it is exchanged for a one-hour access token first.

set -euo pipefail

client_id_entry=${TAILNET_POLICY_CLIENT_ID_ENTRY:-tailscale/policy-oauth-client-id}
secret_entry=${TAILNET_POLICY_SECRET_ENTRY:-tailscale/policy-oauth-secret}
policy_path=${TAILNET_POLICY_FILE:-tailscale/policy.hujson}
api=${TAILNET_API:-https://api.tailscale.com/api/v2}
tailnet=${TAILNET_NAME:--}

usage() {
  cat <<'USAGE'
Usage:
  apply-tailnet-policy             Apply the local policy file, after a diff
  apply-tailnet-policy --dry-run   Everything except the final write
  apply-tailnet-policy --fetch     Overwrite the local file with the live policy

Run from a checkout of this repository; the policy file path is relative to the
working directory, so the file applied is the one you are looking at rather than
whatever the last commit holds.

--fetch reseeds the local copy after a change made in the admin console. It
overwrites the file in place, so commit or stash local edits first.

Environment:
  TAILNET_POLICY_FILE             default tailscale/policy.hujson
  TAILNET_POLICY_CLIENT_ID_ENTRY  default tailscale/policy-oauth-client-id
  TAILNET_POLICY_SECRET_ENTRY     default tailscale/policy-oauth-secret
  TAILNET_NAME                    default -  (the caller's default tailnet)
USAGE
}

mode=apply
while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) mode=dry-run; shift ;;
    --fetch) mode=fetch; shift ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "apply-tailnet-policy: unknown argument '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ "$mode" != "fetch" ] && [ ! -f "$policy_path" ]; then
  echo "apply-tailnet-policy: no policy file at '$policy_path'." >&2
  echo "Run from a checkout of this repository, or set TAILNET_POLICY_FILE." >&2
  echo "To create it from the live policy: apply-tailnet-policy --fetch" >&2
  exit 1
fi

# Only stdout is discarded, so the secret stays off the terminal while gpg's own
# diagnostics reach stderr. A failure here is as often a gpg problem as a
# missing entry, and the two need different fixes.
for entry in "$client_id_entry" "$secret_entry"; do
  if ! pass show "$entry" >/dev/null; then
    echo >&2
    echo "apply-tailnet-policy: could not read '$entry' from the password store." >&2
    echo "If the entry does not exist, create an OAuth client with the" >&2
    echo "policy_file scope at https://login.tailscale.com/admin/settings/oauth" >&2
    echo "and store its two halves:" >&2
    echo "    pass insert $client_id_entry" >&2
    echo "    pass insert $secret_entry" >&2
    echo "If gpg reported a key error above, check that 'command -v gpg' is your" >&2
    echo "wrapped gpg rather than an unwrapped one earlier on PATH." >&2
    exit 1
  fi
done

# 0700 because the access token and the curl configuration that carries it live
# here for the length of the run.
umask 077
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

client_id=$(pass show "$client_id_entry" | head -n 1)
client_secret=$(pass show "$secret_entry" | head -n 1)

# The secret goes over stdin rather than in argv, where /proc would expose it to
# any other process on the machine for the life of the request.
token=$(
  printf 'client_id=%s&client_secret=%s' "$client_id" "$client_secret" \
    | curl -sS --fail-with-body --data-binary @- "$api/oauth/token" \
    | jq -r '.access_token // empty'
)
if [ -z "$token" ]; then
  echo "apply-tailnet-policy: the OAuth client did not return an access token." >&2
  echo "Check that '$client_id_entry' and '$secret_entry' belong to the same" >&2
  echo "client and that it carries the policy_file scope." >&2
  exit 1
fi

# Same reasoning as the secret: a --config file keeps the bearer token out of
# every subsequent argv.
printf 'header = "Authorization: Bearer %s"\n' "$token" > "$work/curl.conf"
api_curl() { curl -sS --config "$work/curl.conf" "$@"; }

# Ask for HuJSON explicitly. The policy file's comments are the operator's
# reasoning, and a round trip through canonicalized JSON drops all of them.
api_curl --fail-with-body \
  -H 'Accept: application/hujson' \
  -D "$work/headers" \
  -o "$work/live.hujson" \
  "$api/tailnet/$tailnet/acl"

if [ "$mode" = "fetch" ]; then
  mkdir -p "$(dirname "$policy_path")"
  cp "$work/live.hujson" "$policy_path"
  echo "apply-tailnet-policy: wrote the live policy to '$policy_path'."
  exit 0
fi

etag=$(sed -n 's/^[Ee][Tt][Aa][Gg]: *//p' "$work/headers" | tail -n 1 | tr -d '\r')
if [ -z "$etag" ]; then
  echo "apply-tailnet-policy: no ETag on the fetch, so a concurrent console" >&2
  echo "edit could not be detected. Refusing to write." >&2
  exit 1
fi

if diff -q "$work/live.hujson" "$policy_path" >/dev/null; then
  echo "apply-tailnet-policy: the live policy already matches '$policy_path'."
  exit 0
fi

echo "Changes to apply to tailnet '$tailnet':"
echo
diff -u --label 'live (tailscale)' --label "local ($policy_path)" \
  "$work/live.hujson" "$policy_path" || true
echo

# Validate before the confirmation prompt, so an answer is only ever asked for
# about a policy Tailscale has already accepted as well-formed.
validation=$(
  api_curl --fail-with-body \
    -H 'Content-Type: application/hujson' \
    --data-binary "@$policy_path" \
    "$api/tailnet/$tailnet/acl/validate"
)
# A valid policy comes back as an empty object. Anything else is the reason it
# was rejected, and is worth printing verbatim rather than summarizing.
if [ -n "$validation" ] && [ "$(printf '%s' "$validation" | jq -c '.')" != "{}" ]; then
  echo "apply-tailnet-policy: Tailscale rejected the policy:" >&2
  printf '%s\n' "$validation" >&2
  exit 1
fi
echo "Validated."

if [ "$mode" = "dry-run" ]; then
  cat <<DRYRUN

Dry run, so nothing was written. The request this would send:

    POST $api/tailnet/$tailnet/acl
    If-Match: $etag
    Content-Type: application/hujson
    (body: $policy_path, $(wc -c < "$policy_path") bytes)
DRYRUN
  exit 0
fi

echo
echo "This replaces the tailnet policy file. A wrong policy locks every host"
echo "out at once, and 'case' has no route in except Tailscale SSH."
printf 'Apply? [y/N] '
read -r reply
case $reply in
  y | Y | yes | YES) ;;
  *)
    echo "Not applied."
    exit 1
    ;;
esac

# If-Match carries the ETag from the fetch above, so a console edit made while
# this script was running is refused rather than silently overwritten.
api_curl --fail-with-body \
  -H "If-Match: $etag" \
  -H 'Content-Type: application/hujson' \
  -D "$work/applied-headers" \
  --data-binary "@$policy_path" \
  -o "$work/applied.hujson" \
  "$api/tailnet/$tailnet/acl"

echo "Applied."
new_etag=$(sed -n 's/^[Ee][Tt][Aa][Gg]: *//p' "$work/applied-headers" | tail -n 1 | tr -d '\r')
# Not "&&": as the last command in the script its exit status would become the
# script's, so a successful apply that returned no ETag would report failure.
if [ -n "$new_etag" ]; then
  echo "New ETag: $new_etag"
fi
