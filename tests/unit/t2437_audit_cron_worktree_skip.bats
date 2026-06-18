#!/usr/bin/env bats
# T-2437 (OBS-077 keystone): worktree audit content-vs-environment classification.
#
# T-2435 worktree-skipped the cron REGISTRY drift block but missed the sibling
# cron-misload LINT block (T-1722), which also reads /etc/cron.d/ for an install
# under the worktree slug that never exists → latent false-FAIL the moment any
# non-agentic-audit USER-field crontab lands in .context/cron/. T-2437 brings the
# lint block under the same guard and codifies the keystone:
#
#   A pre-push/audit check may FAIL in a linked worktree ONLY when it measures
#   committed CONTENT drift (self-vendor, fabric, task YAML, secrets). Checks that
#   measure HOST/working-copy ENVIRONMENT state (cron install at /etc/cron.d/) are
#   INFO-skipped — managed from the main checkout, absent-in-worktree is expected.
#
# Static-source assertions on agents/audit/audit.sh (sibling style to
# t2247_audit_self_vendor_mitigation.bats). The discriminator fw_is_linked_worktree
# itself is behaviourally covered by tests/unit/lib_paths.bats (T-2435).

load ../test_helper

AUDIT_SCRIPT="$FRAMEWORK_ROOT/agents/audit/audit.sh"

@test "t2437 t1: cron REGISTRY drift block is worktree-guarded (T-2435 regression guard)" {
    [ -f "$AUDIT_SCRIPT" ] || skip "agents/audit/audit.sh missing"
    # The registry-block opener must AND-guard on the linked-worktree discriminator.
    grep -qE '^if \[ -f "\$_cron_registry" \] && fw_is_linked_worktree "\$PROJECT_ROOT"; then' "$AUDIT_SCRIPT"
}

@test "t2437 t2: cron-misload LINT block is worktree-guarded (the T-2437 fix)" {
    [ -f "$AUDIT_SCRIPT" ] || skip "agents/audit/audit.sh missing"
    # The misload-lint opener (previously unconditional) must now AND-guard too.
    grep -qE '^if \[ -d "\$_cron_lint_dir" \] && fw_is_linked_worktree "\$PROJECT_ROOT"; then' "$AUDIT_SCRIPT"
    # And it must emit an INFO skip (counts as PASS), not run the FAIL-bearing loop.
    out=$(awk '/_cron_lint_dir="\$PROJECT_ROOT\/.context\/cron"/,/^# T-1631/' "$AUDIT_SCRIPT")
    echo "$out" | grep -q 'Cron-misload lint skipped — linked worktree' || { echo "$out"; return 1; }
}

@test "t2437 t3: self-vendor (CONTENT) is NOT worktree-skipped — stays a FAIL" {
    [ -f "$AUDIT_SCRIPT" ] || skip "agents/audit/audit.sh missing"
    # The classification keystone: content drift must NOT be suppressed in a
    # worktree, or real un-vendored drift would ship. check_self_vendor_drift()
    # must contain zero linked-worktree skips.
    out=$(awk '/^check_self_vendor_drift\(\) \{/,/^}/' "$AUDIT_SCRIPT")
    [ -n "$out" ] || { echo "check_self_vendor_drift not found"; return 1; }
    ! echo "$out" | grep -q 'fw_is_linked_worktree' || { echo "self-vendor MUST NOT worktree-skip (content drift)"; echo "$out"; return 1; }
}

@test "t2437 t4: the content-vs-environment keystone is documented in-source" {
    [ -f "$AUDIT_SCRIPT" ] || skip "agents/audit/audit.sh missing"
    grep -q "content-vs-environment classification" "$AUDIT_SCRIPT" || { echo "keystone comment missing"; return 1; }
    grep -q "T-2437" "$AUDIT_SCRIPT" || { echo "T-2437 reference missing"; return 1; }
}
