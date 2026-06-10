#!/usr/bin/env bats
# T-2307 (T-2304 follow-on): `_self_vendor_libs` extended to recursive + `*.md` filter.
#
# Surfaces under test:
#   - lib/upgrade.sh:_self_vendor_libs() — now mirrors `_self_vendor_agents` shape
#     (T-2266+T-2304): while-read-find loop, *.sh + *.md filter, recursive
#     traversal with parent-dir mkdir at real-run, dry-run/real-run wording split.
#   - Audit's libs-class drift scanner (agents/audit/audit.sh:1644) already scans
#     `*.sh + *.md` — this test pins the helper-SYNC side of the leg.
#
# Sibling: tests/unit/test_self_vendor_agents_md_filter.bats (T-2304) pins the
# same leg for `_self_vendor_agents`. Both helpers share the same shape; both
# tests use the same fixture pattern (synthetic FRAMEWORK_ROOT with drift in
# the relevant subtree).
#
# AC mapping (per .tasks/active/T-2307-*.md):
#   .md drift surfaces in dry-run                 — t1
#   real-run syncs .md files recursively          — t2
#   .sh path still works (no regression)          — t3
#   clean state — no spurious "would sync"        — t4

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t2307-XXXXXX)"
    export FRAMEWORK_ROOT
    export FW_VERSION="1.6.171"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build a synthetic framework tree with subdirs holding *.sh + *.md:
#   lib/foo.sh                            same                            (skip)
#   lib/templates/changed.md              differs from vendored           (sync)
#   lib/templates/skills/new.md           missing in vendored             (sync)
#   lib/extra/ignored.txt                 filter excludes                  (never sync)
make_synthetic_fw_with_libs_md_diff() {
    local syn_fw="$TEST_TEMP_DIR/syn-fw-libs-md"
    mkdir -p "$syn_fw/lib/templates" "$syn_fw/lib/templates/skills" "$syn_fw/lib/extra"
    mkdir -p "$syn_fw/.agentic-framework/lib/templates"
    # same — should be skipped
    echo "echo same" > "$syn_fw/lib/foo.sh"
    echo "echo same" > "$syn_fw/.agentic-framework/lib/foo.sh"
    # changed .md — should sync
    echo "# new content" > "$syn_fw/lib/templates/changed.md"
    echo "# old content" > "$syn_fw/.agentic-framework/lib/templates/changed.md"
    # new .md in deeper subdir — should sync (recursive auto-mkdir)
    echo "# new file" > "$syn_fw/lib/templates/skills/new.md"
    # excluded — filter is *.sh + *.md (T-2307); .txt is out of scope
    echo "plain text" > "$syn_fw/lib/extra/ignored.txt"
    echo "$syn_fw"
}

# ─────────────────────────────────────────────────────────────────────────
# Dry-run surfaces .md drift
# ─────────────────────────────────────────────────────────────────────────

@test "t2307 t1: helper dry-run reports 'would sync N file(s) to .agentic-framework/lib/' including .md drift" {
    local syn_fw
    syn_fw=$(make_synthetic_fw_with_libs_md_diff)
    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$syn_fw"
    run _self_vendor_libs "true"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    # 2 files would sync: templates/changed.md (diff) + templates/skills/new.md (missing)
    # foo.sh same → skipped; extra/ignored.txt out of scope
    [[ "$output" == *"would sync 2 file(s) to .agentic-framework/lib/"* ]]
    # Dry-run must NOT print real-run verb
    [[ "$output" != *"Self-vendor:"*" synced 2 file(s) to .agentic-framework/lib/"* ]]
    # Dry-run: vendored copy NOT mutated
    diff -q "$syn_fw/.agentic-framework/lib/templates/changed.md" "$syn_fw/lib/templates/changed.md" >/dev/null 2>&1 && exit 1
    [ ! -f "$syn_fw/.agentic-framework/lib/templates/skills/new.md" ]
}

# ─────────────────────────────────────────────────────────────────────────
# Real-run syncs .md recursively with parent mkdir
# ─────────────────────────────────────────────────────────────────────────

@test "t2307 t2: helper real-run syncs .md files recursively with parent-dir auto-mkdir" {
    local syn_fw
    syn_fw=$(make_synthetic_fw_with_libs_md_diff)
    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$syn_fw"
    run _self_vendor_libs "false"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    [[ "$output" == *"synced 2 file(s) to .agentic-framework/lib/"* ]]
    # changed.md now matches the source
    diff -q "$syn_fw/lib/templates/changed.md" "$syn_fw/.agentic-framework/lib/templates/changed.md"
    # new.md was created in a missing subdir (recursive auto-mkdir)
    [ -f "$syn_fw/.agentic-framework/lib/templates/skills/new.md" ]
    diff -q "$syn_fw/lib/templates/skills/new.md" "$syn_fw/.agentic-framework/lib/templates/skills/new.md"
    # ignored.txt NOT mirrored (filter excludes)
    [ ! -f "$syn_fw/.agentic-framework/lib/extra/ignored.txt" ]
}

# ─────────────────────────────────────────────────────────────────────────
# .sh path regression check (the prior shape was *.sh-only; this must still work)
# ─────────────────────────────────────────────────────────────────────────

@test "t2307 t3: .sh drift still syncs (no regression from non-recursive → recursive change)" {
    local syn_fw="$TEST_TEMP_DIR/syn-fw-sh-only"
    mkdir -p "$syn_fw/lib" "$syn_fw/.agentic-framework/lib"
    # Drifted .sh at lib/ root (the old shape)
    echo "echo new" > "$syn_fw/lib/changed.sh"
    echo "echo old" > "$syn_fw/.agentic-framework/lib/changed.sh"
    # Drifted .sh in subdir (new shape — non-recursive would have missed this)
    mkdir -p "$syn_fw/lib/subdir" "$syn_fw/.agentic-framework/lib/subdir"
    echo "echo subdir-new" > "$syn_fw/lib/subdir/nested.sh"
    echo "echo subdir-old" > "$syn_fw/.agentic-framework/lib/subdir/nested.sh"

    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$syn_fw"
    run _self_vendor_libs "false"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    [[ "$output" == *"synced 2 file(s) to .agentic-framework/lib/"* ]]
    diff -q "$syn_fw/lib/changed.sh" "$syn_fw/.agentic-framework/lib/changed.sh"
    diff -q "$syn_fw/lib/subdir/nested.sh" "$syn_fw/.agentic-framework/lib/subdir/nested.sh"
}

# ─────────────────────────────────────────────────────────────────────────
# Clean state — no spurious output
# ─────────────────────────────────────────────────────────────────────────

@test "t2307 t4: clean state (no drift) — helper emits no 'would sync' / 'synced' line" {
    local syn_fw="$TEST_TEMP_DIR/syn-fw-clean"
    mkdir -p "$syn_fw/lib/templates" "$syn_fw/.agentic-framework/lib/templates"
    # Source and vendored identical
    echo "echo same" > "$syn_fw/lib/foo.sh"
    echo "echo same" > "$syn_fw/.agentic-framework/lib/foo.sh"
    echo "# same" > "$syn_fw/lib/templates/x.md"
    echo "# same" > "$syn_fw/.agentic-framework/lib/templates/x.md"

    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$syn_fw"
    run _self_vendor_libs "true"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    [[ "$output" != *"would sync"* ]]
    [[ "$output" != *"Self-vendor:"*" synced"* ]]
}
