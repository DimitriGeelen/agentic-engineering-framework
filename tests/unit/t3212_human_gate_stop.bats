#!/usr/bin/env bats
# T-3212 (arc-012 IW-5) — a human gate STOPS the continuous run and says why.
#
# WHAT THIS PINS.
#
# Two properties, and they fail in opposite directions:
#
#   1. When the loop is ARMED and a task hits a human gate, the loop disarms and
#      records which task and which gate class stopped it. Failing to disarm is
#      the park-and-next behaviour this slice exists to end.
#   2. When the loop is DISARMED — every ordinary session — the helper is a
#      silent no-op that cannot fail a task close. Over-firing here would write a
#      termination reason onto a run that was never running, which is worse than
#      the ambiguity the field was added to remove.
#
# So the negative tests are not padding. Each one is a way the helper could be
# "working" while being wrong.
#
# The MUTATION test at the bottom is the control leg: it strips the disarm from a
# real copy of the shipped helper and asserts the positive test's subject stops
# holding. That is what makes the positive tests evidence rather than decoration.
#
# ── WHY EVERY NEGATIVE ASSERTION HERE IS `run` + `[ "$status" -ne 0 ]` ────────
#
# NOT `! grep -q PAT file`. That form is INERT under bats and cannot fail a test.
# POSIX: "the -e setting shall be ignored when executing ... any command preceded
# by !". So a negated assertion that does not hold returns 1, errexit skips it,
# and the test passes. Measured, this file, 2026-08-29:
#
#     @test "..." { ! true; }     -> ok       (should have failed)
#     @test "..." { false; }      -> not ok   (control)
#
# Found because mutating the shipped helper left the mutation test itself green
# when its own `! diff -q` guard should have bitten. Same family as T-3203's
# finding about errexit suppression in the P-011 gate: a construct that looks
# like an assertion, reads like an assertion, and is not one.

# assert_no: the negative assertion that actually reddens.
assert_no() {
    run "$@"
    [ "$status" -ne 0 ]
}

setup() {
    FWROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FWROOT
    LIB="$FWROOT/lib/continuous-mode.sh"
    DRIVER="$FWROOT/agents/context/stop-driver.sh"
    TMP="$(mktemp -d)"
    export TMP
    mkdir -p "$TMP/.context/working"
    STATE="$TMP/.context/working/.continuous-mode.yaml"
    LOG="$TMP/.context/working/.stop-driver.log"
}

teardown() {
    [ -n "${TMP:-}" ] && rm -rf "$TMP"
}

armed_state() {
    cat > "$STATE" <<YAML
enabled: true
max_iterations: 10
current_iteration: 1
tasks_completed: 0
YAML
}

# Source the shipped helper and fire it. $1=task $2=gate-class
note_gate() {
    bash -c ". '$LIB'; fw_continuous_note_human_gate '$1' '$2' '$TMP'"
}

# ── The positive case ────────────────────────────────────────────────────────

@test "T-3212: an armed loop DISARMS when a task hits a human gate" {
    armed_state
    run note_gate "T-9001" "human-ac"
    [ "$status" -eq 0 ]
    grep -q '^enabled: false' "$STATE"
}

@test "T-3212: the reason names the task AND the gate class, not just the flag" {
    # `enabled: false` alone cannot distinguish "operator never armed it" from
    # "the loop stopped itself here" — that ambiguity is the whole defect.
    armed_state
    note_gate "T-9002" "human-ac"
    grep -q 'last_terminated_reason: human-gate:human-ac:T-9002' "$STATE"
}

@test "T-3212: terminated_at is recorded in ISO-8601 Z form" {
    armed_state
    note_gate "T-9003" "human-ac"
    grep -qE 'terminated_at: .?[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z' "$STATE"
}

@test "T-3212: the gate class is carried through, so Tier-0 slots in unchanged" {
    # The scope fence says only the partial-complete call site ships here. This
    # asserts the helper is not hard-wired to it, which is what makes that fence
    # a scope decision rather than a design limit.
    armed_state
    note_gate "T-9004" "tier0"
    grep -q 'last_terminated_reason: human-gate:tier0:T-9004' "$STATE"
}

