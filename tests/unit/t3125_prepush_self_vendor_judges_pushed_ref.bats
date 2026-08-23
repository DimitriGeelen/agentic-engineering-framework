#!/usr/bin/env bats
# T-3125: the self-vendor pre-push gate must judge the tree being PUSHED, not
# the working tree.
#
# Origin (observed live 2026-08-23): `fw vendor self --dry-run` compares
# WORKING-TREE source against WORKING-TREE vendored copies, but the property
# the T-2240 gate protects — "consumers that vendor from origin/master inherit
# the stale lib/ silently" — is about the PUSHED REF. A concurrent session's
# uncommitted bin/fw and agents/audit/audit.sh held 19 commits for hours; for
# both files `git show HEAD:<src>` was byte-identical to the vendored blob, so
# the ref being pushed was clean and the block was false. Cost: two Tier-0
# approvals.
#
# The four states this pins:
#   (a) clean                       → push allowed, no WARN, no block
#   (b) committed drift             → BLOCKED (T-2240 protection survives)
#   (c) working-tree-only drift     → allowed + WARN naming the class
#   (d) committed + working-tree    → BLOCKED (committed staleness dominates)
#
# L-599: the fixture is a synthetic repo built in a tmp dir. Nothing here reads
# the framework checkout's own git state, and the hook under test is GENERATED
# from agents/git/lib/hooks.sh into the fixture — so a mutation of the source
# is what this suite measures, not whatever happens to sit in .git/hooks.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_REPO="$(mktemp -d -t fw-t3125-XXXXXX)"
    cd "$TMP_REPO"
    git init -q
    git config user.email "t3125@local"
    git config user.name "T-3125 fixture"
    git config commit.gpgsign false

    # --- source tree: one file per vendored class the gate mirrors ----------
    mkdir -p agents/audit lib bin
    cat > agents/audit/audit.sh <<'STUB'
#!/bin/bash
exit 0
STUB
    chmod +x agents/audit/audit.sh
    echo "# lib payload v1" > lib/thing.sh
    _install_fw_stub

    # --- vendored copies, byte-identical → committed tree starts IN SYNC ----
    mkdir -p .agentic-framework/lib .agentic-framework/agents/audit .agentic-framework/bin
    cp lib/thing.sh .agentic-framework/lib/thing.sh
    cp agents/audit/audit.sh .agentic-framework/agents/audit/audit.sh
    cp bin/fw .agentic-framework/bin/fw

    echo "1.0.0" > VERSION
    git add -A
    git commit -q -m "T-3125: fixture init"
    REMOTE_SHA="$(git rev-parse HEAD)"

    # Generate the hook from the SOURCE under test into the fixture.
    PROJECT_ROOT="$TMP_REPO" bash "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks >/dev/null 2>&1
    [ -x .git/hooks/pre-push ]

    BRANCH="$(git rev-parse --abbrev-ref HEAD)"
    export REMOTE_SHA BRANCH
}

teardown() {
    cd /
    [ -n "${TMP_REPO:-}" ] && rm -rf "$TMP_REPO"
    return 0
}

# Stub fw: only `vendor self --dry-run` matters. FW_STUB_DRIFT=1 makes the
# DETECTOR fire, exactly as the real dry-run does when the working tree
# diverges. Everything else exits 0 so the hook's other steps pass.
_install_fw_stub() {
    cat > "$TMP_REPO/bin/fw" <<'STUB'
#!/bin/bash
case "$1" in
    vendor)
        shift
        if [ "$1" = "self" ]; then
            if [ "${FW_STUB_DRIFT:-0}" = "1" ]; then
                echo "  Self-vendor: would sync 1 file(s) to .agentic-framework/lib/"
            fi
            exit 0
        fi
        ;;
esac
exit 0
STUB
    chmod +x "$TMP_REPO/bin/fw"
}

# Commit a source change WITHOUT refreshing the vendored copy → the pushed ref
# is genuinely stale. This is the state T-2240 exists to block.
_commit_drift() {
    echo "# lib payload v2 (committed, vendored copy NOT refreshed)" > lib/thing.sh
    git add lib/thing.sh
    git commit -q -m "T-3125: source edit without vendor refresh"
}

# Dirty the working tree only. Nothing is committed, so the pushed ref stays
# byte-identical to its vendored copies — this is the false-positive shape.
_dirty_worktree() {
    echo "# uncommitted edit by a concurrent session" >> lib/thing.sh
}

