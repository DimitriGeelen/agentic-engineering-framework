#!/usr/bin/env bats
# T-3107 (slice 2 of 3): duplicate-ID detection spans every corpus view.
#
# The failure this rail exists for: agents/audit/audit.sh scanned the main
# checkout alone and printed "No duplicate task IDs" for seven weeks while
# T-2505, T-2506 and T-2428 each named a DIFFERENT task in a worktree replica.
#
# The judgement the tests are really pinning is the discriminator. Git checks
# the same committed task out into every worktree, and a worktree pinned to an
# older commit holds an older revision of it — so "the bytes differ" is true of
# 2744 of this repo's 2911 multi-view IDs and means nothing. The check asks
# whether the files are the same TASK (`created:`, falling back to the filename
# slug), not whether they are the same bytes. Tests 5-7 below are the ones that
# fail if someone "simplifies" it back to a hash compare.
#
# Fixtures are REAL git repos with REAL `git worktree add`: the class lives in
# git's view semantics, so a mocked `git worktree list` would only prove the
# mock works (same reasoning as tests/unit/t3104_task_corpus_views.bats).

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    RUNNER="$REPO_ROOT/tests/helpers/audit-dup-task-ids-block.sh"
    export TEST_DIR="${BATS_TMPDIR:-/tmp}/fw_t3107_$$_${BATS_TEST_NUMBER}"
    mkdir -p "$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}

# Run the shipped block with $1 as the local .tasks view.
scan() { run env -u _FW_PATHS_DERIVED_BY -u _FW_PATHS_LOADED "$RUNNER" "$REPO_ROOT" "$1"; }

# Write a task file. $4 (created) and $5 (body) are optional.
mktask() {
    local dir="$1" tid="$2" slug="$3" created="${4-2026-01-01T00:00:00Z}" body="${5:-body}"
    mkdir -p "$dir"
    {
        echo "---"
        echo "id: $tid"
        echo "name: \"$slug\""
        [ -n "$created" ] && echo "created: $created"
        echo "---"
        echo ""
        echo "$body"
    } > "$dir/${tid}-${slug}.md"
}

# A git repo at $1 with a committed .tasks/ tree.
make_repo() {
    local root="$1"
    mkdir -p "$root/.tasks/active" "$root/.tasks/completed"
    git -C "$root" init -q
    git -C "$root" config user.email t3107@test.local
    git -C "$root" config user.name t3107
    : > "$root/.tasks/active/.keep"
    git -C "$root" add -A
    git -C "$root" commit -qm "T-3107: fixture"
}

commit_all() { git -C "$1" add -A && git -C "$1" commit -qm "${2:-T-3107: fixture change}"; }

# ── 1. clean single view ─────────────────────────────────────────────────────

@test "clean single view: PASS, and the line states files AND views" {
    make_repo "$TEST_DIR/main"
    mktask "$TEST_DIR/main/.tasks/active" T-1 alpha
    mktask "$TEST_DIR/main/.tasks/completed" T-2 beta
    commit_all "$TEST_DIR/main"

    scan "$TEST_DIR/main/.tasks"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^PASS|No duplicate task IDs — examined 2 task file(s) across 1 corpus view(s)'
    echo "$output" | grep -q '^COUNTS|pass=1|warn=0|fail=0$'
}

@test "PASS count is measured, not hard-coded: it tracks the real file count" {
    make_repo "$TEST_DIR/main"
    for i in 1 2 3 4 5; do mktask "$TEST_DIR/main/.tasks/active" "T-$i" "slug$i"; done
    commit_all "$TEST_DIR/main"
    n=$(find "$TEST_DIR/main/.tasks" -name 'T-*.md' -type f | wc -l)
    [ "$n" -eq 5 ]

    scan "$TEST_DIR/main/.tasks"
    rendered=$(echo "$output" | sed -n 's/^PASS|No duplicate task IDs — examined \([0-9]*\) task file(s).*/\1/p')
    [ "$rendered" -eq "$n" ]
}

# ── 2. clean multi-view with identical replicas ──────────────────────────────

