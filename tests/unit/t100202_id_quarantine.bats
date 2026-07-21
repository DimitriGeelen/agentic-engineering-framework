#!/usr/bin/env bats
# Regression: task-ID allocator quarantines far-outlier bands (T-100202).
#
# A removed self-feeding audit-finding emitter inflated one ID to T-99971 in a
# single leap; the old "global max + 1" allocator then chained every new task
# into the T-100xxx band while real work sat at ~T-2524. generate_id now uses
# "MAIN-CLUSTER max + 1" — a block separated from the rest by a gap larger than
# FW_ID_QUARANTINE_GAP (default 1000) is excluded from the ceiling, so new tasks
# resume at sane numbers WITHOUT renumbering the existing band.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
CREATE_TASK="$FRAMEWORK_ROOT/agents/task-create/create-task.sh"

setup() {
    export BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"
    export TEST_DIR="$BATS_TMPDIR/fw_id_quarantine_test_$$"
    mkdir -p "$TEST_DIR/active" "$TEST_DIR/completed" "$TEST_DIR/templates"
    cp "$FRAMEWORK_ROOT/.tasks/templates/zzz-default.md" "$TEST_DIR/templates/default.md" 2>/dev/null || true
    export TASKS_DIR="$TEST_DIR"
    export PROJECT_ROOT="$FRAMEWORK_ROOT"
    # Hermeticity (T-100185 sibling): strip inherited session env so the
    # inception recommendation gate never arms during --type build creation.
    unset CLAUDECODE FW_ALLOW_EMPTY_RECOMMENDATION FW_INCEPTION_PRE_GATED
    # Hermeticity (T-2289 invariant): a derivation sentinel inherited from the
    # invoking session would cause paths.sh to discard the explicit TASKS_DIR.
    unset _FW_PATHS_DERIVED_BY
}

teardown() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}

_seed() { : > "$TEST_DIR/active/$1.md"; }

_mint() {
    run timeout 15 "$CREATE_TASK" --name "$1" --description "d" --type build --owner agent < /dev/null
    [ "$status" -eq 0 ]
}

@test "T-100202: outlier band is quarantined — new ID resumes at main cluster, not the band" {
    _seed "T-2523-seed"
    _seed "T-2524-seed"
    _seed "T-99971-inflation-outlier"
    _mint "Quarantine probe"
    # Main cluster max is 2524 → next is T-2525, NOT T-99972 (the old global-max+1).
    ls "$TEST_DIR/active/" | grep -q '^T-2525-'
    ! ls "$TEST_DIR/active/" | grep -q '^T-99972-'
}

@test "T-100202: whole T-100xxx-style band is skipped even when it dominates the corpus" {
    _seed "T-2524-seed"
    _seed "T-100199-band"
    _seed "T-100200-band"
    _seed "T-100201-band"
    _mint "Skip band probe"
    ls "$TEST_DIR/active/" | grep -q '^T-2525-'
    ! ls "$TEST_DIR/active/" | grep -q '^T-100202-'
}

@test "T-100202: backward-compatible — no outlier band means plain global max + 1" {
    _seed "T-0010-a"
    _seed "T-0011-b"
    _mint "No outlier probe"
    ls "$TEST_DIR/active/" | grep -q '^T-012-'
}

@test "T-100202: sub-threshold gap is NOT quarantined (both stay in the main cluster)" {
    _seed "T-0010-a"
    _seed "T-0900-b"   # gap 890 < 1000 → same cluster
    _mint "Small gap probe"
    ls "$TEST_DIR/active/" | grep -q '^T-901-'
}

@test "T-100202: allocator parses the LEADING id only — embedded T-NNNN in a recursive slug is ignored" {
    _seed "T-0010-a"
    # An inflation-era recursive filename with an embedded uppercase T-99999.
    _seed "T-0011-audit-warn--task-T-99999-audit-warn"
    _mint "Leading anchor probe"
    # Embedded 99999 must NOT drive the ceiling; leading ids are 10,11 → next 012.
    ls "$TEST_DIR/active/" | grep -q '^T-012-'
    ! ls "$TEST_DIR/active/" | grep -q '^T-100000-'
}

@test "T-100202: empty corpus mints T-001" {
    _mint "First task probe"
    ls "$TEST_DIR/active/" | grep -q '^T-001-'
}

# ── AC3: cross-view guard ────────────────────────────────────────────────────

@test "T-100202 AC3: worktree with stale .tasks view unions the main checkout — no duplicate ID" {
    local repo="$TEST_DIR/repo" wt="$TEST_DIR/wt"
    mkdir -p "$repo/.tasks/active" "$repo/.tasks/completed" "$repo/.tasks/templates"
    cp "$FRAMEWORK_ROOT/.tasks/templates/zzz-default.md" "$repo/.tasks/templates/default.md" 2>/dev/null || true
    : > "$repo/.tasks/active/T-0010-committed.md"
    git -C "$repo" init -q
    git -C "$repo" add -A
    git -C "$repo" -c user.email=t@t -c user.name=t commit -qm seed
    git -C "$repo" worktree add -q "$wt" HEAD
    # Main checkout advances past the worktree's snapshot (uncommitted is enough
    # to diverge the views — the worktree never sees it).
    : > "$repo/.tasks/active/T-0020-main-only.md"

    run timeout 15 env TASKS_DIR="$wt/.tasks" "$CREATE_TASK" \
        --name "Cross view probe" --description "d" --type build --owner agent < /dev/null
    [ "$status" -eq 0 ]
    # Union max is 20 → T-021. The old local-only scan would mint T-011,
    # colliding with a future main-side T-011 (the T-100200 dup class).
    ls "$wt/.tasks/active/" | grep -q '^T-021-'
    ! ls "$wt/.tasks/active/" | grep -q '^T-011-'
}

@test "T-100202 AC3: non-git TASKS_DIR falls back to local-only scan (harness/back-compat)" {
    _seed "T-0030-local"
    _mint "Fallback probe"
    ls "$TEST_DIR/active/" | grep -q '^T-031-'
}

# ── AC4: audit-emit recursion guard ──────────────────────────────────────────

@test "T-100202 AC4: recursive audit-warn name is refused, no file minted" {
    _seed "T-0010-a"
    run timeout 15 "$CREATE_TASK" \
        --name "Audit WARN — Task T-2488-audit-warn--task-t-2462-audit-warn--task.md missing Updates" \
        --description "d" --type build --owner agent < /dev/null
    [ "$status" -ne 0 ]
    [[ "$output" == *"Recursive audit-warn task name refused"* ]]
    # Nothing minted
    [ "$(ls "$TEST_DIR/active/" | grep -c '^T-011-')" -eq 0 ]
}

@test "T-100202 AC4: a single audit-warn mention is still a legal task name" {
    _seed "T-0010-a"
    _mint "Fix audit WARN on cron drift"
    ls "$TEST_DIR/active/" | grep -q '^T-011-'
}
