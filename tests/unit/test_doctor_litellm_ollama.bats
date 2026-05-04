#!/usr/bin/env bats
# T-1700 — fw doctor: litellm-proxy + ollama reachability checks.
#
# Pins the skip-if-no-consumer pattern (mirror of T-1694 pi check):
#   1. The check ONLY fires when a workflow file declares the marker.
#   2. When a workflow declares ANTHROPIC_BASE_URL: http://localhost:4000,
#      doctor probes :4000/health.
#   3. When a workflow declares worker_kind: ollama-loop, doctor probes
#      192.168.10.107:11434/api/tags.
#   4. Both checks are host-scope (use _doctor_warn_host on failure).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    FW_BIN="$FRAMEWORK_ROOT/bin/fw"
    [ -x "$FW_BIN" ]
}

@test "do_doctor body contains litellm-proxy reachable check" {
    grep -q "litellm-proxy reachable" "$FW_BIN"
    grep -q "http://localhost:4000/health" "$FW_BIN"
}

@test "do_doctor body contains ollama reachable check" {
    grep -q "ollama reachable" "$FW_BIN"
    grep -q "192.168.10.107:11434/api/tags" "$FW_BIN"
}

@test "litellm check is gated on ANTHROPIC_BASE_URL workflow marker" {
    # Skip-if-no-consumer: presence of ANTHROPIC_BASE_URL: http://localhost:4000
    # in any workflow file gates the litellm reachability probe.
    grep -q 'ANTHROPIC_BASE_URL:\\s\*http://localhost:4000' "$FW_BIN"
}

@test "ollama check is gated on worker_kind: ollama-loop workflow marker" {
    grep -q 'worker_kind:\\s\*ollama-loop' "$FW_BIN"
}

@test "litellm + ollama failures route through _doctor_warn_host" {
    # Drift detector: either both go through the helper (host-scope) or
    # both are project-scope. They must NOT split — ollama / litellm are
    # always host-level (network reachability to other machines / proxies).
    local litellm_block ollama_block
    litellm_block=$(awk '/litellm-proxy not reachable/,/fi/' "$FW_BIN" | head -10)
    ollama_block=$(awk '/ollama not reachable/,/fi/' "$FW_BIN" | head -5)
    echo "$litellm_block" | grep -q "_doctor_warn_host"
    echo "$ollama_block" | grep -q "_doctor_warn_host"
}

@test "fw doctor exits cleanly on this project (litellm/ollama checks don't FAIL)" {
    cd "$FRAMEWORK_ROOT"
    run "$FW_BIN" doctor
    [ "$status" -eq 0 ]
    [[ "$output" != *"FAIL"*"litellm"* ]]
    [[ "$output" != *"FAIL"*"ollama"* ]]
}