@test "multi-view with byte-identical replicas: PASS, view count is 3, replicas counted not reported" {
    make_repo "$TEST_DIR/main"
    mktask "$TEST_DIR/main/.tasks/active" T-1 alpha
    mktask "$TEST_DIR/main/.tasks/active" T-2 beta
    commit_all "$TEST_DIR/main"
    git -C "$TEST_DIR/main" worktree add -q -b wt1 "$TEST_DIR/wt1"
    git -C "$TEST_DIR/main" worktree add -q -b wt2 "$TEST_DIR/wt2"

    scan "$TEST_DIR/main/.tasks"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'examined 6 task file(s) across 3 corpus view(s)'
    echo "$output" | grep -q '2 ID(s) byte-identical in every view'
    echo "$output" | grep -q '^COUNTS|pass=1|warn=0|fail=0$'
    # A replica is NOT a finding: neither ID may be named as a collision.
    if echo "$output" | grep -q '^FAIL|'; then false; fi
    ! echo "$output" | grep -qi 'collision'
}

# ── 3. within-authority duplicate -> FAIL ────────────────────────────────────

@test "same ID twice inside ONE view FAILs and names both paths" {
    make_repo "$TEST_DIR/main"
    mktask "$TEST_DIR/main/.tasks/active"    T-7 alpha
    mktask "$TEST_DIR/main/.tasks/completed" T-7 alpha
    commit_all "$TEST_DIR/main"

    scan "$TEST_DIR/main/.tasks"
    echo "$output" | grep -q '^FAIL|Duplicate task IDs detected (G-052)'
    echo "$output" | grep -q 'T-7'
    echo "$output" | grep -q '.tasks/active/T-7-alpha.md'
    echo "$output" | grep -q '.tasks/completed/T-7-alpha.md'
    echo "$output" | grep -q '|fail=1$'
    # a FAIL suppresses the PASS line — the check did not come up clean
    ! echo "$output" | grep -q '^PASS|'
}

@test "a within-view duplicate in a WORKTREE view FAILs too (not just the authority)" {
    # The seven-week blind spot was precisely 'the other view does not count'.
    make_repo "$TEST_DIR/main"
    mktask "$TEST_DIR/main/.tasks/active" T-1 alpha
    commit_all "$TEST_DIR/main"
    git -C "$TEST_DIR/main" worktree add -q -b wt1 "$TEST_DIR/wt1"
    mktask "$TEST_DIR/wt1/.tasks/completed" T-1 alpha
    commit_all "$TEST_DIR/wt1"

    scan "$TEST_DIR/main/.tasks"
    echo "$output" | grep -q '^FAIL|Duplicate task IDs detected (G-052)'
    echo "$output" | grep -q "$TEST_DIR/wt1/.tasks/completed/T-1-alpha.md"
}

# ── 4. cross-view divergent duplicate -> WARN naming both paths ──────────────

@test "cross-view fork (different created:) WARNs and names BOTH view paths" {
    make_repo "$TEST_DIR/main"
    mktask "$TEST_DIR/main/.tasks/active" T-9 alpha 2026-05-05T00:00:00Z
    commit_all "$TEST_DIR/main"
    git -C "$TEST_DIR/main" worktree add -q -b wt1 "$TEST_DIR/wt1"
    rm -f "$TEST_DIR/wt1/.tasks/active/T-9-alpha.md"
    mktask "$TEST_DIR/wt1/.tasks/active" T-9 omega 2026-07-01T09:18:46Z
    commit_all "$TEST_DIR/wt1"

    scan "$TEST_DIR/main/.tasks"
    echo "$output" | grep -q '^WARN|Cross-view task-ID collisions: 1 ID(s) name a different task in another corpus view'
    echo "$output" | grep -q 'FORK T-9 (identity differs by created:)'
    echo "$output" | grep -q "$TEST_DIR/main/.tasks/active/T-9-alpha.md"
    echo "$output" | grep -q "$TEST_DIR/wt1/.tasks/active/T-9-omega.md"
    echo "$output" | grep -q '|warn=1|fail=0$'
    # WARN, not FAIL: a fork artifact is historical, an in-view duplicate is live
    if echo "$output" | grep -q '^FAIL|'; then false; fi
    ! echo "$output" | grep -q '^PASS|'
}

