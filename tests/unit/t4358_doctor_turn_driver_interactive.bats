#!/usr/bin/env bats
# T-4358 (GH #101) — doctor must not WARN "TURN DRIVER is not armed" for an
# ordinary interactive claude-fw session. The wrapper records a `start` event
# on every launch, so the turn-driver sub-check runs for every session; only an
# ARMED state (enabled: true) that has stopped is the T-3225 failure worth a
# WARN. Never armed, or deliberately disarmed, is informational.
#
# The block under test is taken from bin/fw itself (the turn-driver sub-check
# inside the Continuous-run `start|iterate` branch) and run against fixture
# projects with the real lib/continuous-mode.sh.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    PROJ="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$PROJ/.context/working"
}

_block() {
    awk '/TURN DRIVER is armed lives/{seen=1}
         seen && !on && /lib\/continuous-mode\.sh" \]; then/{on=1}
         on && /"\$\{_crl_pid:-\}" \]/{exit}
         on{print}' "$FRAMEWORK_ROOT/bin/fw"
}

_run_block() {
    local block
    block="$(_block)"
    [ -n "$block" ]
    run env PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" /bin/bash -c "_section() {
GREEN=''; YELLOW=''; CYAN=''; NC=''
$block
}; _section"
}

_future() { date -u -d '+2 hours' +%Y-%m-%dT%H:%M:%SZ; }
_past()   { date -u -d '-3 days'  +%Y-%m-%dT%H:%M:%SZ; }

@test "T-4358: the block is found in bin/fw" {
    block="$(_block)"
    [[ "$block" == *"fw_continuous_cli status"* ]]
    [[ "$block" == *"TURN DRIVER is not armed"* ]]
}

@test "T-4358: never armed (no state file) is informational, not a WARN" {
    _run_block
    [[ "$output" == *"turn driver: not armed"* ]]
    [[ "$output" != *"WARN"* ]]
}

@test "T-4358: deliberately disarmed (enabled: false) is informational, not a WARN" {
    printf 'enabled: false\ncurrent_iteration: 0\n' > "$PROJ/.context/working/.continuous-mode.yaml"
    _run_block
    [[ "$output" == *"turn driver: not armed"* ]]
    [[ "$output" != *"WARN"* ]]
}

@test "T-4358/control: armed with a lapsed directive still WARNs (T-3225 case)" {
    printf 'enabled: true\ncurrent_iteration: 0\n' > "$PROJ/.context/working/.continuous-mode.yaml"
    printf 'filed_at: %s\nexpires_at: %s\n' "$(_past)" "$(_past)" > "$PROJ/.context/working/.next-directive.yaml"
    _run_block
    [[ "$output" == *"WARN"*"TURN DRIVER is not armed"* ]]
    [[ "$output" == *"lapsed"* ]]
}

@test "T-4358/control: armed and live reports ARMED" {
    printf 'enabled: true\ncurrent_iteration: 0\n' > "$PROJ/.context/working/.continuous-mode.yaml"
    printf 'filed_at: %s\nexpires_at: %s\n' "$(_past)" "$(_future)" > "$PROJ/.context/working/.next-directive.yaml"
    _run_block
    [[ "$output" == *"turn driver: ARMED"* ]]
    [[ "$output" != *"WARN"* ]]
}
