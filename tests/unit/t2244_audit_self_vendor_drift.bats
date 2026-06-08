#!/usr/bin/env bats
# T-2244: audit self-vendor drift FAIL (F2 N×M daily-cron backstop).
# Mirror of t2243 (doctor leg) but at the audit surface — daily cron
# catches anything that slipped past the developer-facing gates.
#
# Audit's structure section runs the new `check_self_vendor_drift`.
# Tests mutate the vendored copy, run audit --section structure --quiet,
# and assert the FAIL line names the affected class.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    TPL_SENTINEL="$FRAMEWORK_ROOT/.agentic-framework/.tasks/templates/default.md"
    LIBS_SENTINEL="$FRAMEWORK_ROOT/.agentic-framework/lib/upgrade.sh"
    [ -f "$TPL_SENTINEL" ] || skip ".agentic-framework/.tasks/templates/default.md missing"
    [ -f "$LIBS_SENTINEL" ] || skip ".agentic-framework/lib/upgrade.sh missing"
    TPL_BACKUP="$TEST_TEMP_DIR/default.md.orig"
    LIBS_BACKUP="$TEST_TEMP_DIR/upgrade.sh.orig"
    cp "$TPL_SENTINEL" "$TPL_BACKUP"
    cp "$LIBS_SENTINEL" "$LIBS_BACKUP"
}

teardown() {
    [ -f "$TPL_BACKUP" ] && cp "$TPL_BACKUP" "$TPL_SENTINEL"
    [ -f "$LIBS_BACKUP" ] && cp "$LIBS_BACKUP" "$LIBS_SENTINEL"
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "t2244 t2: libs-only drift → FAIL line names libs class" {
    # Mutate the vendored libs sentinel (upgrade.sh).
    echo "# T-2244 audit libs drift sentinel" >> "$LIBS_SENTINEL"
    # audit exits 2 on failures (which is the path we're testing). Capture
    # both stdout/stderr and let exit-2 land via `|| true` so bats `set -e`
    # doesn't kill the line ([[feedback_bats_set_e_rc_capture]]).
    # NO --quiet — that suppresses the FAIL output our assertions need.
    out=$(cd "$FRAMEWORK_ROOT" && bin/fw audit --section structure 2>&1 || true)
    # Audit exit code 2 = failures. We expect FAIL line for libs.
    [[ "$out" == *"Self-vendor drift: libs class"* ]] || { echo "$out" | tail -50; return 1; }
    [[ "$out" == *"upgrade.sh"* ]] || { echo "$out" | tail -50; return 1; }
    # T-2247: libs class scans bin+lib+agents+web; 'fw vendor self' only syncs
    # lib/. Mitigation must point at full 'fw vendor' (always-works superset).
    [[ "$out" == *"Run: fw vendor "* ]] || { echo "$out" | tail -50; return 1; }
    [[ "$out" != *"Run: fw vendor self"* ]] || { echo "$out" | tail -50; return 1; }
}

@test "t2244 t3: templates-only drift → FAIL line names templates class" {
    # Mutate vendored template.
    echo "<!-- T-2244 audit templates drift sentinel -->" >> "$TPL_SENTINEL"
    # audit exits 2 on failures (which is the path we're testing). Capture
    # both stdout/stderr and let exit-2 land via `|| true` so bats `set -e`
    # doesn't kill the line ([[feedback_bats_set_e_rc_capture]]).
    # NO --quiet — that suppresses the FAIL output our assertions need.
    out=$(cd "$FRAMEWORK_ROOT" && bin/fw audit --section structure 2>&1 || true)
    [[ "$out" == *"Self-vendor drift: templates class"* ]] || { echo "$out" | tail -50; return 1; }
    [[ "$out" == *".tasks/templates/default.md"* ]] || { echo "$out" | tail -50; return 1; }
    [[ "$out" == *"fw vendor self"* ]] || { echo "$out" | tail -50; return 1; }
}