@test "T-3212: pre-existing counters survive the disarm" {
    # A rewrite that dropped tasks_completed would silently reset the task
    # ceiling, so the next armed run gets a budget it already spent.
    armed_state
    note_gate "T-9005" "human-ac"
    grep -q 'tasks_completed: 0' "$STATE"
    grep -q 'max_iterations: 10' "$STATE"
}

# ── The negative cases: each is a way the helper could over-fire ─────────────

@test "T-3212: a DISARMED loop is untouched — no reason is invented" {
    echo "enabled: false" > "$STATE"
    run note_gate "T-9006" "human-ac"
    [ "$status" -eq 0 ]
    assert_no grep -q 'last_terminated_reason' "$STATE"
}

@test "T-3212: an absent state file is a silent no-op, not a failed close" {
    run note_gate "T-9007" "human-ac"
    [ "$status" -eq 0 ]
    [ ! -f "$STATE" ]
}

@test "T-3212: malformed YAML is a silent no-op, not a failed close" {
    printf 'enabled: true\n  : : bad\n[[[\n' > "$STATE"
    run note_gate "T-9008" "human-ac"
    [ "$status" -eq 0 ]
}

@test "T-3212: an empty task id is refused without touching state" {
    armed_state
    run note_gate "" "human-ac"
    [ "$status" -eq 0 ]
    grep -q '^enabled: true' "$STATE"
}

# ── The stop-driver reads the reason back ───────────────────────────────────

@test "T-3212: stop-driver reports the recorded termination reason" {
    armed_state
    note_gate "T-9010" "human-ac"
    CLAUDE_PROJECT_DIR="$TMP" bash -c "printf '{}' | bash '$DRIVER'" >/dev/null
    grep -q 'reason=terminated(human-gate:human-ac:T-9010)' "$LOG"
}

@test "T-3212: CONTROL — with no reason recorded it still says disarmed" {
    # Control for the test above: proves that assertion tracks a state change
    # rather than a string the driver always emits.
    echo "enabled: false" > "$STATE"
    CLAUDE_PROJECT_DIR="$TMP" bash -c "printf '{}' | bash '$DRIVER'" >/dev/null
    grep -q 'continuous-mode-disabled' "$LOG"
    assert_no grep -q 'terminated(' "$LOG"
}

@test "T-3212: stopping is still the verdict — the driver yields, it does not drive" {
    armed_state
    note_gate "T-9011" "human-ac"
    run bash -c "CLAUDE_PROJECT_DIR='$TMP' bash -c \"printf '{}' | bash '$DRIVER'\""
    [ "$status" -eq 0 ]
    [ "$output" = "{}" ]
}

# ── The control leg ──────────────────────────────────────────────────────────

@test "T-3212: MUTATION — strip the disarm and the positive assertion reddens" {
    # Build a real copy of the shipped helper with ONE line removed: the
    # assignment that disarms the loop. If the suite stays green against that,
    # the positive tests are asserting something other than what they claim.
    MUT="$TMP/mutated-continuous-mode.sh"
    grep -v '^state\["enabled"\] = False$' "$LIB" > "$MUT"

    # The mutation must actually remove something — a mutation that changes no
    # bytes reddens nothing for an uninteresting reason, and would make this
    # control vacuous in exactly the way it exists to detect. This guard caught
    # precisely that during the run that wrote it, but only after `! diff` was
    # replaced with a form that can fail (see assert_no above).
    assert_no diff -q "$LIB" "$MUT"

    armed_state
    bash -c ". '$MUT'; fw_continuous_note_human_gate 'T-9012' 'human-ac' '$TMP'"

    # The subject of the first positive test no longer holds.
    assert_no grep -q '^enabled: false' "$STATE"
    grep -q '^enabled: true' "$STATE"

    # ...and the reason alone is NOT enough: without the disarm the loop keeps
    # driving turns while claiming to have terminated, which is a worse state
    # than either failure on its own. This is why the disarm and the reason are
    # asserted separately rather than as one compound check.
    grep -q 'last_terminated_reason: human-gate:human-ac:T-9012' "$STATE"
}
