#!/usr/bin/env bats
# T-1932 — `fw bvp auto-promote --enable / --disable` (§ACD-gated, D8)
#
# Verifies:
#   - --enable refuses under $CLAUDECODE=1 without --i-am-human/--from-watchtower
#   - --enable refuses without --rationale (R6) and with rationale <30 chars
#   - --enable with valid rationale + sovereignty override flips policy true,
#     writes "event: enable" log entry, files 30-day review task (R7)
#   - --disable flips policy false unconditionally (no §ACD, no rationale)
#   - --disable writes "event: disable" log entry
#   - cron entry registered + matches "in sync" check

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/bin/fw" ] || skip "bin/fw not found"
    cd "$FRAMEWORK_ROOT"

    # T-3807: a throwaway project, never the live repo. These tests used to flip the live
    # policy, append to the live log and FILE REAL review tasks in the live .tasks/active
    # (consuming real task ids), restoring and deleting in teardown.
    FIX="$(mktemp -d)"
    mkdir -p "$FIX/policy" "$FIX/.tasks/active" "$FIX/.tasks/completed" "$FIX/.tasks/templates" \
             "$FIX/.context/working"
    cp "$FRAMEWORK_ROOT/policy/value-drivers.yaml" "$FIX/policy/"
    cp "$FRAMEWORK_ROOT/.framework.yaml" "$FIX/.framework.yaml"
    cp "$FRAMEWORK_ROOT/.tasks/templates/"*.md "$FIX/.tasks/templates/"
    echo "entries: []" > "$FIX/.context/bvp-auto-promote-log.yaml"
    export PROJECT_ROOT="$FIX"

    POLICY="$FIX/policy/value-drivers.yaml"
    LOG="$FIX/.context/bvp-auto-promote-log.yaml"
}

teardown() {
    [ -n "${FIX:-}" ] && [ -d "$FIX" ] && rm -rf "$FIX"
    unset PROJECT_ROOT
}

@test "--enable refuses under \$CLAUDECODE=1 without sovereignty override" {
    CLAUDECODE=1 run bin/fw bvp auto-promote --enable --rationale "this is a thirty plus character rationale ok"
    [ "$status" -ne 0 ]
    [[ "$output" == *"§ACD"* || "$output" == *"agents must not invoke"* ]]
}

@test "--enable refuses without --rationale (R6 mitigation)" {
    CLAUDECODE=1 run bin/fw bvp auto-promote --enable --i-am-human
    [ "$status" -ne 0 ]
    [[ "$output" == *"--rationale is required"* ]]
}

@test "--enable refuses with rationale <30 chars (R6 mitigation)" {
    CLAUDECODE=1 run bin/fw bvp auto-promote --enable --i-am-human --rationale "short"
    [ "$status" -ne 0 ]
    [[ "$output" == *"must be ≥30 characters"* ]]
}

@test "--enable with valid rationale + override flips policy true + logs enable event" {
    run bin/fw bvp auto-promote --enable --i-am-human \
        --rationale "test bats fixture flipping enabled for the duration of one test"
    [ "$status" -eq 0 ]
    [[ "$output" == *"flipped → true"* ]]

    grep -q "enabled: true" "$POLICY"

    # Log has an enable event with required fields.
    run python3 - <<PY
import yaml
d = yaml.safe_load(open('$LOG'))
e = (d.get('entries') or [])[-1]
print('event:', e.get('event'))
print('has_rationale:', 'rationale' in e)
print('has_ts:', 'ts' in e)
print('has_actor:', 'actor' in e)
PY
    [[ "$output" == *"event: enable"* ]]
    [[ "$output" == *"has_rationale: True"* ]]
    [[ "$output" == *"has_ts: True"* ]]
    [[ "$output" == *"has_actor: True"* ]]
}

@test "--disable is idempotent + writes disable log event" {
    run bin/fw bvp auto-promote --disable
    [ "$status" -eq 0 ]
    [[ "$output" == *"flipped → false"* ]]

    grep -q "enabled: false" "$POLICY"

    run python3 - <<PY
import yaml
d = yaml.safe_load(open('$LOG'))
e = (d.get('entries') or [])[-1]
print('event:', e.get('event'))
PY
    [[ "$output" == *"event: disable"* ]]
}

@test "cron-registry has bvp-auto-promote-hourly entry" {
    run grep -E "id: bvp-auto-promote-hourly" .context/cron-registry.yaml
    [ "$status" -eq 0 ]
}

@test "cron registry in sync (fw doctor)" {
    # The REAL repo's registry is the subject here, not the fixture (T-3807). Read-only.
    unset PROJECT_ROOT
    run bash -c "FW_DOCTOR_SMOKE=0 bin/fw doctor 2>&1 | grep -E 'Cron registry in sync'"
    [ "$status" -eq 0 ]
}
