# Transfer a project's .scratch/ handoff documents between this clone and the
# same clone on another machine.
#
# Both machines keep repositories at the same path relative to the home
# directory, so the remote clone is derived from the local one and the script
# needs no configuration. Each transfer is an explicit one-way copy under a
# single-writer protocol: the caller decides the direction, the script shows
# what would change, and overwritten files are kept on the receiving side.
# Nothing is ever deleted.

usage() {
  cat >&2 <<'EOF'
Usage: handoff-sync (pull|push|diff) <host> [-n|--dry-run] [-y|--yes]

Copy this project's .scratch/ handoff documents between this clone and the
clone at the same home-relative path on <host>.

  pull   copy <host>'s documents over this clone's
  push   copy this clone's documents over <host>'s
  diff   show the textual differences between the two, changing nothing

pull and push preview the transfer, then ask before applying it. Files the
transfer overwrites are kept under the receiver's
.scratch/sync-backups/<timestamp>/. Documents present only on the receiver are
left alone.

  -n, --dry-run   stop after the preview
  -y, --yes       apply without asking
EOF
  exit 2
}

mode=
host=
dry_run=0
yes=0
for argument in "$@"; do
  case "$argument" in
    -n | --dry-run) dry_run=1 ;;
    -y | --yes) yes=1 ;;
    -h | --help) usage ;;
    -*)
      echo "handoff-sync: unknown option $argument" >&2
      usage
      ;;
    *)
      if [ -z "$mode" ]; then
        mode=$argument
      elif [ -z "$host" ]; then
        host=$argument
      else
        usage
      fi
      ;;
  esac
done
case "$mode" in
  pull | push | diff) ;;
  *) usage ;;
esac
[ -n "$host" ] || usage

# Quote for the remote login shell. Single quotes with '\'' for embedded quotes
# are read the same way by POSIX shells and by fish.
quote() {
  printf "'%s'" "${1//\'/\'\\\'\'}"
}

top=$(git rev-parse --show-toplevel)
case "$top" in
  "$HOME"/*) relative=${top#"$HOME"/} ;;
  *)
    echo "handoff-sync: $top is outside $HOME, so the remote path cannot be derived" >&2
    exit 1
    ;;
esac
local_dir=$top/.scratch
remote_dir=$relative/.scratch

# Handoff documents name commits and paths, so the code should reach a clone
# before its documents do. Show both clones' heads and warn when they differ.
local_head=$(git rev-parse --short HEAD)
local_branch=$(git symbolic-ref --short --quiet HEAD || echo detached)
# shellcheck disable=SC2029 # the path is meant to expand here, quoted for the remote shell
if ! remote_state=$(ssh "$host" "git -C $(quote "$relative") rev-parse --short HEAD; git -C $(quote "$relative") symbolic-ref --short --quiet HEAD || echo detached"); then
  echo "handoff-sync: could not read the clone at $host:$relative" >&2
  exit 1
fi
remote_head=${remote_state%%$'\n'*}
remote_branch=${remote_state#*$'\n'}
printf 'Code:      local %s (%s)\n' "$local_head" "$local_branch"
printf '           %-5s %s (%s)\n' "$host" "$remote_head" "$remote_branch"
if [ "$local_head" != "$remote_head" ]; then
  echo "Warning: the clones are at different commits. Sync code before handoff documents." >&2
fi

# The backup directory is excluded so one transfer never carries another's
# backups. --checksum compares content rather than modification times, which
# are meaningless across two machines, and there is deliberately no --delete.
# Symlinks travel as symlinks: a link into a directory the receiver lacks is
# more honest dangling than silently dropped.
rsync_options=(--recursive --links --checksum --itemize-changes --exclude=/sync-backups/)

if [ "$mode" = diff ]; then
  staged=$(mktemp --directory --tmpdir "handoff-sync-$host.XXXXXX")
  trap 'rm -rf -- "$staged"' EXIT
  rsync --recursive --links --checksum --exclude=/sync-backups/ "$host:$remote_dir/" "$staged/"
  printf 'Diff:      local %s\n           %-5s %s\n\n' "$local_dir" "$host" "$staged"
  set +e
  diff --recursive --unified --exclude=sync-backups "$local_dir" "$staged"
  status=$?
  set -e
  case "$status" in
    0) echo "The documents are identical." ;;
    1) ;;
    *) exit "$status" ;;
  esac
  exit 0
fi

case "$mode" in
  pull)
    source=$host:$remote_dir/
    destination=$local_dir/
    receiver=$local_dir
    ;;
  push)
    if [ ! -d "$local_dir" ]; then
      echo "handoff-sync: $local_dir does not exist" >&2
      exit 1
    fi
    source=$local_dir/
    destination=$host:$remote_dir/
    receiver=$host:$remote_dir
    ;;
esac

printf 'Transfer:  %s\n        -> %s\n\n' "$source" "$destination"
preview=$(rsync "${rsync_options[@]}" --dry-run "$source" "$destination")
if [ -z "$preview" ]; then
  echo "Already in sync."
  exit 0
fi
printf '%s\n\n' "$preview"

if [ "$dry_run" = 1 ]; then
  exit 0
fi
if [ "$yes" != 1 ]; then
  if [ ! -t 0 ]; then
    echo "handoff-sync: not a terminal; pass --yes to apply" >&2
    exit 1
  fi
  read -r -p "Apply this transfer? [y/N] " answer
  case "$answer" in
    y | Y | yes) ;;
    *)
      echo "Nothing changed."
      exit 1
      ;;
  esac
fi

# A relative --backup-dir is resolved against the destination, so the
# displaced files land beside the documents that replaced them.
stamp=$(date +%Y%m%d-%H%M%S)
rsync "${rsync_options[@]}" --backup-dir="sync-backups/$stamp" "$source" "$destination"
echo
echo "Applied. Overwritten files were kept under $receiver/sync-backups/$stamp/."
