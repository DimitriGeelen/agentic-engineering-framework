#!/usr/bin/env bats
# T-2455 (OBS-085): `_self_vendor_libs` must include `*.py` in its find filter.
#
# Bug: the libs helper synced `*.sh + *.md` only, but the audit's libs-class
# drift scanner (agents/audit/audit.sh:check_self_vendor_drift) scans
# `*.sh + *.py + fw + *.md`. Every `lib/**/*.py` (40 files incl.
# lib/reviewer/static_scan.py, the govd_*.py fabric, lib/integrate.py) was
# therefore un-vendorable: when source `.py` drifted, the audit FAILed but
# `fw vendor self` could NOT clear it (the helper never touched .py) → all
# pushes blocked by an unresolvable pre-push audit FAIL.
# Origin: T-2449 edited lib/reviewer/static_scan.py; the vendored copy stayed
# stale and surfaced as a permanent self-vendor drift FAIL the next push.
#
# Sibling: tests/unit/test_self_vendor_libs_md_filter.bats (T-2307) pins the
# `.md` leg of the same helper; this file pins the `.py` leg using the same
# synthetic-FRAMEWORK_ROOT fixture pattern.
#
# AC mapping (per .tasks/active/T-2455-*.md):
#   real-run syncs a drifted .py in a subdir + creates a missing .py     — t1
#   dry-run surfaces .py drift without mutating                          — t2
#   source-parity: helper filter includes *.py, matching the audit       — t3
#   clean state — no spurious "would sync" with a .py present            — t4

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t2455-XXXXXX)"
    export FRAMEWORK_ROOT
    export FW_VERSION="1.6.171"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build a synthetic framework tree with *.py drift (mirrors the real bug shape):
#   lib/foo.sh                              same                          (skip)
#   lib/reviewer/scan.py                    differs from vendored         (sync)
#   lib/govd_new.py                         missing in vendored           (sync)
#   lib/extra/ignored.txt                   filter excludes               (never sync)
make_synthetic_fw_with_libs_py_diff() {
    local syn_fw="$TEST_TEMP_DIR/syn-fw-libs-py"
    mkdir -p "$syn_fw/lib/reviewer" "$syn_fw/lib/extra"
    mkdir -p "$syn_fw/.agentic-framework/lib/reviewer"
    # same .sh — should be skipped
    echo "echo same" > "$syn_fw/lib/foo.sh"
    echo "echo same" > "$syn_fw/.agentic-framework/lib/foo.sh"
    # changed .py in a subdir (the static_scan.py class) — should sync
    echo "print('new')" > "$syn_fw/lib/reviewer/scan.py"
    echo "print('old')" > "$syn_fw/.agentic-framework/lib/reviewer/scan.py"
    # new .py missing in vendored at lib/ root — should sync
    echo "print('fabric')" > "$syn_fw/lib/govd_new.py"
    # excluded — filter is *.sh + *.py + *.md; .txt is out of scope
    echo "plain text" > "$syn_fw/lib/extra/ignored.txt"
    echo "$syn_fw"
}

# ─────────────────────────────────────────────────────────────────────────
# Real-run syncs .py recursively (the regression fix)
# ─────────────────────────────────────────────────────────────────────────

@test "t2455 t1: helper real-run syncs drifted .py in subdir + creates missing .py" {
    local syn_fw
    syn_fw=$(make_synthetic_fw_with_libs_py_diff)
    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$syn_fw"
    run _self_vendor_libs "false"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    # 2 files sync: reviewer/scan.py (diff) + govd_new.py (missing)
    # foo.sh same → skipped; extra/ignored.txt out of scope
    [[ "$output" == *"synced 2 file(s) to .agentic-framework/lib/"* ]]
    # drifted .py now matches source
    diff -q "$syn_fw/lib/reviewer/scan.py" "$syn_fw/.agentic-framework/lib/reviewer/scan.py"
    # missing .py was created
    [ -f "$syn_fw/.agentic-framework/lib/govd_new.py" ]
    diff -q "$syn_fw/lib/govd_new.py" "$syn_fw/.agentic-framework/lib/govd_new.py"
    # ignored.txt NOT mirrored (filter excludes)
    [ ! -f "$syn_fw/.agentic-framework/lib/extra/ignored.txt" ]
}

# ─────────────────────────────────────────────────────────────────────────
# Dry-run surfaces .py drift without mutating
# ─────────────────────────────────────────────────────────────────────────

@test "t2455 t2: helper dry-run reports .py drift and does NOT mutate vendored" {
    local syn_fw
    syn_fw=$(make_synthetic_fw_with_libs_py_diff)
    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$syn_fw"
    run _self_vendor_libs "true"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    [[ "$output" == *"would sync 2 file(s) to .agentic-framework/lib/"* ]]
    # Dry-run must NOT print real-run verb
    [[ "$output" != *"Self-vendor:"*" synced 2 file(s) to .agentic-framework/lib/"* ]]
    # vendored copy NOT mutated
    diff -q "$syn_fw/.agentic-framework/lib/reviewer/scan.py" "$syn_fw/lib/reviewer/scan.py" >/dev/null 2>&1 && exit 1
    [ ! -f "$syn_fw/.agentic-framework/lib/govd_new.py" ]
}

# ─────────────────────────────────────────────────────────────────────────
# Source-parity pin — the structural guard against re-divergence
# ─────────────────────────────────────────────────────────────────────────

@test "t2455 t3: _self_vendor_libs find filter includes *.py (parity with audit scan set)" {
    # Extract the find line in _self_vendor_libs that traverses lib/ and assert
    # it filters on *.py. This is the exact line that the bug omitted.
    run grep -E 'find "\$FRAMEWORK_ROOT/lib".*-name "\*\.py"' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    [ "$status" -eq 0 ]
    # And the audit's drift scanner must also include *.py (the parity target).
    run grep -E '\.agentic-framework/lib".*-name "\*\.py"' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ "$status" -eq 0 ]
}

# ─────────────────────────────────────────────────────────────────────────
# Clean state — no spurious output (with a .py present)
# ─────────────────────────────────────────────────────────────────────────

@test "t2455 t4: clean state (.py in sync) — helper emits no 'would sync' line" {
    local syn_fw="$TEST_TEMP_DIR/syn-fw-clean-py"
    mkdir -p "$syn_fw/lib/reviewer" "$syn_fw/.agentic-framework/lib/reviewer"
    echo "echo same" > "$syn_fw/lib/foo.sh"
    echo "echo same" > "$syn_fw/.agentic-framework/lib/foo.sh"
    echo "print('same')" > "$syn_fw/lib/reviewer/scan.py"
    echo "print('same')" > "$syn_fw/.agentic-framework/lib/reviewer/scan.py"

    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$syn_fw"
    run _self_vendor_libs "true"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    [[ "$output" != *"would sync"* ]]
    [[ "$output" != *"Self-vendor:"*" synced"* ]]
}
