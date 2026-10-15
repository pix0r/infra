#!/usr/bin/env bash
# Integration test with a real local Git remote and the actual brain indexer.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
brain=$1
python=$2
provision=$(cd "$(dirname "$0")/../hosts/dev-box" && pwd)/personal-search-provision.sh
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
remote=$test_root/remote
runtime=$test_root/runtime
mkdir -p "$remote/scripts" "$remote/atlas" "$runtime"
cp -f "$brain/scripts/"{personal_search.py,personal_search_web.py,project_dashboard.py} "$remote/scripts/"
printf '# First\noriginalcanary\n' > "$remote/atlas/note.md"
git -C "$remote" init -q
git -C "$remote" config user.name Test
git -C "$remote" config user.email test@example.invalid
git -C "$remote" add .
git -C "$remote" commit -qm first
first=$(git -C "$remote" rev-parse HEAD)
bash "$provision" "$runtime" "$remote" "$first" "$python"
test "$(git -C "$runtime/releases/$first" rev-parse HEAD)" = "$first"
test "$(stat -c '%a' "$runtime/releases/$first")" = 700
"$python" "$runtime/releases/$first/scripts/personal_search.py" --index "$runtime/index/$first.sqlite" search originalcanary --json | "$python" -c 'import json,sys; assert len(json.load(sys.stdin)) == 1'
printf '# Second\nupdatedcanary\n' > "$remote/atlas/note.md"
git -C "$remote" commit -qam second
second=$(git -C "$remote" rev-parse HEAD)
bash "$provision" "$runtime" "$remote" "$second" "$python"
test -f "$runtime/index/$first.sqlite"
"$python" "$runtime/releases/$second/scripts/personal_search.py" --index "$runtime/index/$second.sqlite" search updatedcanary --json | "$python" -c 'import json,sys; assert len(json.load(sys.stdin)) == 1'
# Cached releases can restart and roll back without network access.
mv -f "$remote" "$remote.offline"
bash "$provision" "$runtime" "$remote" "$first" "$python"
if bash "$provision" "$runtime" "$remote" 0000000000000000000000000000000000000000 "$python"; then
  echo 'Unexpected success fetching unavailable revision' >&2
  exit 1
fi
test -f "$runtime/index/$first.sqlite"
# Never silently overwrite an edited release.
printf 'edited\n' >> "$runtime/releases/$first/atlas/note.md"
if bash "$provision" "$runtime" "$remote" "$first" "$python"; then
  echo 'Unexpected success with dirty release' >&2
  exit 1
fi
echo 'PASS: initial provisioning, pinned update, offline rollback, failed fetch, dirty release'
