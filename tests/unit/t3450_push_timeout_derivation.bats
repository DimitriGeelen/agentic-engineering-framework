#!/usr/bin/env bats
# T-3450 — the handover push timeout is derived from the measured audit
# gate cost, instead of a static 300.
#
# Sibling to tests/unit/t3421_prepush_lock_wait.bats: fw_handover_push_timeout_default
# (lib/prepush-lock-wait.sh) reuses that function's extracted ledger reader
# (fw_audit_timing_read_structure_seconds) so both derivations parse
# .context/audits/full-audit-timing.yaml in exactly one place. Hermetic:
# every ledger here is a fixture under a tmpdir.
#
# NOTE on filename: T-3450's own task file and a stale comment in
# handover.sh (predating this task) both refer to
# "tests/unit/t3062_push_timeout_budget.bats" as the file that pins this
# relationship. No such file exists in this repo — the actual file is
# tests/unit/handover_push_timeout.bats (source-level pins on handover.sh's
# shape). That file already has three pre-existing failures unrelated to
# this task (stale literal-value assertions left over from T-1277/T-1341,
# predating T-3062's bump of the default to 300 — see git blame). This file
# is added as the sibling the AC anticipates, scoped to the new derivation
# only; the pre-existing failures are out of scope for T-3450 and are not
# touched. See ## Decisions in T-3450 for the full trace.

load ../test_helper

LIB="$FRAMEWORK_ROOT/lib/prepush-lock-wait.sh"

setup() {
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.context/audits"
}

teardown() {
    [ -d "${TEST_ROOT:-}" ] && rm -rf "$TEST_ROOT"
}

# ledger SECONDS [TIMED_OUT] — write a timing ledger in the shape
# audit.sh:_audit_write_timing_yaml emits.
ledger() {
    local timed_out="${2:-false}"
    cat > "$TEST_ROOT/.context/audits/full-audit-timing.yaml" <<EOF
# Full-audit run timing - written by agents/audit/audit.sh (T-3127)
last_run:
  timestamp: "2026-09-22T17:56:41+02:00"
  total_seconds: 1556
  ceiling_seconds: 3000
  timed_out: $timed_out
  sections:
    - name: "structure"
      seconds: $1
    - name: "tree"
      seconds: 182
EOF
}

run_push_default() {
    run bash -c "source '$LIB'; fw_handover_push_timeout_default '$TEST_ROOT'"
}

run_lock_default() {
    run bash -c "source '$LIB'; fw_prepush_lock_wait_default '$TEST_ROOT'"
}

# ---- AC: a large structure value yields a proportionally larger timeout ----

@test "measured 268s (2026-09-22 ledger) -> 402 (ceil 1.5x)" {
    ledger 268
    run_push_default
    [ "$status" -eq 0 ]
    [ "$output" = "402" ]
}

@test "measured 600s -> 900 (capped, ceil 1.5x hits the cap exactly)" {
    ledger 600
    run_push_default
    [ "$status" -eq 0 ]
    [ "$output" = "900" ]
}

@test "runaway measurement (1000s) is capped at 900, not an indefinite hang" {
    ledger 1000
    run_push_default
    [ "$output" = "900" ]
}

@test "tiny measurement is floored at 180" {
    ledger 10
    run_push_default
    [ "$output" = "180" ]
}

@test "larger structure value always yields a strictly larger timeout than a smaller one, in range" {
    ledger 150
    run_push_default
    small="$output"
    ledger 268
    run_push_default
    large="$output"
    [ "$large" -gt "$small" ]
}

# ---- AC: a missing file yields the fallback ----

@test "no ledger -> 650 fallback" {
    run_push_default
    [ "$status" -eq 0 ]
    [ "$output" = "650" ]
}

@test "ledger without a structure entry -> 650 fallback" {
    cat > "$TEST_ROOT/.context/audits/full-audit-timing.yaml" <<'EOF'
last_run:
  timed_out: false
  sections:
    - name: "tree"
      seconds: 325
EOF
    run_push_default
    [ "$output" = "650" ]
}

@test "non-numeric structure entry -> 650 fallback, not an error" {
    ledger "n/a"
    run_push_default
    [ "$status" -eq 0 ]
    [ "$output" = "650" ]
}

# ---- AC: a timed-out run is ignored rather than trusted ----

@test "timed_out: true -> 650 fallback even with a large measured value" {
    ledger 268 true
    run_push_default
    [ "$output" = "650" ]
}

@test "timed_out: true differs from fw_prepush_lock_wait_default, which trusts the same ledger (T-3421 pinned behaviour)" {
    ledger 268 true
    run_push_default
    push="$output"
    run_lock_default
    lock="$output"
    # Lock-wait ignores timed_out (T-3421's own tests pin this); push does not
    # (this task). The two diverge on exactly this ledger shape.
    [ "$lock" = "335" ]
    [ "$push" = "650" ]
}

# ---- AC: the derived value must exceed the lock wait, not equal it ----

@test "push timeout exceeds the lock wait at every measured value tested, including the timed-out fallback" {
    for m in 10 100 150 268 480 600 700 1000; do
        ledger "$m" false
        run_push_default
        push="$output"
        run_lock_default
        lock="$output"
        [ "$push" -gt "$lock" ] || {
            echo "m=$m: push=$push lock=$lock — push did not exceed lock"
            false
        }
    done
    # And the timed-out edge, where push falls back but lock does not.
    ledger 1000 true
    run_push_default
    push="$output"
    run_lock_default
    lock="$output"
    [ "$push" -gt "$lock" ] || {
        echo "timed-out 1000s: push=$push lock=$lock — push did not exceed lock"
        false
    }
}

# ---- AC: an explicit env var overrides all of it ----

@test "handover.sh honours an explicit FW_HANDOVER_PUSH_TIMEOUT over the derivation" {
    grep -q 'if \[ -n "\${FW_HANDOVER_PUSH_TIMEOUT:-}" \]; then' "$FRAMEWORK_ROOT/agents/handover/handover.sh"
    grep -q '_push_timeout="\$FW_HANDOVER_PUSH_TIMEOUT"' "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}

@test "handover.sh derives the default via fw_handover_push_timeout_default when unset" {
    grep -q 'fw_handover_push_timeout_default "\$PROJECT_ROOT"' "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}

@test "handover.sh logs the resolved push timeout and its source" {
    grep -q 'Push timeout: \${_push_timeout}s (\${_push_timeout_source})' "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}

@test "the old static 300 default is gone from the push-timeout assignment" {
    [ "$(grep -c '_push_timeout="\${FW_HANDOVER_PUSH_TIMEOUT:-300}"' "$FRAMEWORK_ROOT/agents/handover/handover.sh")" -eq 0 ]
}
