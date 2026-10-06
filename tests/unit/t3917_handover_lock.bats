#!/usr/bin/env bats
# T-3917 (G-110, RC-2 of ring20-manager's T-2248) — the budget-critical
# auto-handover lock can no longer disable the auto-handover forever.
# Measured: AEF's own .handover-in-progress was stale since 2026-06-09 (content
# "1"), ring20-manager's ~163 days; every critical checkpoint skipped silently.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    T="$(mktemp -d)"
    LOCK="$T/.handover-in-progress"
    source "$FRAMEWORK_ROOT/lib/handover-lock.sh"
    unset FW_HANDOVER_TOTAL_TIMEOUT
}

teardown() { rm -rf "$T"; }

@test "T-3917: a 4-month-old legacy lock ('1') is stale" {
    echo 1 > "$LOCK"
    touch -d "2026-06-09 18:55:40" "$LOCK"
    run fw_handover_lock_stale "$LOCK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"legacy lock (no pid)"*"day(s) old"* ]]
}

@test "T-3917/control: a fresh legacy lock still blocks" {
    echo 1 > "$LOCK"
    run fw_handover_lock_stale "$LOCK"
    [ "$status" -eq 1 ]
}

@test "T-3917/control: a fresh lock held by a live pid blocks" {
    printf '%s %s\n' "$(date +%s)" "$$" > "$LOCK"
    run fw_handover_lock_stale "$LOCK"
    [ "$status" -eq 1 ]
}

@test "T-3917: a lock whose writer pid is dead is stale" {
    sleep 0.01 & dead=$!; wait "$dead"
    printf '%s %s\n' "$(date +%s)" "$dead" > "$LOCK"
    run fw_handover_lock_stale "$LOCK"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no longer running"* ]]
}

@test "T-3917: a live-pid lock past 2 x FW_HANDOVER_TOTAL_TIMEOUT (floor 300 s) is stale" {
    printf '%s %s\n' "$(( $(date +%s) - 301 ))" "$$" > "$LOCK"
    run fw_handover_lock_stale "$LOCK"
    [ "$status" -eq 0 ]
    export FW_HANDOVER_TOTAL_TIMEOUT=600
    run fw_handover_lock_stale "$LOCK"
    [ "$status" -eq 1 ]            # 301 s < 1200 s
}

@test "T-3917: fw_handover_lock_write records epoch and pid" {
    fw_handover_lock_write "$LOCK"
    read -r epoch pid < "$LOCK"
    [[ "$epoch" =~ ^[0-9]+$ ]] && [ "$pid" = "$$" ]
}

@test "T-3917: the trapped handover subshell removes the lock when it is SIGTERMed" {
    fw_handover_lock_write "$LOCK"
    ( trap 'rm -f "$LOCK"' EXIT INT TERM HUP; sleep 30 ) &
    sub=$!
    sleep 0.3
    kill -TERM "$sub"
    wait "$sub" 2>/dev/null || true
    [ ! -f "$LOCK" ]
}

@test "T-3917: checkpoint.sh clears a stale lock through the shared predicate and traps the handover subshell" {
    f="$FRAMEWORK_ROOT/agents/context/checkpoint.sh"
    grep -q 'source "$FRAMEWORK_ROOT/lib/handover-lock.sh"' "$f"
    grep -q 'fw_handover_lock_stale "$handover_lock"' "$f"
    grep -q 'fw_handover_lock_write "$handover_lock"' "$f"
    grep -q "trap 'rm -f \"\$handover_lock\"' EXIT INT TERM HUP" "$f"
    ! grep -q 'echo "1" > "$handover_lock"' "$f"
}

@test "T-3917: fw doctor reports a stale lock with the same predicate" {
    grep -q 'Stale .handover-in-progress' "$FRAMEWORK_ROOT/bin/fw"
    grep -q 'fw_handover_lock_stale "$ho_lock"' "$FRAMEWORK_ROOT/bin/fw"
}
