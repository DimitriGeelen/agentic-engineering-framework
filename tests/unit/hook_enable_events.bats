#!/usr/bin/env bats
# T-3170 (arc-012 S4) — hook-enable must accept every event Claude Code fires,
# and our SessionEnd handler must stay unregistered.
#
# The second half is the unusual one: it asserts an ABSENCE, because T-1459 decided
# reference-only and a decision with nothing enforcing it is just a comment someone
# will overwrite.

setup() {
    HOOK_ENABLE="${BATS_TEST_DIRNAME}/../../bin/hook-enable.sh"
    SETTINGS="${BATS_TEST_DIRNAME}/../../.claude/settings.json"
    HANDLER="${BATS_TEST_DIRNAME}/../../agents/context/session-end.sh"
    TMP="$(mktemp -d)"
}

teardown() {
    [ -n "${TMP:-}" ] && rm -rf "$TMP"
}

@test "SessionEnd is a valid event" {
    grep -q 'VALID_EVENTS=.*SessionEnd' "$HOOK_ENABLE"
}

@test "every event Claude Code fires is accepted" {
    for e in PostToolUse PreToolUse SessionStart SessionEnd PreCompact Stop SubagentStop UserPromptSubmit; do
        grep -q "VALID_EVENTS=.*${e}" "$HOOK_ENABLE" || {
            echo "missing event: $e"
            return 1
        }
    done
}

@test "the tool actually accepts --event SessionEnd, not just the string in a variable" {
    # The control leg for the two greps above: they would pass against a build where
    # the validator reads some other list entirely.
    echo '{}' > "$TMP/settings.json"
    run bash "$HOOK_ENABLE" --script /bin/true --matcher "" --event SessionEnd \
        --file "$TMP/settings.json" --dry-run
    [ "$status" -eq 0 ]
}

@test "an event Claude Code does not fire is still rejected" {
    # Otherwise the test above passes against a validator that accepts anything.
    echo '{}' > "$TMP/settings.json"
    run bash "$HOOK_ENABLE" --script /bin/true --matcher "" --event NotAnEvent \
        --file "$TMP/settings.json" --dry-run
    [ "$status" -ne 0 ]
}

@test "session-end.sh is NOT registered — T-1459 decided reference-only" {
    # G-016 was a handover commit storm. Registering this handler re-opens it, and
    # the decision to leave it parked needs something that fails when reversed.
    # T-5054: the SessionEnd EVENT may carry other handlers — the TermLink adapter2 report
    # (`fw hook sidecar-adapter2 session-end`) only tells the meter the session ended and
    # commits nothing. What T-1459 parked is session-end.sh itself: refused by hook name
    # (`fw hook session-end`) or by path, on any event.
    run python3 -c "
import json, re
d = json.load(open('$SETTINGS'))
cmds = [h.get('command', '') for ev in d.get('hooks', {}).values() for m in ev for h in m.get('hooks', [])]
bad = [c for c in cmds if 'session-end.sh' in c or re.search(r'\bfw hook session-end(\s|$)', c)]
print('PRESENT: ' + '; '.join(bad) if bad else 'ABSENT')"
    [ "$output" = "ABSENT" ]
}

@test "control: the session-end.sh check fires when it IS registered (by name or path)" {
    for cmd in '/x/bin/fw hook session-end' '/x/agents/context/session-end.sh'; do
        printf '{"hooks":{"SessionEnd":[{"matcher":"","hooks":[{"type":"command","command":"%s"}]}]}}' "$cmd" > "$TMP/s.json"
        run python3 -c "
import json, re
d = json.load(open('$TMP/s.json'))
cmds = [h.get('command', '') for ev in d.get('hooks', {}).values() for m in ev for h in m.get('hooks', [])]
bad = [c for c in cmds if 'session-end.sh' in c or re.search(r'\bfw hook session-end(\s|$)', c)]
print('PRESENT' if bad else 'ABSENT')"
        [ "$output" = "PRESENT" ]
    done
}

@test "the handler's header names the precondition, not just a task number" {
    grep -q 'G-016' "$HANDLER"
    grep -q 'REFERENCE ONLY' "$HANDLER"
}
