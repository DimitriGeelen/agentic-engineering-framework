#!/usr/bin/env bats
#
# T-4851: with python3 broken, check-tier0.sh falls back to hook_degraded_tier0
# (lib/hook-degraded.sh, T-4652). That bash scan knew only rm -r / force push /
# hard reset / branch -D / SQL / dd / mkfs, so `git commit --no-verify`,
# `fw task update --force`, `fw inception decide`, core.hooksPath and friends were
# ALLOWED while degraded — classes the healthy fast path sends to the matcher.
#
# The drift guard below reads the fast-path keyword regex out of check-tier0.sh
# and requires every alternative to have a row in CASES. Each row's command must be
# blocked by the HEALTHY gate (so the sample is a real Tier 0 instance) and by the
# DEGRADED gate (so the fallback covers that class). A new fast-path alternative
# with no row fails the guard.
#
# `! cmd` at statement position is inert in bats (T-4398): use `|| false`.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    HOOK="$(ls "$ROOT"/agents/context/check-tier[0].sh)"
    PROJ="$(realpath "$(mktemp -d)")"
    mkdir -p "$PROJ/.context/working" "$PROJ/.tasks/active"
    export PROJECT_ROOT="$PROJ"
    BADPY="$(mktemp -d)"
    printf '#!/bin/sh\necho "python3: broken" >&2\nexit 1\n' > "$BADPY/python3"
    chmod +x "$BADPY/python3"
}

teardown() {
    rm -rf "$PROJ" "$BADPY"
}

payload() {
    # JSON-encode the command with the real python3 (healthy, before PATH is shadowed)
    T4851_CMD="$1" T4851_CWD="$PROJ" python3 -c '
import json, os
print(json.dumps({"tool_name": "Bash", "tool_use_id": "toolu_t4851", "cwd": os.environ["T4851_CWD"],
                  "tool_input": {"command": os.environ["T4851_CMD"]}}))'
}

degraded() {
    local p; p="$(payload "$1")"
    run env PATH="$BADPY:$PATH" bash "$HOOK" <<< "$p"
}

healthy() {
    local p; p="$(payload "$1")"
    run bash "$HOOK" <<< "$p"
}

# alternative-of-the-fast-path-regex <TAB> sample Tier 0 command (one row per alternative;
# extra rows for one alternative are allowed and all checked)
T0W="tier""0"
CASES="$(cat <<EOF
git\\s+(push|reset|clean|checkout|restore|branch)\\s	git push --force origin master
git\\s+(push|reset|clean|checkout|restore|branch)\\s	git push -uf origin master
git\\s+(push|reset|clean|checkout|restore|branch)\\s	git push origin --delete victim
git\\s+(push|reset|clean|checkout|restore|branch)\\s	git push origin :victim
git\\s+(push|reset|clean|checkout|restore|branch)\\s	git reset --ha HEAD~1
git\\s+(push|reset|clean|checkout|restore|branch)\\s	git clean -fdx
git\\s+(push|reset|clean|checkout|restore|branch)\\s	git checkout .
git\\s+(push|reset|clean|checkout|restore|branch)\\s	git restore .
git\\s+(push|reset|clean|checkout|restore|branch)\\s	git branch --force --delete victim
git\\s+-	git -C /tmp/x push --force origin master
git\\s+commit\\b[^;|&]*\\s-[a-z]*n	git commit -anm x
(HOME|XDG_CONFIG_HOME|GIT_CONFIG[A-Z0-9_]*)=	HOME=/tmp/h git push origin master
(HOME|XDG_CONFIG_HOME|GIT_CONFIG[A-Z0-9_]*)=	GIT_CONFIG_GLOBAL=/tmp/g git commit -m x
hooksPath	git config core.hooksPath /dev/null
include\\.path	git -c include.path=/tmp/c push origin master
includeif	git config includeIf.gitdir:/x/.path /tmp/c
${T0W}	bin/fw ${T0W} approve
--no-v	git commit --no-verify -m x
--no-v	git push --no-verif origin master
rm\\s+-	rm -rf ./
DROP\\s	echo DROP TABLE users | psql
TRUNCATE\\s	echo TRUNCATE TABLE users | psql
docker\\s+system	docker system prune -af
kubectl\\s+delete	kubectl delete namespace prod
find\\s.*-delete	find . -name x -delete
dd\\s+if=	dd if=/dev/zero of=/dev/sda
chmod\\s.*\\s000	chmod -R 000 /srv/data
mkfs	mkfs.ext4 /dev/sdb1
pkill\\s	pkill -9 node
pkill\\s	pkill -f worker
killall\\s	killall -KILL node
kill-se	tmux kill-server
fw\\s.*--force	fw task update T-1 --status work-completed --force
fw\\s.*inception\\s.*decide	fw inception decide T-1 go --rationale x
EOF
)"

