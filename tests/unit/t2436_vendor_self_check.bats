#!/usr/bin/env bats
# T-2436 (OBS-076): `fw vendor self --check` is a READ-ONLY drift verifier.
#
# Before T-2436 the `--check` flag was silently accepted by the `vendor self`
# routing in bin/fw but matched neither `--dry-run` nor a real flag, so it fell
# through to a REAL mutating sync that exited 0. A caller running
# `fw vendor self --check` expecting verification actually MUTATED the vendored
# .agentic-framework/ tree and saw a misleading "clean" (exit 0) — the drift was
# just made clean, never committed. That silent-mutation trap is the OBS-076
# "audit and `vendor self --check` disagree".
#
# Fix: `--check` runs every helper in dry-run mode (never mutates) and EXITS
# NON-ZERO when any class is out of sync — the form that AGREES with audit's
# check_self_vendor_drift and with the pre-push gate's `--dry-run` grep.
#
# Surfaces under test: bin/fw `vendor self` routing block.
#   --check maps to dry-run+check, not a real sync   — t1 (static)
#   --check exits 1 on drift / 0 in sync (logic)     — t2 (static)
#   --check NEVER mutates the vendored tree           — t3 (behavioral)
#   --check exit code agrees with --dry-run state     — t4 (behavioral)
#   --help documents --check                          — t5

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

# ─────────────────────────────────────────────────────────────────────────
# Static — routing wires --check to dry-run+check, not a mutating sync
# ─────────────────────────────────────────────────────────────────────────

@test "t2436 t1: bin/fw maps --check to dry-run + check (not a real sync)" {
    [ -f "$FRAMEWORK_ROOT/bin/fw" ] || skip "bin/fw missing"
    # The case branch must set BOTH _vs_dry=true (read-only) AND _vs_check=true.
    grep -qE -- '--check\)[[:space:]]*_vs_dry=true;[[:space:]]*_vs_check=true' "$FRAMEWORK_ROOT/bin/fw"
}

@test "t2436 t2: bin/fw --check exits non-zero on drift, zero in sync" {
    [ -f "$FRAMEWORK_ROOT/bin/fw" ] || skip "bin/fw missing"
    # Slice the vendor-self check block and assert the exit-code logic.
    out=$(awk '/_vs_check=false/,/exit 0$/' "$FRAMEWORK_ROOT/bin/fw")
    [ -n "$out" ] || { echo "vendor self check block not found"; return 1; }
    # Drift path: grep "would sync" → exit 1.
    echo "$out" | grep -q 'would sync' || { echo "$out"; return 1; }
    echo "$out" | grep -qE 'exit 1' || { echo "$out"; return 1; }
    # In-sync path: emit "in sync" and exit 0.
    echo "$out" | grep -q 'in sync with source' || { echo "$out"; return 1; }
}

# ─────────────────────────────────────────────────────────────────────────
# Behavioral — read-only contract holds against the live tree
# ─────────────────────────────────────────────────────────────────────────

@test "t2436 t3: --check never mutates the vendored .agentic-framework/ tree" {
    [ -x "$FW" ] || skip "bin/fw not executable"
    git -C "$FRAMEWORK_ROOT" rev-parse --git-dir >/dev/null 2>&1 || skip "not a git repo"
    local before after
    before=$(git -C "$FRAMEWORK_ROOT" status --porcelain -- .agentic-framework | sort)
    run "$FW" vendor self --check
    # read-only verifier: clean → 0, drift → 1; never a crash/other code.
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
    after=$(git -C "$FRAMEWORK_ROOT" status --porcelain -- .agentic-framework | sort)
    [ "$before" = "$after" ] || { echo "MUTATION: --check changed the vendored tree"; echo "before:[$before]"; echo "after:[$after]"; return 1; }
}

@test "t2436 t4: --check exit code agrees with --dry-run drift state" {
    [ -x "$FW" ] || skip "bin/fw not executable"
    run "$FW" vendor self --check
    local check_status=$status
    run "$FW" vendor self --dry-run
    if echo "$output" | grep -q "would sync"; then
        # drift present → --check must have failed
        [ "$check_status" -ne 0 ]
    else
        # in sync → --check must have passed
        [ "$check_status" -eq 0 ]
    fi
}

# ─────────────────────────────────────────────────────────────────────────
# Discoverability
# ─────────────────────────────────────────────────────────────────────────

@test "t2436 t5: fw vendor self --help documents the --check verifier" {
    run "$FW" vendor self --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--check"* ]]
    [[ "$output" == *"read-only"* ]]
    [[ "$output" == *"T-2436"* ]]
}