@test "a fork does not suppress a simultaneous within-view FAIL: both are emitted" {
    make_repo "$TEST_DIR/main"
    mktask "$TEST_DIR/main/.tasks/active"    T-9 alpha 2026-05-05T00:00:00Z
    mktask "$TEST_DIR/main/.tasks/completed" T-4 dup   2026-05-05T00:00:00Z
    mktask "$TEST_DIR/main/.tasks/active"    T-4 dup   2026-05-05T00:00:00Z
    commit_all "$TEST_DIR/main"
    git -C "$TEST_DIR/main" worktree add -q -b wt1 "$TEST_DIR/wt1"
    rm -f "$TEST_DIR/wt1/.tasks/active/T-9-alpha.md"
    mktask "$TEST_DIR/wt1/.tasks/active" T-9 omega 2026-07-01T09:18:46Z
    commit_all "$TEST_DIR/wt1"

    scan "$TEST_DIR/main/.tasks"
    echo "$output" | grep -q '^FAIL|Duplicate task IDs detected (G-052)'
    echo "$output" | grep -q '^WARN|Cross-view task-ID collisions'
    echo "$output" | grep -q '|warn=1|fail=1$'
    # the FAIL evidence must not swallow the FORK lines, nor vice versa
    [ "$(echo "$output" | grep -c 'FORK T-9')" -eq 1 ]
    [ "$(echo "$output" | grep -c 'WITHIN T-4')" -eq 1 ]
}

# ── 5-7. the discriminator: identity, not content ────────────────────────────

@test "cross-view identical replica stays SILENT (no WARN, no FAIL)" {
    make_repo "$TEST_DIR/main"
    mktask "$TEST_DIR/main/.tasks/active" T-3 gamma
    commit_all "$TEST_DIR/main"
    git -C "$TEST_DIR/main" worktree add -q -b wt1 "$TEST_DIR/wt1"

    scan "$TEST_DIR/main/.tasks"
    echo "$output" | grep -q '^PASS|'
    echo "$output" | grep -q '1 ID(s) byte-identical in every view'
    if echo "$output" | grep -q '^WARN|'; then false; fi
    ! echo "$output" | grep -q '^FAIL|'
}

@test "SAME task at DIFFERENT revisions stays silent — bytes differ, identity does not" {
    # THE noise test. A worktree pinned to an older commit holds an older
    # revision of the same task. A content-hash discriminator flags this; on the
    # live corpus that is 2744 findings and the check dies of irrelevance.
    make_repo "$TEST_DIR/main"
    mktask "$TEST_DIR/main/.tasks/active" T-5 delta 2026-05-05T00:00:00Z "original body"
    commit_all "$TEST_DIR/main"
    git -C "$TEST_DIR/main" worktree add -q -b wt1 "$TEST_DIR/wt1"
    # main edits the task; wt1 keeps the older revision. Same id, same created:,
    # same slug, different bytes.
    mktask "$TEST_DIR/main/.tasks/active" T-5 delta 2026-05-05T00:00:00Z "revised body, much longer than before"
    commit_all "$TEST_DIR/main"
    if cmp -s "$TEST_DIR/main/.tasks/active/T-5-delta.md" "$TEST_DIR/wt1/.tasks/active/T-5-delta.md"; then false; fi

    scan "$TEST_DIR/main/.tasks"
    echo "$output" | grep -q '^PASS|'
    echo "$output" | grep -q '1 same-task at differing revisions'
    if echo "$output" | grep -q '^WARN|'; then false; fi
    ! echo "$output" | grep -q 'FORK T-5'
}