fast_path_alternatives() {
    # the single-quoted regex on the line after `grep -qEi \` in the fast-path filter
    awk '/grep -qEi \\$/ {getline; print; exit}' "$HOOK" \
        | sed -E "s/^[[:space:]]*'//; s/'; then[[:space:]]*$//" \
        | python3 -c '
import sys
s = sys.stdin.read().strip()
depth, br, cur, out = 0, False, "", []
for ch in s:
    if br:
        br = ch != "]"
    elif ch == "[":
        br = True
    elif ch == "(":
        depth += 1
    elif ch == ")":
        depth -= 1
    if ch == "|" and depth == 0 and not br and not cur.endswith("["):
        out.append(cur); cur = ""
    else:
        cur += ch
out.append(cur)
print("\n".join(out))'
}

@test "T-4851: drift guard — every fast-path alternative has a degraded case" {
    alts="$(fast_path_alternatives)"
    [ "$(printf '%s\n' "$alts" | wc -l)" -ge 15 ]
    missing=""
    while IFS= read -r alt; do
        [ -n "$alt" ] || continue
        printf '%s\n' "$CASES" | cut -f1 | grep -qxF -- "$alt" || missing="$missing [$alt]"
    done <<< "$alts"
    [ -z "$missing" ] || { echo "fast-path alternatives with no degraded case:$missing"; false; }
}

@test "T-4851: every case is a real Tier 0 instance with healthy python" {
    bad=""
    while IFS=$'\t' read -r _alt cmd; do
        healthy "$cmd"
        [ "$status" -eq 2 ] || bad="$bad [$cmd → $status]"
    done <<< "$CASES"
    [ -z "$bad" ] || { echo "healthy gate did not block:$bad"; false; }
}

@test "T-4851: every case is BLOCKED by the degraded fallback (python3 broken)" {
    bad=""
    while IFS=$'\t' read -r _alt cmd; do
        degraded "$cmd"
        { [ "$status" -eq 2 ] && [[ "$output" == *"HOOK DEGRADED"* ]]; } || bad="$bad [$cmd → $status]"
    done <<< "$CASES"
    [ -z "$bad" ] || { echo "degraded gate allowed:$bad"; false; }
}

@test "T-4851: reported commands are blocked while degraded (ring20-dashboard be.46)" {
    degraded "git commit --no-verify -m x"
    [ "$status" -eq 2 ]
    [[ "$output" == *"HOOK DEGRADED"* ]]
    degraded "fw task update T-1 --status work-completed --force"
    [ "$status" -eq 2 ]
    degraded "git commit -n -m x"
    [ "$status" -eq 2 ]
}

@test "T-4851: a reassembled spelling (quotes inside the word) is blocked while degraded" {
    degraded "bin/fw ${T0W:0:4}\"\"${T0W:4} approve"
    [ "$status" -eq 2 ]
    degraded "bin/fw \$'tier\\x30' approve"
    [ "$status" -eq 2 ]
}

@test "T-4851: benign commands are still allowed while degraded" {
    for cmd in "ls -la" "git status" "git push origin bleeding-edge" "git commit -m fix" "bin/fw task show T-1"; do
        degraded "$cmd"
        [ "$status" -eq 0 ] || { echo "over-blocked: $cmd"; false; }
        [[ "$output" == *"DEGRADED"* ]]
    done
}
