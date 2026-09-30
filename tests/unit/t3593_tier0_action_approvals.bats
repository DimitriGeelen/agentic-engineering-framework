#!/usr/bin/env bats
# T-3593 (T-3576 GO): Tier 0 approvals are keyed to the ACTION, not the command hash.
#
# Everything runs in a fixture repo under a tmpdir. The hook is driven the way
# Claude Code drives it (PreToolUse JSON on stdin, with `cwd`), and approvals go
# through the real `fw tier0 approve` verb with CLAUDECODE unset — i.e. acting as
# the operator, inside the fixture only. Nothing here pushes, resets or deletes
# anything: the hook only DECIDES; no command under test is ever executed.
#
# Each positive assertion is paired with a negative control, so an exit 0 cannot
# be green merely because the harness failed to observe a block.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    FX="$(mktemp -d -t fw-t3593-XXXXXX)"
    FX="$(cd "$FX" && pwd -P)"
    mkdir -p "$FX/.tasks/active" "$FX/.context/working" "$FX/.context/approvals"
    git -C "$FX" init -q -b main
    git -C "$FX" -c user.email=t@l -c user.name=t commit -q --allow-empty -m "T-3593: fixture"
    export FX
    HOOK="$FRAMEWORK_ROOT/agents/context/check-tier0.sh"
    unset CLAUDE_PROJECT_DIR TIER0_WATCHTOWER_TTL
}

teardown() {
    [ -n "${FX:-}" ] && [ -d "$FX" ] && rm -rf "${FX:?}"
    return 0
}

_hook() {
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_input':{'command':sys.argv[1]},'cwd':sys.argv[2]}))" "$1" "$FX")
    printf '%s' "$json" | PROJECT_ROOT="$FX" bash "$HOOK"
}

# Operator approval: the real verb, CLAUDECODE unset, run from the fixture.
_approve() {
    (cd "$FX" && env -u CLAUDECODE -u CLAUDE_PROJECT_DIR PROJECT_ROOT="$FX" "$FRAMEWORK_ROOT/bin/fw" tier0 approve "$@")
}

_events() { cat "$FX/.context/working/tier0-action-events.jsonl" 2>/dev/null; }

@test "tail -12 vs tail -14: one action approval admits the cosmetically different retry" {
    run _hook "git push --force origin main 2>&1 | tail -12"
    [ "$status" -eq 2 ]
    [[ "$output" == *"FORCE-PUSH ref 'main' to remote 'origin'"* ]]
    run _approve
    [ "$status" -eq 0 ]
    [[ "$output" == *"FORCE-PUSH ref 'main' to remote 'origin'"* ]]
    run _hook "git push --force origin main 2>&1 | tail -14"
    [ "$status" -eq 0 ]
    _events | grep -q '"event": "admitted"'
}

@test "CONTROL: without an approval the tail -14 retry is blocked" {
    run _hook "git push --force origin main 2>&1 | tail -14"
    [ "$status" -eq 2 ]
}

@test "flag order and whitespace do not change the action" {
    run _hook "git push --force origin main"
    [ "$status" -eq 2 ]
    _approve >/dev/null
    run _hook "git   push origin   main -f   >/dev/null"
    [ "$status" -eq 0 ]
}

@test "a DIFFERENT ref does not match the approval" {
    _hook "git push --force origin main" 2>/dev/null || true
    _approve >/dev/null
    run _hook "git push --force origin feature"
    [ "$status" -eq 2 ]
    # control: the approved ref still matches (proves the approval was live)
    run _hook "git push --force origin main | tail -3"
    [ "$status" -eq 0 ]
}

@test "a DIFFERENT remote does not match the approval" {
    _hook "git push --force origin main" 2>/dev/null || true
    _approve >/dev/null
    run _hook "git push --force github main"
    [ "$status" -eq 2 ]
    run _hook "git push --force origin main"
    [ "$status" -eq 0 ]
}

@test "a DIFFERENT path does not match a recursive-delete approval" {
    mkdir -p "$FX/build" "$FX/other"
    _hook "cd $FX && rm -rf *" 2>/dev/null || true
    _approve >/dev/null
    run _hook "cd $FX/other && rm -rf *"
    [ "$status" -eq 2 ]
    run _hook "cd $FX   &&   rm -rf * 2>&1 | tail -1"
    [ "$status" -eq 0 ]
}

@test "single-use: the second use of a consumed approval is refused" {
    _hook "cd $FX && rm -rf *" 2>/dev/null || true
    _approve >/dev/null
    run _hook "cd $FX && rm -rf *"
    [ "$status" -eq 0 ]
    _events | grep -q '"event": "consumed"'
    # Different incidental text on purpose: the byte-identical command within 5s
    # is let through by the T-1508 duplicate-hook-fire sentinel (both paths, by
    # design). A cosmetically different retry is exactly what must be refused.
    run _hook "cd $FX && rm -rf * | cat"
    [ "$status" -eq 2 ]
}

@test "single-use: a push approval admitted by the text gate cannot be admitted again" {
    _hook "git push --force origin main" 2>/dev/null || true
    _approve >/dev/null
    run _hook "git push --force origin main"
    [ "$status" -eq 0 ]
    run _hook "git push --force origin main | cat"
    [ "$status" -eq 2 ]
}

