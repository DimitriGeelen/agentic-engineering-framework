#!/usr/bin/env bats
# T-1884: CTL-026 section-gating regression — promoted from oe-daily-only to
# (compliance || oe-daily) so pre-push audit catches missing/regressed
# Human Sovereignty Gate in update-task.sh BEFORE the commit ships.
# Third twin of T-1882 (CTL-028 status-side) and T-1883 (CTL-012 AC-side).
#
# CTL-026 is a framework-source presence check (greps update-task.sh for
# the sovereignty-gate strings) — different detection class from CTL-028/CTL-012
# (which scan completed/), but same detection-window class (was: up to 24h
# via oe-daily cron).
#
# Tests verify:
#   1. CTL-026 fires when --section compliance (the new pre-push path)
#   2. CTL-026 still fires when --section oe-daily (no regression)
#   3. CTL-026 fires under pre-push profile (structure,compliance,quality,discovery)
#   4. CTL-026 does NOT fire under --section structure alone (gate granularity)

load ../test_helper

setup() {
    # No fixture corpus needed — CTL-026 reads the framework's own update-task.sh.
    # Tests run against the live FRAMEWORK_ROOT, so a clean repo emits PASS.
    TMPREPO=$(mktemp -d)
    export TMPREPO
    mkdir -p "$TMPREPO/.tasks/completed" "$TMPREPO/.tasks/active" \
             "$TMPREPO/.context/episodic" "$TMPREPO/docs/reports" \
             "$TMPREPO/.git"
}

teardown() {
    [ -d "${TMPREPO:-}" ] && rm -rf "$TMPREPO"
}

@test "CTL-026 T-1884: --section compliance fires CTL-026 (pre-push path)" {
    cd "$TMPREPO"
    run env PROJECT_ROOT="$TMPREPO" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section compliance 2>&1
    [[ "$output" == *"CTL-026"* ]]
}

@test "CTL-026 T-1884: --section oe-daily still fires CTL-026 (no regression)" {
    cd "$TMPREPO"
    run env PROJECT_ROOT="$TMPREPO" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section oe-daily 2>&1
    [[ "$output" == *"CTL-026"* ]]
}

@test "CTL-026 T-1884: pre-push profile (structure,compliance,quality,discovery) fires CTL-026" {
    cd "$TMPREPO"
    run env PROJECT_ROOT="$TMPREPO" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section structure,compliance,quality,discovery 2>&1
    [[ "$output" == *"CTL-026"* ]]
}

@test "CTL-026 T-1884: --section structure alone does NOT fire CTL-026 (gate granularity)" {
    # Mirrors T-1882/T-1883's gate-granularity test. Structure is intentionally
    # lean for fast pre-push; CTL-026 lives in compliance.
    cd "$TMPREPO"
    run env PROJECT_ROOT="$TMPREPO" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section structure 2>&1
    [[ "$output" != *"CTL-026"* ]]
}
