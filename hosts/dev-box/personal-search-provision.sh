#!/usr/bin/env bash
# Runtime-only private fetch: neither credentials nor note contents enter Nix.
set -euo pipefail
umask 077
export GIT_TERMINAL_PROMPT=0 PYTHONDONTWRITEBYTECODE=1
root=$1
repository=$2
revision=$3
python=$4
[[ $revision =~ ^[0-9a-f]{40}$ ]] || { echo 'Expected a full commit SHA' >&2; exit 1; }
mkdir -p "$root/releases" "$root/index"
release=$root/releases/$revision
stage=
trap 'if [ -n "$stage" ]; then rm -rf "$stage"; fi' EXIT
if [ ! -e "$release" ]; then
  stage=$(mktemp -d "$root/releases/.prepare-XXXXXXXX")
  git -C "$stage" init -q
  git -C "$stage" remote add origin "$repository"
  git -C "$stage" fetch --quiet --depth=1 origin "$revision"
  git -C "$stage" checkout --quiet --detach FETCH_HEAD
  test "$(git -C "$stage" rev-parse HEAD)" = "$revision"
  mv -T "$stage" "$release"
  stage=
fi
# Releases are machine-owned snapshots; refuse edits instead of deleting them.
test ! -L "$release"
test "$(git -C "$release" rev-parse HEAD)" = "$revision"
if [ -n "$(git -C "$release" status --porcelain --untracked-files=all)" ]; then
  echo "Refusing modified release: $release" >&2
  exit 1
fi
test -f "$release/scripts/personal_search_web.py"
"$python" "$release/scripts/personal_search.py" \
  --brain "$release" --index "$root/index/$revision.sqlite" index
