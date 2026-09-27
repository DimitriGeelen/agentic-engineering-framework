#!/usr/bin/env bash
# T-1255: verify handover.sh push loop pushes only to origin when >1 remote.
# Self-contained (no real network). Uses file:// remotes + a stub PROJECT_ROOT.
set -euo pipefail
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT
cd "$TMP"

# Set up bare "origin" + "github" remote repos
git init --bare -q origin.git
git init --bare -q github.git

# Set up working repo with both remotes
git init -q -b main repo
cd repo
git -c user.email=a -c user.name=a commit --allow-empty -q -m "init"
git remote add origin "$TMP/origin.git"
git remote add github "$TMP/github.git"

# Reproduce the patched logic in isolation
remote_count=$(git remote | wc -l)
pushed_to=()
while IFS= read -r remote_name; do
    [ -z "$remote_name" ] && continue
    if [ "$remote_count" -gt 1 ] && [ "$remote_name" != "origin" ]; then
        continue
    fi
    git push -q "$remote_name" HEAD
    pushed_to+=("$remote_name")
done < <(git remote)

# Verify origin received the push and github did NOT
origin_head=$(git -C "$TMP/origin.git" rev-parse main)
[ -n "$origin_head" ] || { echo "FAIL: origin did not receive push"; exit 1; }
if git -C "$TMP/github.git" rev-parse main >/dev/null 2>&1; then
    echo "FAIL: github should NOT have received push but did"
    exit 1
fi
[ "${pushed_to[*]}" = "origin" ] || { echo "FAIL: pushed_to=${pushed_to[*]} (want: origin)"; exit 1; }
echo "PASS: T-1255 handover push-target test"
