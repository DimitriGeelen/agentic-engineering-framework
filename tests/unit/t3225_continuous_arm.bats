#!/usr/bin/env bats
# T-3225 — `fw continuous arm|disarm|status`, and the stop driver's response to it.
#
# The loop shipped disarmed (T-3164) with no verb to arm it. Arming meant five
# fields across TWO files, and the second one — `.next-directive.yaml:expires_at`
# — is the expiry `stop-driver.sh` actually reads. A run can be `enabled: true`
# and still stop dead on a directive expiry from months ago, which is what
# happened for 74 days.
#
# Every arm/disarm leg is paired with the driver's ACTUAL verdict on a sandbox,
# because the thing under test is not "did the YAML change" but "does the loop
# take its next turn". A test that only asserts the file contents would have
# passed throughout the 74-day outage.
#
# Fixture discipline (peer 832, agent-chat-arc @828): the sandbox carries a
# `.framework.yaml` marker so `fw_reanchor_from_cwd` cannot silently degrade to
# the live repo, AND setup asserts the fixture took hold rather than trusting it.
# A prober that cannot tell "fixture honoured" from "live state happened to
# agree" is inert while looking green.

setup() {
    REPO="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    FW="$REPO/bin/fw"
    DRIVER="$REPO/agents/context/stop-driver.sh"
    SB="$BATS_TEST_TMPDIR/sandbox"
    mkdir -p "$SB/.context/working" "$SB/.tasks/active"
    touch "$SB/.framework.yaml"
    PROBE="{\"session_id\":\"t3225\",\"transcript_path\":\"/dev/null\",\"stop_hook_active\":false,\"cwd\":\"$SB\"}"

    # Fixture assertion, not a spot-check: the sandbox must not BE the repo.
    [ "$SB" != "$REPO" ]
    [ -f "$SB/.framework.yaml" ]
}

driver_verdict() {
    printf '%s' "$PROBE" | CLAUDE_PROJECT_DIR="$SB" bash "$DRIVER" 2>/dev/null
}

@test "status on a fresh sandbox reports STOPPED and exits 1" {
    run env PROJECT_ROOT="$SB" "$FW" continuous status
    [ "$status" -eq 1 ]
    [[ "$output" == *"STOPPED"* ]]
}

@test "arm reports ARMED and exits 0" {
    run env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3 --directive "t3225 fixture"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ARMED"* ]]
}

@test "MUTATION CONTROL: driver yields {} unarmed and blocks armed" {
    # Both legs asserted. Neither alone can distinguish a working driver from
    # one that always returns the same thing.
    run driver_verdict
    [ "$output" = "{}" ]

    env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3 --directive "t3225 fixture" >/dev/null
    run driver_verdict
    [[ "$output" == *'"decision": "block"'* ]]
    [[ "$output" == *"iteration-1"* ]]
}

@test "disarm returns the driver to {} and records the reason" {
    env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3 --directive "t3225 fixture" >/dev/null
    run driver_verdict
    [[ "$output" == *'"decision": "block"'* ]]

    run env PROJECT_ROOT="$SB" "$FW" continuous disarm --reason "pinned by t3225"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pinned by t3225"* ]]

    run driver_verdict
    [ "$output" = "{}" ]
}

@test "halt file outranks an armed loop, and arm refuses under it (exit 3)" {
    env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3 --directive "t3225 fixture" >/dev/null
    touch "$SB/.context/working/.continuous-halt"

    run driver_verdict
    [ "$output" = "{}" ]

    run env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2
    [ "$status" -eq 3 ]
    [[ "$output" == *"halt file present"* ]]
}

@test "an unbounded arm is refused, not defaulted (exit 2)" {
    run env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 999
    [ "$status" -eq 2 ]
    [[ "$output" == *"24h ceiling"* ]]

    run env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 0
    [ "$status" -eq 2 ]
}

@test "arm clears a stale directive expiry — the 74-day blocker" {
    # The origin state: enabled true would not have been enough, because the
    # directive's own expires_at had lapsed. Arm must rewrite BOTH.
    cat > "$SB/.context/working/.next-directive.yaml" <<'EOF'
directive: stale
filed_at: 2026-06-14T18:20:00Z
expires_at: 2026-06-17T00:00:00Z
max_iterations: 5
EOF
    cat > "$SB/.context/working/.continuous-mode.yaml" <<'EOF'
enabled: true
current_iteration: 0
tier_ceiling: 1
EOF
    # enabled:true alone leaves the loop dead on the stale directive expiry.
    run driver_verdict
    [ "$output" = "{}" ]

    run env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3
    [ "$status" -eq 0 ]
    run driver_verdict
    [[ "$output" == *'"decision": "block"'* ]]
}

@test "status names BOTH blockers when both are live" {
    cat > "$SB/.context/working/.next-directive.yaml" <<'EOF'
directive: stale
filed_at: 2026-06-14T18:20:00Z
expires_at: 2026-06-17T00:00:00Z
EOF
    cat > "$SB/.context/working/.continuous-mode.yaml" <<'EOF'
enabled: false
current_iteration: 3
EOF
    run env PROJECT_ROOT="$SB" "$FW" continuous status
    [ "$status" -eq 1 ]
    [[ "$output" == *"ALSO blocking"* ]]
    [[ "$output" == *"enabled is not true"* ]]
    [[ "$output" == *"lapsed"* ]]
}

@test "status labels last_terminated_reason as stored, not re-evaluated" {
    # The 74-day failure was readable the whole time as a frozen `now` recited
    # from state. Whatever else status prints, it must not present that string
    # as a live evaluation.
    cat > "$SB/.context/working/.continuous-mode.yaml" <<'EOF'
enabled: false
current_iteration: 3
last_terminated_reason: 'expires_at 2026-06-17T00:00:00Z passed (now 2026-08-26T12:50:35Z)'
EOF
    run env PROJECT_ROOT="$SB" "$FW" continuous status
    [[ "$output" == *"NOT re-evaluated"* ]]
}

@test "an unknown subcommand and a bad option both exit 2" {
    run env PROJECT_ROOT="$SB" "$FW" continuous frobnicate
    [ "$status" -eq 2 ]
    run env PROJECT_ROOT="$SB" "$FW" continuous status --nonsense
    [ "$status" -eq 2 ]
}
