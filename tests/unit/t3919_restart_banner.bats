#!/usr/bin/env bats
# T-3919 (G-110, RC-3 of ring20-manager's T-2248) — the restart banner says
# "Handover committed" only when a handover at least as new as the restart
# signal exists. It used to print it unconditionally.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    ROOT="$(mktemp -d)"
    mkdir -p "$ROOT/.context/handovers"
    eval "$(awk '/^_restart_handover_line\(\) \{/,/^}/' "$FRAMEWORK_ROOT/bin/claude-fw")"
}

teardown() { rm -rf "$ROOT"; }

@test "T-3919: LATEST.md newer than the signal -> 'Handover committed'" {
    echo h > "$ROOT/.context/handovers/LATEST.md"
    run _restart_handover_line "$ROOT" "$(( $(date +%s) - 30 ))"
    [[ "$output" == *"Handover committed."* ]]
}

@test "T-3919: LATEST.md older than the signal -> WARNING with its age, never 'committed'" {
    echo h > "$ROOT/.context/handovers/LATEST.md"
    touch -d "-13 hours" "$ROOT/.context/handovers/LATEST.md"
    run _restart_handover_line "$ROOT" "$(date +%s)"
    [[ "$output" == *"WARNING: NO handover since the restart signal"* ]]
    [[ "$output" == *"78"?" min old"* ]]
    [[ "$output" != *"Handover committed"* ]]
}

@test "T-3919: no LATEST.md at all -> WARNING" {
    run _restart_handover_line "$ROOT" "$(date +%s)"
    [[ "$output" == *"WARNING: NO handover exists"* ]]
}

@test "T-3919: the banner no longer prints the unconditional line" {
    # The phrase survives only as the helper's conditional branch, never at the call site.
    [ "$(grep -c 'echo "  Handover committed. Continuing in 3 seconds..."' "$FRAMEWORK_ROOT/bin/claude-fw")" -eq 1 ]
    awk '/^_restart_handover_line\(\)/,/^}/' "$FRAMEWORK_ROOT/bin/claude-fw" | grep -q 'Handover committed. Continuing'
    grep -q '_restart_handover_line "$(cd' "$FRAMEWORK_ROOT/bin/claude-fw"
}
