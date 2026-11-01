#!/usr/bin/env bats
# T-4953 (operator 2026-11-01, option 1; consultation docs/reports/T-4953-readonly-pipe-consult.md):
# a plain read-only gate query followed by ONE inert filter is still refused, but writes no
# approval card and no pending hash; it leaves one audit line instead. Classification is the
# whole command and fails closed: every lookalike keeps the ordinary block AND its card.
#
# SAFETY: fixtures only. The hook only DECIDES; nothing in a command under test is executed.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    W="$(mktemp -d -t fw-t4953-XXXXXX)"
    W="$(cd "$W" && pwd -P)"
    mkdir -p "$W/.tasks/active" "$W/.context/working" "$W/.context/approvals"
    unset CLAUDE_PROJECT_DIR TIER0_WATCHTOWER_TTL CDPATH TIER0_LOCK_TIMEOUT
    export W NTFY_ENABLED=false
    LOG="$W/.context/working/tier0-read-refusals.jsonl"
    PENDING="$W/.context/working/.tier0-approval.pending"
}

teardown() {
    cd /
    [ -n "${W:-}" ] && [ -d "$W" ] && rm -rf "${W:?}"
    return 0
}

_gate() {
    local json
    json=$(python3 -c "
import json, sys
print(json.dumps({'tool_input': {'command': sys.argv[1]}, 'cwd': sys.argv[2], 'tool_use_id': 'toolu_' + sys.argv[3]}))" "$1" "$W" "$RANDOM$RANDOM")
    printf '%s' "$json" | PROJECT_ROOT="$W" bash "$FRAMEWORK_ROOT/agents/context/check-tier0.sh"
}

_cards() { ls "$W/.context/approvals" 2>/dev/null | grep -c '^pending-' || true; }

@test "read-only query + one inert filter: refused, no card, no pending hash, one audit line each" {
    local c n=0
    for c in "bin/fw tier0 status | grep pending" \
             "fw tier0 list | wc -l" \
             "bin/fw tier0 | head -20" \
             "bin/fw tier0 status 2>&1 | tail -3" \
             "cd $W && bin/fw tier0 status | grep -n pending" \
             ".agentic-framework/bin/fw tier0 help|head"; do
        run _gate "$c"
        n=$((n + 1))
        [ "$status" -eq 2 ] || { echo "not refused: $c"; echo "$output"; return 1; }
        [[ "$output" == *"refused because of the pipe (T-4953)"* ]] || { echo "wrong path: $c"; echo "$output"; return 1; }
        [[ "$output" != *"TIER 0 BLOCK"* ]] || { echo "full block: $c"; return 1; }
        [ ! -e "$PENDING" ] || { echo "pending hash written: $c"; return 1; }
        [ "$(_cards)" -eq 0 ] || { echo "card written: $c"; return 1; }
        [ "$(wc -l < "$LOG")" -eq "$n" ] || { echo "audit lines != $n after: $c"; return 1; }
    done
    python3 -c "
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
assert all(r['card'] is False and r['command'] and 'T-4953' in r['reason'] for r in rows), rows
" "$LOG"
}

@test "lookalikes keep the ordinary block AND the card (whole-command match, fail closed)" {
    local c
    for c in "bin/fw tier0 status | sh" \
             "bin/fw tier0 status | bash" \
             "bin/fw tier0 status | xargs echo" \
             "bin/fw tier0 status | grep x | sh" \
             "bin/fw tier0 status | grep 'x'" \
             "bin/fw tier0 status | grep \"x\"" \
             "bin/fw tier0 status | grep \$(id)" \
             "bin/fw tier0 status | grep \`id\`" \
             "bin/fw tier0 status | tail -3 > out.txt" \
             "bin/fw tier0 status | grep x &" \
             "bin/fw tier0 status | grep x; true" \
             "bin/fw tier0 status | grep x && true" \
             "sudo bin/fw tier0 status | grep x" \
             "bin/fw tier0 approve | grep x" \
             "bin/fw tier0 status --x | grep x" \
             "bin/fw tier0 status 2>/tmp/e | grep x" \
             $'bin/fw tier0 status | grep x\nbin/fw tier0 approve'; do
        rm -f "$PENDING"
        run _gate "$c"
        [ "$status" -eq 2 ] || { echo "not blocked: $c"; echo "$output"; return 1; }
        [[ "$output" == *"TIER 0 BLOCK"* ]] || { echo "card suppressed: $c"; echo "$output"; return 1; }
        [ -e "$PENDING" ] || { echo "no pending hash: $c"; return 1; }
    done
    [ ! -e "$LOG" ] || { echo "lookalike logged as a read:"; cat "$LOG"; return 1; }
}

@test "CONTROL: the plain read-only forms still run with nothing written" {
    local c
    for c in "bin/fw tier0 status" "fw tier0 list" "bin/fw tier0" "cd $W && bin/fw tier0 help"; do
        run _gate "$c"
        [ "$status" -eq 0 ] || { echo "blocked: $c"; echo "$output"; return 1; }
    done
    [ ! -e "$LOG" ] && [ ! -e "$PENDING" ] && [ "$(_cards)" -eq 0 ]
}
