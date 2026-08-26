#!/usr/bin/env bats
# T-3164 (arc-012 S1) — the continuous-run turn driver.
#
# The assertions that matter are the ones about what the driver REFUSES to do. A
# Stop hook that continues when it should not takes the operator's session away
# from them, so every test below is written so that removing the guard it covers
# turns it red.

setup() {
    DRIVER="${BATS_TEST_DIRNAME}/../../agents/context/stop-driver.sh"
    TMP="$(mktemp -d)"
    export CLAUDE_PROJECT_DIR="$TMP"
    mkdir -p "$TMP/.context/working"
    STATE="$TMP/.context/working/.continuous-mode.yaml"
    HALT="$TMP/.context/working/.continuous-halt"
    DIRECTIVE="$TMP/.context/working/.next-directive.yaml"
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
YAML
}

run_driver() {
    printf '%s' "${1:-{\}}" | bash "$DRIVER"
}

# --- disarmed by default: three distinct states, one test each -------------

@test "no state file at all yields stop" {
    run run_driver '{}'
    [ "$status" -eq 0 ]
    [ "$output" = "{}" ]
}

@test "enabled: false yields stop" {
    echo "enabled: false" > "$STATE"
    run run_driver '{}'
    [ "$status" -eq 0 ]
    [ "$output" = "{}" ]
}

@test "malformed state yaml yields stop, never a continue" {
    printf 'enabled: true\n  : : not: [valid\n' > "$STATE"
    run run_driver '{}'
    [ "$status" -eq 0 ]
    [ "$output" = "{}" ]
}

@test "state file present but empty yields stop" {
    : > "$STATE"
    run run_driver '{}'
    [ "$output" = "{}" ]
}

# --- the armed path, so the tests above are known to be discriminating -----
# Without this, every assertion of "{}" would pass against a driver that can
# never continue at all — the control leg, same discipline as T-3163.

@test "armed and under cap DOES continue — the discriminating control" {
    armed_state
    run run_driver '{}'
    [ "$status" -eq 0 ]
    [ "$output" != "{}" ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d.get('decision') == 'block', d
assert d.get('reason'), 'reason must be non-empty'
"
}

# --- the measured contract (T-3163) ----------------------------------------

@test "continue payload uses decision:block — the shape that actually drives a turn" {
    armed_state
    run run_driver '{}'
    echo "$output" | grep -q '"decision": "block"'
}

@test "the inert ok:false shape is never emitted" {
    armed_state
    run run_driver '{}'
    ! echo "$output" | grep -qE '"ok"[[:space:]]*:[[:space:]]*false'
}

@test "driver source emits no ok:false contract outside comments" {
    # The header documents the inert shape as a warning, which is the point of it.
    # The assertion is about what the driver can EMIT, so comments are stripped first.
    code=$(grep -vE '^[[:space:]]*#' "$DRIVER")
    ! printf '%s' "$code" | grep -qE '"ok"[[:space:]]*:[[:space:]]*false'
}

# --- brake 1: halt beats continue ------------------------------------------

@test "halt file stops the loop even when armed and under cap" {
    armed_state
    touch "$HALT"
    run run_driver '{}'
    [ "$output" = "{}" ]
}

@test "halt is checked BEFORE the enabled/cap verdict" {
    # Ordering assertion: with a halt file AND unreadable state, the logged reason
    # must name the halt. If the caps were evaluated first this would read
    # state-unreadable-or-empty instead.
    printf 'not: [valid yaml\n' > "$STATE"
    touch "$HALT"
    run run_driver '{}'
    [ "$output" = "{}" ]
    grep -q "halt-file present" "$LOG"
}

# --- brake 3: the platform runaway guard -----------------------------------

@test "stop_hook_active true yields stop even when armed" {
    armed_state
    run run_driver '{"stop_hook_active": true}'
    [ "$output" = "{}" ]
}

@test "stop_hook_active false still continues when armed" {
    armed_state
    run run_driver '{"stop_hook_active": false}'
    echo "$output" | grep -q '"decision": "block"'
}

# --- brake 2: our own caps -------------------------------------------------

@test "max_iterations reached yields stop" {
    cat > "$STATE" <<YAML
enabled: true
max_iterations: 3
current_iteration: 3
YAML
    run run_driver '{}'
    [ "$output" = "{}" ]
}

@test "expires_at in the past yields stop" {
    armed_state
    cat > "$DIRECTIVE" <<YAML
directive: "keep going"
expires_at: '2020-01-01T00:00:00Z'
YAML
    run run_driver '{}'
    [ "$output" = "{}" ]
}

@test "expires_after_seconds elapsed since filed_at yields stop" {
    cat > "$STATE" <<YAML
enabled: true
max_iterations: 10
current_iteration: 1
expires_after_seconds: 60
YAML
    cat > "$DIRECTIVE" <<YAML
directive: "keep going"
filed_at: '2020-01-01T00:00:00Z'
YAML
    run run_driver '{}'
    [ "$output" = "{}" ]
}

@test "per-directive max_iterations overrides the state value" {
    cat > "$STATE" <<YAML
enabled: true
max_iterations: 99
current_iteration: 2
YAML
    cat > "$DIRECTIVE" <<YAML
directive: "keep going"
max_iterations: 2
YAML
    run run_driver '{}'
    [ "$output" = "{}" ]
}

# --- fails closed ----------------------------------------------------------

@test "unparseable payload does not continue-by-accident" {
    armed_state
    run run_driver 'this is not json at all'
    # Armed state + unreadable payload: the payload only carries the platform
    # guard, so this legitimately continues — but it must still be a WELL-FORMED
    # decision, never a crash or a partial write.
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
}

@test "exit status is always 0 — a hook must never break the session" {
    for payload in '{}' '{"stop_hook_active": true}' 'garbage'; do
        run run_driver "$payload"
        [ "$status" -eq 0 ]
    done
}

# --- observability ---------------------------------------------------------

@test "every decision is logged with a reason" {
    armed_state
    run_driver '{}' >/dev/null
    grep -q "decision=continue" "$LOG"
    echo "enabled: false" > "$STATE"
    run_driver '{}' >/dev/null
    grep -q "decision=stop" "$LOG"
    grep -q "reason=" "$LOG"
}