@test "fallback to filename slug when a view's copy has no created: field" {
    # 18 legacy files in the live corpus carry no parseable created:. Falling
    # back to the slug keeps them classifiable instead of silently unscanned.
    make_repo "$TEST_DIR/main"
    mktask "$TEST_DIR/main/.tasks/active" T-6 epsilon ""
    commit_all "$TEST_DIR/main"
    git -C "$TEST_DIR/main" worktree add -q -b wt1 "$TEST_DIR/wt1"
    rm -f "$TEST_DIR/wt1/.tasks/active/T-6-epsilon.md"
    mktask "$TEST_DIR/wt1/.tasks/active" T-6 zeta ""
    commit_all "$TEST_DIR/wt1"

    scan "$TEST_DIR/main/.tasks"
    echo "$output" | grep -q 'FORK T-6 (identity differs by filename slug)'
    echo "$output" | grep -q '^WARN|Cross-view task-ID collisions'
}

@test "no created: anywhere and identical slugs: silent, not a fork" {
    make_repo "$TEST_DIR/main"
    mktask "$TEST_DIR/main/.tasks/active" T-6 epsilon "" "one"
    commit_all "$TEST_DIR/main"
    git -C "$TEST_DIR/main" worktree add -q -b wt1 "$TEST_DIR/wt1"
    mktask "$TEST_DIR/main/.tasks/active" T-6 epsilon "" "two — different bytes"
    commit_all "$TEST_DIR/main"

    scan "$TEST_DIR/main/.tasks"
    echo "$output" | grep -q '^PASS|'
    ! echo "$output" | grep -q '^WARN|'
}

# ── 8. degenerate view sets WARN, never PASS ─────────────────────────────────

@test "empty view set WARNs via warn_unenumerable, never PASS" {
    make_repo "$TEST_DIR/main"
    mktask "$TEST_DIR/main/.tasks/active" T-1 alpha
    commit_all "$TEST_DIR/main"

    run env FW_T3107_NO_VIEWS=1 "$RUNNER" "$REPO_ROOT" "$TEST_DIR/main/.tasks"
    echo "$output" | grep -q 'NOT EVALUATED: could not read the corpus view set'
    echo "$output" | grep -q '^COUNTS|pass=0|warn=1|fail=0$'
    ! echo "$output" | grep -q '^PASS|'
}

@test "views present but zero task files WARNs (candidate set empty), never PASS" {
    make_repo "$TEST_DIR/main"

    scan "$TEST_DIR/main/.tasks"
    echo "$output" | grep -q 'NOT EVALUATED: candidate set empty'
    ! echo "$output" | grep -q '^PASS|'
}

@test "fw_task_view_dirs undefined WARNs and says lib/paths.sh is stale" {
    make_repo "$TEST_DIR/main"
    mktask "$TEST_DIR/main/.tasks/active" T-1 alpha
    commit_all "$TEST_DIR/main"

    run env FW_T3107_UNDEF_VIEWS=1 "$RUNNER" "$REPO_ROOT" "$TEST_DIR/main/.tasks"
    echo "$output" | grep -q 'NOT EVALUATED: could not read the corpus view set'
    echo "$output" | grep -q 'lib/paths.sh is stale'
    ! echo "$output" | grep -q '^PASS|'
}

# ── 9. the shipped source holds one definition of the corpus ─────────────────

@test "the duplicate check reads fw_task_view_dirs and defines no second corpus" {
    block=$(sed -n '/^if ! declare -F fw_task_view_dirs/,/^# end duplicate-task-ID scan$/p' \
            "$REPO_ROOT/agents/audit/audit.sh")
    [ -n "$block" ]
    echo "$block" | grep -q 'fw_task_view_dirs'
    # no bare pass "..." — every verdict routes through T-3105's emitters
    if echo "$block" | grep -qE '^[[:space:]]*pass "'; then false; fi
    # and no hand-rolled corpus root: the old block hard-coded TASKS_DIR
    ! echo "$block" | grep -q "environ.get('TASKS_DIR'"
}

@test "audit.sh keeps its exec bit (OBS-336: a lost +x killed the rail at exit 126)" {
    [ -x "$REPO_ROOT/agents/audit/audit.sh" ]
}