_run_push_hook() {
    local sha; sha="$(git rev-parse HEAD)"
    run bash -c "echo 'refs/heads/$BRANCH $sha refs/heads/$BRANCH $REMOTE_SHA' \
        | FW_STUB_DRIFT=${FW_STUB_DRIFT:-0} .git/hooks/pre-push origin http://localhost"
}

# ── (a) clean ────────────────────────────────────────────────────────────────

@test "t3125 (a) clean tree → push allowed, no WARN, no block" {
    FW_STUB_DRIFT=0 _run_push_hook
    [ "$status" -eq 0 ]
    [[ "$output" != *"self-vendor drift detected"* ]]
    [[ "$output" != *"working-tree-only"* ]]
}

# ── (b) committed drift ──────────────────────────────────────────────────────

@test "t3125 (b) committed drift → push BLOCKED (T-2240 protection survives)" {
    _commit_drift
    FW_STUB_DRIFT=1 _run_push_hook
    [ "$status" -eq 1 ]
    [[ "$output" == *"self-vendor drift detected"* ]]
    # Names the committed-stale path, not just the class count
    [[ "$output" == *"lib/thing.sh"* ]]
    # Both bypass mechanisms still named (L-399 parity)
    [[ "$output" == *"FW_SKIP_SELF_VENDOR_CHECK=1"* ]]
    [[ "$output" == *"--no-verify"* ]]
}

# ── (c) working-tree-only drift — THE DEFECT ─────────────────────────────────

@test "t3125 (c) working-tree-only drift → push ALLOWED with WARN" {
    _dirty_worktree
    FW_STUB_DRIFT=1 _run_push_hook
    [ "$status" -eq 0 ]
    [[ "$output" != *"Push blocked"* ]]
    [[ "$output" == *"WARN"* ]]
    [[ "$output" == *"working-tree-only"* ]]
    # The WARN must name the affected class and say the pushed ref is clean
    [[ "$output" == *".agentic-framework/lib/"* ]]
    [[ "$output" == *"IN SYNC"* ]]
}

@test "t3125 (c2) a concurrent session's uncommitted bin/ + agents/ edits do not block" {
    # The literal 2026-08-23 shape: another session dirties bin/fw and
    # agents/audit/audit.sh; this session pushes a clean ref.
    echo "# concurrent edit" >> bin/fw
    echo "# concurrent edit" >> agents/audit/audit.sh
    FW_STUB_DRIFT=1 _run_push_hook
    [ "$status" -eq 0 ]
    [[ "$output" == *"working-tree-only"* ]]
}

# ── (d) both ─────────────────────────────────────────────────────────────────

@test "t3125 (d) committed AND working-tree drift → BLOCKED (committed dominates)" {
    _commit_drift
    _dirty_worktree
    FW_STUB_DRIFT=1 _run_push_hook
    [ "$status" -eq 1 ]
    [[ "$output" == *"self-vendor drift detected"* ]]
    [[ "$output" != *"working-tree-only"* ]]
}

# ── vendored file absent from the ref is drift too ───────────────────────────

@test "t3125 (b2) new source file never vendored → BLOCKED" {
    # Walking only the vendored tree would miss this: the source exists, the
    # vendored counterpart does not, and vendor-self syncs on missing-dest.
    echo "# brand new" > lib/newthing.sh
    git add lib/newthing.sh
    git commit -q -m "T-3125: new lib file, never vendored"
    FW_STUB_DRIFT=1 _run_push_hook
    [ "$status" -eq 1 ]
    [[ "$output" == *"self-vendor drift detected"* ]]
    [[ "$output" == *"lib/newthing.sh"* ]]
}

# ── bypass still wins ────────────────────────────────────────────────────────

@test "t3125 (e) FW_SKIP_SELF_VENDOR_CHECK=1 still bypasses committed drift" {
    _commit_drift
    local sha; sha="$(git rev-parse HEAD)"
    run bash -c "echo 'refs/heads/$BRANCH $sha refs/heads/$BRANCH $REMOTE_SHA' \
        | FW_STUB_DRIFT=1 FW_SKIP_SELF_VENDOR_CHECK=1 .git/hooks/pre-push origin http://localhost"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN"* ]]
    [[ "$output" != *"Push blocked"* ]]
}
