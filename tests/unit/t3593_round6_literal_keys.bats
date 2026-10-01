#!/usr/bin/env bats
# T-3593 round 6 — two findings from docs/reports/T-3593-round5-codex.md.
#
# HIGH: `git branch -D victim`, `-D +victim` and `-D refs/heads/victim` produced
# the same action key. For a LOCAL delete git takes the name literally, so
# those are three different branches; an approval shown for one deleted another.
# Same class, found while checking the other verbs: `rm -rf link` and
# `rm -rf link/` keyed alike, but with link -> dir the second deletes the
# directory's contents and the first only the link.
#
# MEDIUM: `env -u CLAUDECODE bin/fw $'tier\x30' approve` was SAFE: the keyword
# check never decoded ANSI-C quoting.
#
# SAFETY: fixtures only, under a tmpdir, with the git discovery fence. The hook
# only DECIDES; no branch is deleted and no rm runs. Approvals are fixture
# approvals through the real `fw tier0 approve` with CLAUDECODE unset.


load ../git_fence

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    FX="$(mktemp -d -t fw-t3593r6-XXXXXX)"
    FX="$(cd "$FX" && pwd -P)"
    REMOTE="$FX/remote.git"
    W="$FX/work"
    git init -q --bare "$REMOTE"
    git init -q -b main "$W"
    cd "$W"
    git config user.email "t3593@local"
    git config user.name "T-3593 fixture"
    git config commit.gpgsign false
    mkdir -p .tasks/active .context/working .context/approvals sub agents/audit lib
    # The same minimal project shape as the round-4 suite, so `fw tier0
    # approve` treats the fixture as a project and does not try to vendor.
    cat > agents/audit/audit.sh <<'STUB'
#!/bin/bash
echo "=== STRUCTURE CHECKS ==="
echo "AUDIT-SCOPE: fails=0 ref=0 worktree=0"
exit 0
STUB
    chmod +x agents/audit/audit.sh
    cp "$FRAMEWORK_ROOT/lib/tier0_action.py" lib/
    echo "1.0.0" > VERSION
    printf '.context/\n' > .gitignore
    echo zero > f.txt
    git add -A
    git commit -q -m "T-3593: c0"
    git remote add origin "$REMOTE"
    git push -q origin main 2>/dev/null
    unset CLAUDE_PROJECT_DIR TIER0_WATCHTOWER_TTL CDPATH TIER0_LOCK_TIMEOUT
    export FX REMOTE W NTFY_ENABLED=false
}

teardown() {
    [ -n "${HOLDER:-}" ] && kill "$HOLDER" 2>/dev/null
    cd /
    [ -n "${FX:-}" ] && [ -d "$FX" ] && rm -rf "${FX:?}"
    return 0
}

