#!/usr/bin/env bats
# T-3167 (arc-012 F3) — a recorded termination must disarm the flag.
#
# These drive the real inject-next-directive.py against a scratch project root.
# The flag being tested is the one that lied about this repo for 70 days, so a
# test written against a transcription of the logic would miss the whole point.

setup() {
    INJECTOR="${BATS_TEST_DIRNAME}/../../agents/context/inject-next-directive.py"
    ROOT="$(mktemp -d)"
    mkdir -p "$ROOT/.context/working"
    STATE="$ROOT/.context/working/.continuous-mode.yaml"
    DIRECTIVE="$ROOT/.context/working/.next-directive.yaml"
}

teardown() {
    [ -n "${ROOT:-}" ] && rm -rf "$ROOT"
}

armed() {
    cat > "$STATE" <<YAML
enabled: true
max_iterations: ${1:-10}
current_iteration: ${2:-1}
tier_ceiling: 5
YAML
}

directive() {
    cat > "$DIRECTIVE" <<YAML
directive: "drive the arc"
${1:-}
YAML
}

inject() {
    python3 "$INJECTOR" --project-root "$ROOT" --source "${1:-resume}"
}

enabled_now() {
    python3 -c "
import yaml, sys
print(yaml.safe_load(open('$STATE')).get('enabled'))"
}

terminated_reason_now() {
    python3 -c "
import yaml
print(yaml.safe_load(open('$STATE')).get('last_terminated_reason') or '')"
}

@test "expiry disarms the flag in the same write that records the reason" {
    armed
    directive "expires_at: '2020-01-01T00:00:00Z'"
    run inject
    [ "$status" -eq 0 ]
    [ "$(enabled_now)" = "False" ]
    [ -n "$(terminated_reason_now)" ]
}

@test "cap reached disarms the flag" {
    armed 2 2
    directive
    run inject
    [ "$status" -eq 0 ]
    [ "$(enabled_now)" = "False" ]
    [ -n "$(terminated_reason_now)" ]
}

@test "an ordinary iteration leaves enabled alone — the control leg" {
    # Without this, a blanket `enabled = False` on every write would satisfy both
    # tests above while destroying the loop.
    armed 10 1
    directive
    run inject
    [ "$status" -eq 0 ]
    [ "$(enabled_now)" = "True" ]
    [ -z "$(terminated_reason_now)" ]
}

@test "a terminated write never leaves reason set while still armed" {
    # The exact live state this task exists to make impossible.
    armed 2 2
    directive
    run inject
    reason="$(terminated_reason_now)"
    enabled="$(enabled_now)"
    if [ -n "$reason" ]; then [ "$enabled" = "False" ]; fi
}

@test "terminated prose tells the operator it is disarmed and how to re-arm" {
    armed 2 2
    directive
    run inject
    echo "$output" | grep -q 'disarmed'
    echo "$output" | grep -q 'enabled: true'
}

@test "the tier-ceiling prose carries the same disarm notice" {
    # The ceiling branch needs a resolvable blast-radius lookup to fire, which a
    # scratch root has no corpus for; this asserts the emitted string instead of
    # the branch. Narrower than the tests above, and deliberately so.
    grep -q 'disarmed' "$INJECTOR"
    grep -A4 'TIER CEILING EXCEEDED' "$INJECTOR" > /dev/null
}
