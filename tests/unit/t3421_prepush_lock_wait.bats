#!/usr/bin/env bats
# T-3421 — the pre-push audit-lock wait is derived from the measured audit.
#
# T-3297's 90s default expired before the ~292s structure audit it waited for
# could finish. `fw_prepush_lock_wait_default <root>` (lib/prepush-lock-wait.sh)
# reads the last measured `structure` seconds from the timing ledger and
# returns ceil(1.25x) clamped to [90, 600], or 360 with no usable ledger.
# Hermetic: every ledger here is a fixture under a tmpdir.

load ../test_helper

LIB="$FRAMEWORK_ROOT/lib/prepush-lock-wait.sh"

setup() {
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.context/audits"
}

teardown() {
    [ -d "${TEST_ROOT:-}" ] && rm -rf "$TEST_ROOT"
}

# ledger SECONDS — write a timing ledger in the shape audit.sh:_audit_write_timing_yaml emits.
ledger() {
    cat > "$TEST_ROOT/.context/audits/full-audit-timing.yaml" <<EOF
# Full-audit run timing - written by agents/audit/audit.sh (T-3127)
last_run:
  ts: "2026-09-22T06:00:00Z"
  total_seconds: 1449
  ceiling_seconds: 3000
  timed_out: true
  sections:
    - name: "tree"
      seconds: 325
    - name: "structure"
      seconds: $1
    - name: "compliance"
      seconds: 1
EOF
}

run_default() {
    run bash -c "source '$LIB'; fw_prepush_lock_wait_default '$TEST_ROOT'"
}

@test "measured 292s (today's ledger) -> 365 (ceil 1.25x)" {
    ledger 292
    run_default
    [ "$status" -eq 0 ]
    [ "$output" = "365" ]
}

@test "no ledger -> 360 fallback" {
    run_default
    [ "$status" -eq 0 ]
    [ "$output" = "360" ]
}

@test "tiny measurement is floored at T-3297's original 90" {
    ledger 10
    run_default
    [ "$output" = "90" ]
}

@test "runaway measurement is capped at 600 — the gate never becomes an indefinite hang" {
    ledger 1000
    run_default
    [ "$output" = "600" ]
}

@test "non-numeric structure entry -> 360 fallback, not an error" {
    ledger "n/a"
    run_default
    [ "$status" -eq 0 ]
    [ "$output" = "360" ]
}

@test "ledger without a structure entry -> 360 fallback (does not read another section's seconds)" {
    cat > "$TEST_ROOT/.context/audits/full-audit-timing.yaml" <<'EOF'
last_run:
  sections:
    - name: "tree"
      seconds: 325
EOF
    run_default
    [ "$output" = "360" ]
}

@test "hooks.sh resolves the default through the lib and honours an explicit FW_PREPUSH_LOCK_WAIT" {
    # Static pin on the hook source: the derivation is wired, the override is kept.
    grep -q 'fw_prepush_lock_wait_default "\$PROJECT_ROOT"' "$FRAMEWORK_ROOT/agents/git/lib/hooks.sh"
    grep -q 'if \[ -n "\${FW_PREPUSH_LOCK_WAIT:-}" \]; then' "$FRAMEWORK_ROOT/agents/git/lib/hooks.sh"
    # And the old asserted constant is gone from the default path.
    ! grep -q '_t3297_wait="\${FW_PREPUSH_LOCK_WAIT:-90}"' "$FRAMEWORK_ROOT/agents/git/lib/hooks.sh"
}
