#!/usr/bin/env bats
# T-2247: audit self-vendor drift mitigation message scope.
#
# `check_self_vendor_drift()` libs class scans
# .agentic-framework/{bin,lib,agents,web} but `fw vendor self`
# (_self_vendor_libs in lib/upgrade.sh) only syncs .agentic-framework/lib/.
# Mitigation must point at full `fw vendor` (always-works superset),
# NOT `fw vendor self` (under-scoped subset).
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

@test "t2247 t1: audit.sh libs-class mitigation says 'fw vendor' (full)" {
    [ -f "$AUDIT_SCRIPT" ] || skip "agents/audit/audit.sh missing"
    # The libs-class fail block in check_self_vendor_drift() must point
    # at full 'fw vendor', not 'fw vendor self' (which only syncs lib/).
    # Block boundaries: between 'libs class' fail line and the next
    # 'templates class' fail line. Capture the slice then grep.
    out=$(awk '/Self-vendor drift: libs class/,/Self-vendor drift: templates class/' "$AUDIT_SCRIPT")
    [ -n "$out" ] || { echo "libs-class block not found in audit.sh"; return 1; }
    # Positive: mitigation is the full-scope verb.
    echo "$out" | grep -q '"Run: fw vendor  (sync all vendored .agentic-framework/ classes with source)"' || { echo "$out"; return 1; }
    # Negative: mitigation must NOT be the under-scoped 'fw vendor self'.
    ! echo "$out" | grep -q '"Run: fw vendor self  (sync .agentic-framework/ libs with source)"' || { echo "$out"; return 1; }
}

@test "t2247 t2: audit.sh templates-class mitigation unchanged ('fw vendor self')" {
    [ -f "$AUDIT_SCRIPT" ] || skip "agents/audit/audit.sh missing"
    # Templates class is correctly scoped to 'fw vendor self' (templates
    # are synced by _self_vendor_templates). Must stay as-is.
    out=$(awk '/Self-vendor drift: templates class/,/^check_self_vendor_drift$/' "$AUDIT_SCRIPT")
    [ -n "$out" ] || { echo "templates-class block not found in audit.sh"; return 1; }
    echo "$out" | grep -q '"Run: fw vendor self  (sync .agentic-framework/ templates with source)"' || { echo "$out"; return 1; }
}

@test "t2247 t3: explanatory comments name the scope mismatch" {
    [ -f "$AUDIT_SCRIPT" ] || skip "agents/audit/audit.sh missing"
    # Future maintainers need to understand why libs uses 'fw vendor' but
    # templates uses 'fw vendor self'. The comment above the libs FAIL
    # must explain the scope mismatch (T-2247 fix rationale).
    grep -q "T-2247" "$AUDIT_SCRIPT" || { echo "T-2247 reference missing from audit.sh"; return 1; }
    grep -q "only syncs .agentic-framework/lib/" "$AUDIT_SCRIPT" || { echo "scope-mismatch explanation missing"; return 1; }
}
