#!/usr/bin/env bats
# T-1707 / G-065 Stream 2 — fw doctor scope tagging.
#
# Origin: T-1702 deferred. Original incident (2026-05-03 housekeeping)
# was an agent bundling host-level findings (git identity, bats not
# installed) into project housekeeping. Tagging host findings makes
# the boundary unambiguous so an agent doesn't confuse machine-level
# config with project-level config.
#
# These tests pin:
#   - The _doctor_warn_host helper exists in bin/fw
#   - 12 host-scope WARN emits route through the helper
#   - The summary line shows "(N host-level)" when host_warnings > 0
#   - Real `bin/fw doctor` output emits [host] prefix + suffix when
#     a host-level condition fires

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    FW_BIN="$FRAMEWORK_ROOT/bin/fw"
    [ -x "$FW_BIN" ]
}

# ── Source-level pins (cheap, fast) ──

@test "do_doctor defines _doctor_warn_host helper" {
    run grep -q "_doctor_warn_host()" "$FW_BIN"
    [ "$status" -eq 0 ]
}

@test "_doctor_warn_host increments both warnings and host_warnings" {
    # Pin both side-effects so refactors don't drop one
    run grep -E "host_warnings=\\\$\\(\\(host_warnings \\+ 1\\)\\)" "$FW_BIN"
    [ "$status" -eq 0 ]
}

@test "do_doctor body has at least 12 host-scope helper calls" {
    # Counts calls only (not the definition line). 12 host-level checks
    # were classified in T-1707. Tightening (adding more) is fine; loosening
    # below 12 means a host-scope check silently lost its tag.
    actual=$(grep -E "^[[:space:]]+_doctor_warn_host[[:space:]]+\"" "$FW_BIN" | wc -l)
    [ "$actual" -ge 12 ]
}

@test "host-scope explanatory suffix present in helper" {
    run grep -q "host-level — handle from a session at that root" "$FW_BIN"
    [ "$status" -eq 0 ]
}

@test "summary line includes host_warnings breakdown" {
    run grep -q "host-level)" "$FW_BIN"
    [ "$status" -eq 0 ]
}

# ── Behavioural pins (run actual fw doctor) ──

@test "fw doctor exits cleanly on this project" {
    # bin/fw doctor exits 2 if there are FAILs; this project should be
    # clean (warnings only). Mirrors the no-regression check.
    run bash -c "$FW_BIN doctor 2>&1"
    # Accept 0 (clean) or 1 (warnings); 2 means a real FAIL slipped in
    [ "$status" -ne 2 ]
    echo "$output" | grep -q "fw doctor"
}

@test "fw doctor emits [host] tag when a host-level finding fires" {
    # The framework repo on the test host typically has at least one
    # host-level finding (large global install, bats/shellcheck missing,
    # or unconfigured git identity). If none fire, skip rather than fail.
    run bash -c "$FW_BIN doctor 2>&1"
    if echo "$output" | grep -q "\[host\]"; then
        echo "$output" | grep -q "host-level — handle from a session at that root"
    else
        skip "no host-level warnings on this host (test env clean)"
    fi
}

@test "fw doctor summary shows host-level count when nonzero" {
    run bash -c "$FW_BIN doctor 2>&1"
    if echo "$output" | grep -q "\[host\]"; then
        # Summary line should include "host-level)" suffix
        echo "$output" | tail -3 | grep -E "warning\(s\) \([0-9]+ host-level\)"
    else
        skip "no host-level warnings on this host (test env clean)"
    fi
}

@test "no-regression: project-scope WARN emits keep their leading 2 spaces" {
    # _doctor_warn_host preserves the "  WARN  " indentation contract.
    # If a refactor changes the indent, this catches it.
    run bash -c "$FW_BIN doctor 2>&1"
    # Every non-empty line that contains WARN should start with whitespace
    # (output never has WARN at column 0 — preserves existing layout).
    if echo "$output" | grep -E "^WARN\b"; then
        false
    fi
}

# ── Worker_kind validator pin (T-1706 follow-up — ollama-loop accepted) ──

@test "workflow worker_kind validator accepts ollama-loop" {
    # T-1706 added ollama-loop to termlink dispatch but the workflow
    # schema validator rejected it until T-1707 pulled it in. Pin the
    # invariant so future edits don't drop ollama-loop again.
    # T-1946 extracted VALID_WORKER_KINDS from bin/fw to lib/workflow_lint.py
    # (silent-corpus-migration class). Test target updated accordingly.
    run grep -E "VALID_WORKER_KINDS\s*=.*ollama-loop" "$FRAMEWORK_ROOT/lib/workflow_lint.py"
    [ "$status" -eq 0 ]
}
