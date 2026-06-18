#!/usr/bin/env bats
# T-2247 / T-2436: audit self-vendor drift mitigation message scope.
#
# HISTORY: T-2247 asserted the libs-class mitigation point at full `fw vendor`
# because, at the time, `fw vendor self` (_self_vendor_libs) only synced
# .agentic-framework/lib/ — a subset of the libs-class scan (bin+lib+agents+web).
#
# T-2436 (OBS-076) CORRECTED that premise: since T-2264 (_self_vendor_shim →
# bin/fw), T-2266 (_self_vendor_agents → agents/), and T-2267 (_self_vendor_web →
# web/), `fw vendor self` runs ALL six helpers and therefore covers
# bin+lib+agents+web — the exact scope this check scans. The T-2247 recommendation
# (and its "only syncs lib/" comment) had been stale for three tasks. The
# mitigation now points at `fw vendor self` so the FAIL's fix command agrees with
# the canonical sync verb AND with `fw vendor self --check` (the read-only
# verifier added in T-2436).
#
# Templates class IS correctly scoped to `fw vendor self` (templates are
# a sibling of libs in _self_vendor_templates) and its message is
# unchanged.
#
# These are static-source assertions on agents/audit/audit.sh — the
# message text correctness is what's being pinned. Integration coverage
# (audit FAIL emits the right message under real drift) is provided by
# tests/unit/t2244_audit_self_vendor_drift.bats t2 (kept as slow
# end-to-end integration, runs in CI/cron, not in T-2247's close gate).
#
# Origin: T-2247 close-gate must run in seconds, not 12 minutes. T-2244
# t2 was rewritten in this commit to assert the new string; static
# pinning here catches authoring mistakes faster.

load ../test_helper

AUDIT_SCRIPT="$FRAMEWORK_ROOT/agents/audit/audit.sh"

@test "t2247/t2436 t1: audit.sh libs-class mitigation says 'fw vendor self' (now full-scope)" {
    [ -f "$AUDIT_SCRIPT" ] || skip "agents/audit/audit.sh missing"
    # T-2436: the libs-class fail block must point at 'fw vendor self' — which
    # since T-2264/T-2266/T-2267 covers bin+lib+agents+web (the libs-class scan
    # scope). Block boundaries: between 'libs class' fail line and the next
    # 'templates class' fail line. Capture the slice then grep.
    out=$(awk '/Self-vendor drift: libs class/,/Self-vendor drift: templates class/' "$AUDIT_SCRIPT")
    [ -n "$out" ] || { echo "libs-class block not found in audit.sh"; return 1; }
    # Positive: mitigation is 'fw vendor self' + names the read-only verifier.
    echo "$out" | grep -q '"Run: fw vendor self  (syncs all vendored .agentic-framework/ classes — verify with: fw vendor self --check)"' || { echo "$out"; return 1; }
    # Negative: mitigation must NOT be the bare full 'fw vendor' (heavier than needed).
    ! echo "$out" | grep -q '"Run: fw vendor  (sync all vendored .agentic-framework/ classes with source)"' || { echo "$out"; return 1; }
}

@test "t2247 t2: audit.sh templates-class mitigation unchanged ('fw vendor self')" {
    [ -f "$AUDIT_SCRIPT" ] || skip "agents/audit/audit.sh missing"
    # Templates class is correctly scoped to 'fw vendor self' (templates
    # are synced by _self_vendor_templates). Must stay as-is.
    out=$(awk '/Self-vendor drift: templates class/,/^check_self_vendor_drift$/' "$AUDIT_SCRIPT")
    [ -n "$out" ] || { echo "templates-class block not found in audit.sh"; return 1; }
    echo "$out" | grep -q '"Run: fw vendor self  (sync .agentic-framework/ templates with source)"' || { echo "$out"; return 1; }
}

@test "t2247/t2436 t3: explanatory comment records the corrected (no-longer-stale) scope" {
    [ -f "$AUDIT_SCRIPT" ] || skip "agents/audit/audit.sh missing"
    # T-2436: future maintainers need to understand that 'fw vendor self' now
    # covers the full libs-class scope (the T-2247 'lib-only' premise was stale
    # since T-2264/T-2266/T-2267). The comment above the libs FAIL must record
    # the correction.
    grep -q "T-2436" "$AUDIT_SCRIPT" || { echo "T-2436 reference missing from audit.sh"; return 1; }
    grep -q "runs all six helpers" "$AUDIT_SCRIPT" || { echo "corrected-scope explanation missing"; return 1; }
}