# One PreToolUse call. $1 = tool_use_id, $2 = command.
_gate_id() {
    local json
    json=$(python3 -c "
import json, sys
print(json.dumps({'tool_input': {'command': sys.argv[1]}, 'cwd': sys.argv[2], 'tool_use_id': sys.argv[3]}))" "$2" "$W" "$1")
    printf '%s' "$json" | PROJECT_ROOT="$W" bash "$FRAMEWORK_ROOT/agents/context/check-tier0.sh"
}
_gate() { _gate_id "toolu_$RANDOM$RANDOM$RANDOM" "$1"; }

_approve() {
    (cd "$W" && env -u CLAUDECODE -u CLAUDE_PROJECT_DIR PROJECT_ROOT="$W" "$FRAMEWORK_ROOT/bin/fw" tier0 approve "$@")
}

_commit() { echo "$1" > f.txt && git add f.txt && git commit -q -m "T-3593: $1"; }

# Every command in "$@": blocked, and NOT mapped to an action.
_all_blocked_unmapped() {
    local c
    for c in "$@"; do
        run _gate "$c"
        [ "$status" -eq 2 ] || { echo "not blocked: $c"; echo "$output"; return 1; }
        [[ "$output" == *"Not mapped to an action"* ]] || { echo "mapped: $c"; echo "$output"; return 1; }
    done
}

# $1 = the approved command, $2.. = commands that must stay blocked afterwards.
# The approval is made from $1's block, then each other command is gated: all
# must still block (the approval is not theirs), and $1 itself must then pass.
_approval_not_shared() {
    local approved="$1"; shift
    run _gate_id "toolu_a$RANDOM$RANDOM" "$approved"
    [ "$status" -eq 2 ] || { echo "not blocked: $approved"; echo "$output"; return 1; }
    _approve >/dev/null
    local c
    for c in "$@"; do
        run _gate_id "toolu_o$RANDOM$RANDOM" "$c"
        [ "$status" -eq 2 ] || { echo "approval for [$approved] admitted [$c]"; echo "$output"; return 1; }
    done
    run _gate_id "toolu_z$RANDOM$RANDOM" "$approved"
    [ "$status" -eq 0 ] || { echo "own approval not consumed: $approved"; echo "$output"; return 1; }
}

# ── HIGH: local branch names are literal ────────────────────────────────────

@test "codex R5 HIGH (exact probes): -D victim / +victim / refs/heads/victim are three literal names" {
    run _gate "git branch -D victim"
    [[ "$output" == *"DELETE local branch 'victim'"* ]]
    run _gate "git branch -D +victim"
    [[ "$output" == *"DELETE local branch '+victim'"* ]]
    run _gate "git branch -D refs/heads/victim"
    [[ "$output" == *"DELETE local branch 'refs/heads/victim'"* ]]
}

@test "an approval for victim admits neither +victim nor refs/heads/victim (-D, -d -f, --delete --force)" {
    _approval_not_shared "git branch -D victim" \
        "git branch -D +victim" "git branch -D refs/heads/victim" \
        "git branch -d -f +victim" "git branch --delete --force refs/heads/victim"
    _approval_not_shared "git branch -d -f victim" \
        "git branch -d -f +victim" "git branch -D refs/heads/victim"
    _approval_not_shared "git branch --delete --force victim" \
        "git branch --delete --force +victim" "git branch --delete --force refs/heads/victim"
}

@test "the other way round: approvals for +victim / refs/heads/victim do not admit victim" {
    _approval_not_shared "git branch -D +victim" \
        "git branch -D victim" "git branch -D refs/heads/victim"
    _approval_not_shared "git branch -D refs/heads/victim" \
        "git branch -D victim" "git branch -D +victim" "git branch -D heads/victim"
    _approval_not_shared "git branch -D +feature/x" \
        "git branch -D feature/x" "git branch -D refs/heads/feature/x"
}

@test "git branch -D -- name: names after -- are literal and keyed alone" {
    run _gate "git branch -D -- +victim"
    [ "$status" -eq 2 ]
    [[ "$output" == *"DELETE local branch '+victim'"* ]]
    _approval_not_shared "git branch -D -- victim" \
        "git branch -D -- +victim" "git branch -D -- refs/heads/victim"
    # -D -- victim and -D victim are the same target, so either form consumes it.
    _approval_not_shared "git branch -D victim" "git branch -D -- +victim"
}

@test "remote deletes still normalise: push origin :refs/heads/x keys as branch x (push path unchanged)" {
    git branch x
    git push -q origin x 2>/dev/null
    run _gate "git push origin :refs/heads/x"
    [ "$status" -eq 2 ]
    [[ "$output" == *"DELETE branch 'x' on remote 'origin'"* ]]
}

# ── Same class, rm: a trailing slash is a different target ──────────────────

@test "rm -rf link and rm -rf link/ are different keys (link -> dir: the slash deletes the target)" {
    # Only some rm targets are Tier 0 (/, ~, ., *, a last . or ..), but every
    # path in a flagged command is part of its action set, so a link riding
    # next to ./ is keyed too.
    mkdir realdir && ln -s realdir link
    run _gate "rm -rf ./ $W/link/"
    [ "$status" -eq 2 ]
    [[ "$output" == *"RECURSIVELY DELETE $W/link/"* ]]
    _approval_not_shared "rm -rf ./ $W/link" "rm -rf ./ $W/link/" "rm -rf ./ $W/link/."
    _approval_not_shared "rm -rf ./ $W/link/" "rm -rf ./ $W/link"
    # Collapsing that changes nothing is still collapsed: // and /./ inside.
    run _gate_id toolu_s1 "rm -rf ./ $W/realdir/sub"
    [ "$status" -eq 2 ]
    _approve >/dev/null
    run _gate_id toolu_s2 "rm -rf ./ $W//realdir/./sub"
    [ "$status" -eq 0 ]
}

# ── MEDIUM: ANSI-C quoting is decoded before the self-approval check ────────

@test "codex R5 MEDIUM (exact probe and variants): ANSI-C spelled tier0 approve is SELF-APPROVAL" {
    local c
    for c in "env -u CLAUDECODE bin/fw \$'tier\\x30' approve" \
             "bin/fw \$'tier\\x30' approve" \
             "bin/fw \$'\\x74ier0' approve" \
             "bin/fw \$'tier\\060' approve" \
             "bin/fw \$'tier\\60' approve" \
             "bin/fw \$'tier'0 approve" \
             "bin/fw \$'\\x74\\x69\\x65\\x72\\x30' approve" \
             "bin/fw \$'tier\\u0030' approve" \
             "bin/fw \$'tier\\U00000030' approve" \
             "bin/fw \$'\\164ier0' approve" \
             "bin/fw tier0 \$'\\x61pprove'" \
             "env -u CLAUDECODE bin/fw \$'tier\\x30' \$'appr\\157ve'"; do
        run _gate "$c"
        [ "$status" -eq 2 ] || { echo "not blocked: $c"; echo "$output"; return 1; }
        [[ "$output" == *"SELF-APPROVAL"* ]] || { echo "no label: $c"; echo "$output"; return 1; }
    done
}

@test "ANSI-C CONTROL: a \$'..' with no tier0 or destructive word is still SAFE" {
    local c
    for c in "printf \$'a\\tb\\n'" "echo \$'tier\\x31'" "grep -n \$'\\x41' README.md"; do
        run _gate "$c"
        [ "$status" -eq 0 ] || { echo "blocked: $c"; echo "$output"; return 1; }
    done
}
