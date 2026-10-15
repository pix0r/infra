#!/usr/bin/env bash
# Fetch private application source at runtime. Nix includes only the app files.
set -euo pipefail
umask 077
export GIT_TERMINAL_PROMPT=0
root=$1
revision=$2
nixpkgs=$3
[[ $revision =~ ^[0-9a-f]{40}$ ]] || { echo 'Expected a full commit SHA' >&2; exit 1; }
release=$root/releases/$revision
stage=
trap 'if [ -n "$stage" ]; then rm -rf "$stage"; fi' EXIT
if [ ! -e "$release" ]; then
  stage=$(mktemp -d "$root/releases/.prepare-XXXXXXXX")
  git -C "$stage" init -q
  git -C "$stage" remote add origin https://github.com/pix0r/brain.git
  git -C "$stage" fetch --quiet --depth=1 origin "$revision"
  git -C "$stage" checkout --quiet --detach FETCH_HEAD
  test "$(git -C "$stage" rev-parse HEAD)" = "$revision"
  mv -T "$stage" "$release"
  stage=
fi
test ! -L "$release"
test "$(git -C "$release" rev-parse HEAD)" = "$revision"
if [ -n "$(git -C "$release" status --porcelain --untracked-files=all)" ]; then
  echo "Refusing modified release: $release" >&2
  exit 1
fi
# A stable session key survives service restarts and never enters Git or Nix.
if [ ! -e "$root/secret-key-base" ]; then
  openssl rand -hex 64 > "$root/secret-key-base"
fi
nix-build "$release/apps/personal_search_live/default.nix" \
  --arg pkgs "import $nixpkgs {}" --out-link "$root/packages/$revision"
