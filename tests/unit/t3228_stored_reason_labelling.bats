#!/usr/bin/env bats
# T-3228 (arc-012, review C1): the stop-driver's replayed last_terminated_reason
# must read as STORED, carry exactly one clock (log()'s own), and name
# terminated_at — or say "unknown" when it is absent.
#
# Origin: 18 consecutive .stop-driver.log lines of the shape
#   2026-08-31T11:24:20Z decision=stop reason=terminated(expires_at ... (now 2026-08-26T12:50:35Z))
# Two clocks, five days apart, the stale one reading as current.
#
# Every test drives the REAL python brake extracted from stop-driver.sh — not a
# reimplementation. A guard that reimplements the code it guards cannot detect
# that code being fixed (peer 577 finding, chat arc @689).

setup() {
    REPO="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    DRIVER="$REPO/agents/context/stop-driver.sh"
    TMP="$(mktemp -d)"
    # Extract the heredoc'd python brake verbatim from the driver.
    awk '/^verdict=\$\(python3 - /{f=1;next} f&&/^PY$/{exit} f' "$DRIVER" > "$TMP/brake.py"
    [ -s "$TMP/brake.py" ] || { echo "extraction failed — driver shape changed" >&2; return 1; }
    printf 'filed_at: 2026-01-01T00:00:00Z\n' > "$TMP/directive.yaml"
}

teardown() { rm -rf "$TMP"; }

run_brake() { run python3 "$TMP/brake.py" "$TMP/state.yaml" "$TMP/directive.yaml"; }

@test "T-3228 control: a disarmed loop with a stored reason still reports that reason" {
    cat > "$TMP/state.yaml" <<'EOF'
enabled: false
last_terminated_reason: "human-gate:human-ac:T-3199"
EOF
    run_brake
    [ "$status" -eq 0 ]
    [[ "$output" == stop\ * ]]
    # The control: the reason must survive. If this fails the others are meaningless.
    [[ "$output" == *"human-gate:human-ac:T-3199"* ]]
}

@test "T-3228 the replayed reason is marked stored, not presented as live" {
    cat > "$TMP/state.yaml" <<'EOF'
enabled: false
last_terminated_reason: "human-gate:human-ac:T-3199"
terminated_at: "2026-08-26T12:50:35Z"
EOF
    run_brake
    [ "$status" -eq 0 ]
    [[ "$output" == *"stored@"* ]]
    [[ "$output" == *"stored@2026-08-26T12:50:35Z"* ]]
}

@test "T-3228 an embedded (now ...) clock is stripped from the replayed reason" {
    cat > "$TMP/state.yaml" <<'EOF'
enabled: false
last_terminated_reason: "expires_at 2026-06-17T00:00:00Z passed (now 2026-08-26T12:50:35Z)"
EOF
    run_brake
    [ "$status" -eq 0 ]
    # The frozen clock must not appear at all — this is the origin defect.
    [[ "$output" != *"(now "* ]]
    [[ "$output" != *"2026-08-26T12:50:35Z"* ]]
    # ...while the substantive part of the reason survives.
    [[ "$output" == *"expires_at 2026-06-17T00:00:00Z passed"* ]]
}

@test "T-3228 absent terminated_at is stated as unknown, not silently omitted" {
    cat > "$TMP/state.yaml" <<'EOF'
enabled: false
last_terminated_reason: "expires_at 2026-06-17T00:00:00Z passed (now 2026-08-26T12:50:35Z)"
EOF
    run_brake
    [ "$status" -eq 0 ]
    [[ "$output" == *"stored@unknown"* ]]
}

@test "T-3228 control: an armed loop does not take the stored-reason branch at all" {
    cat > "$TMP/state.yaml" <<'EOF'
enabled: true
last_terminated_reason: "human-gate:human-ac:T-3199"
max_iterations: 5
current_iteration: 1
EOF
    run_brake
    [ "$status" -eq 0 ]
    # Separates "the branch fires correctly" from "the branch always fires".
    [[ "$output" != *"stored@"* ]]
}