@test "expiry: an approval past its TTL is refused and the expiry is logged" {
    _hook "git push --force origin main" 2>/dev/null || true
    TIER0_WATCHTOWER_TTL=1 _approve >/dev/null
    sleep 2
    run _hook "git push --force origin main"
    [ "$status" -eq 2 ]
    _events | grep -q '"event": "expired"'
}

@test "CONTROL for expiry: inside the TTL the same approval is admitted" {
    _hook "git push --force origin main" 2>/dev/null || true
    TIER0_WATCHTOWER_TTL=60 _approve >/dev/null
    run _hook "git push --force origin main"
    [ "$status" -eq 0 ]
}

@test "agent cannot approve: CLAUDECODE=1 is refused and nothing is written" {
    _hook "git push --force origin main" 2>/dev/null || true
    run bash -c "cd '$FX' && CLAUDECODE=1 PROJECT_ROOT='$FX' '$FRAMEWORK_ROOT/bin/fw' tier0 approve"
    [ "$status" -ne 0 ]
    [[ "$output" == *"human-only"* ]]
    [ ! -f "$FX/.context/working/tier0-action-approvals.json" ] || \
        ! grep -q '"state": "approved"' "$FX/.context/working/tier0-action-approvals.json"
    run _hook "git push --force origin main"
    [ "$status" -eq 2 ]
}

@test "CONTROL: --i-am-human under CLAUDECODE=1 does approve" {
    _hook "git push --force origin main" 2>/dev/null || true
    run bash -c "cd '$FX' && CLAUDECODE=1 PROJECT_ROOT='$FX' '$FRAMEWORK_ROOT/bin/fw' tier0 approve --i-am-human"
    [ "$status" -eq 0 ]
    run _hook "git push --force origin main"
    [ "$status" -eq 0 ]
}

@test "legacy hash path: an unmapped command is approved by exact text and logged as command-hash" {
    run _hook "git clean -fdx"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Not mapped to an action"* ]]
    [ ! -f "$FX/.context/working/.tier0-action.pending.json" ]
    _approve >/dev/null
    run _hook "git clean -fdx"
    [ "$status" -eq 0 ]
    sleep 1   # the bypass-log write is fire-and-forget
    grep -q "match_path: command-hash" "$FX/.context/bypass-log.yaml"
}

@test "CONTROL for legacy path: different text for an unmapped command is not admitted" {
    _hook "git clean -fdx" 2>/dev/null || true
    _approve >/dev/null
    run _hook "git clean -fdx | tail -3"
    [ "$status" -eq 2 ]
}

@test "action path logs match_path: action to the bypass log" {
    _hook "cd $FX && rm -rf *" 2>/dev/null || true
    _approve >/dev/null
    _hook "cd $FX && rm -rf *"
    grep -q "match_path: action" "$FX/.context/bypass-log.yaml"
}

@test "fail closed: a mapped segment beside an unmapped flagged segment falls to the hash path" {
    run _hook "git push --force origin main; git clean -fdx"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Not mapped to an action"* ]]
    # An approval for the force-push action alone must not admit the pair.
    _hook "git push --force origin main" 2>/dev/null || true
    _approve >/dev/null
    run _hook "git push --force origin main; git clean -fdx"
    [ "$status" -eq 2 ]
}

@test "fail closed: a variable or command substitution is never mapped" {
    run _hook 'git push --force origin $BRANCH'
    [ "$status" -eq 2 ]
    [[ "$output" == *"Not mapped to an action"* ]]
    run _hook 'echo $(git push --force origin main)'
    [ "$status" -eq 2 ]
    [[ "$output" == *"Not mapped to an action"* ]]
}

@test "stricter, not weaker: +refspec and remote ref delete are now blocked" {
    run _hook "git push origin +main"
    [ "$status" -eq 2 ]
    [[ "$output" == *"FORCE-PUSH ref 'main'"* ]]
    run _hook "git push origin --delete old"
    [ "$status" -eq 2 ]
    [[ "$output" == *"DELETE ref 'old' on remote 'origin'"* ]]
    # control: a plain push is not touched
    run _hook "git push origin main"
    [ "$status" -eq 0 ]
}

@test "block message states the text-gate limit honestly and names how to request approval" {
    run _hook "git push --force origin main"
    [ "$status" -eq 2 ]
    [[ "$output" == *"reads only the command you typed"* ]]
    [[ "$output" == *"NOT inspected by this gate"* ]]
    [[ "$output" == *"pre-push hook (T-3594)"* ]]
    [[ "$output" == *"inside a script has no equivalent"* ]]
    [[ "$output" == *"tier0 approve"* ]]
}

@test "fw tier0 status lists live action approvals" {
    _hook "git push --force origin main" 2>/dev/null || true
    _approve >/dev/null
    run bash -c "cd '$FX' && env -u CLAUDECODE PROJECT_ROOT='$FX' '$FRAMEWORK_ROOT/bin/fw' tier0 status"
    [ "$status" -eq 0 ]
    [[ "$output" == *"FORCE-PUSH ref 'main'"* ]]
}
