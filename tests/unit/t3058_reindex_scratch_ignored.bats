#!/usr/bin/env bats
# T-3058 — the vector reindex scratch copy must be gitignored.
#
# It is not a leak. `web/embeddings.py` parks partial work in it so an hourly
# cron can finish a 29-58h bootstrap across many firings (OBS-258), so the file
# sits in .context/working/ for DAYS, at index size, inside the directory every
# handover commits from. `.reindex.resume` was already ignored and the scratch is
# `shutil.move`d into exactly that path — same file, two moments of one run, only
# one of them covered.
#
# Checks run against a scratch repo holding a COPY of the real .gitignore, so the
# mutation (deleting the rule) is possible without touching the working tree.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    R="$TEST_TEMP_DIR/repo"
    mkdir -p "$R/.context/working"
    git -C "$R" init -q .
    cp "$FRAMEWORK_ROOT/.gitignore" "$R/.gitignore"
}

teardown() {
    rm -rf "${TEST_TEMP_DIR:?}"
}

# Drop every .gitignore line matching $1 — the mutation.
_drop_rule() {
    grep -v -- "$1" "$R/.gitignore" > "$R/.gitignore.new"
    ! cmp -s "$R/.gitignore" "$R/.gitignore.new"   # the rule must have existed
    mv "$R/.gitignore.new" "$R/.gitignore"
}

_ignored() {
    git -C "$R" check-ignore -q ".context/working/$1"
}

# A pid that is not the one on disk — the filename carries os.getpid(), so a rule
# that only covered today's file would be worthless tomorrow.
SCRATCH="fw-vec-index.db.reindex.987654.tmp"

@test "A1 — the reindex scratch is ignored, for an arbitrary pid" {
    run _ignored "$SCRATCH"
    [ "$status" -eq 0 ]
}

@test "A1 — the scratch journal is ignored too" {
    run _ignored "${SCRATCH}-journal"
    [ "$status" -eq 0 ]
}

@test "A5 — removing the rule makes the scratch visible again (mutation)" {
    _drop_rule '\.db\.reindex\.\*\.tmp$'
    run _ignored "$SCRATCH"
    [ "$status" -ne 0 ]
}

@test "A5 — removing the journal rule makes the journal visible (mutation)" {
    _drop_rule '\.db\.reindex\.\*\.tmp-journal$'
    run _ignored "${SCRATCH}-journal"
    [ "$status" -ne 0 ]
}

@test "A2 — the index itself is still covered by its own *.db rule, not the new ones" {
    # The way this fix goes wrong silently is a glob wide enough to swallow the
    # real index. Drop both new rules: fw-vec-index.db must stay ignored.
    _drop_rule '\.db\.reindex\.\*\.tmp$'
    _drop_rule '\.db\.reindex\.\*\.tmp-journal$'
    run _ignored "fw-vec-index.db"
    [ "$status" -eq 0 ]
}

@test "A2 — the resume file the scratch is moved into stays ignored" {
    # web/embeddings.py:1092 shutil.move(tmp_path -> resume_path). If a future
    # tidy-up folds these rules together, this is the one that must survive.
    run _ignored "fw-vec-index.db.reindex.resume"
    [ "$status" -eq 0 ]
}

@test "A1 — an unrelated .context/working file is NOT swept up (positive control)" {
    # Guards the harness: if check-ignore matched everything, every test above
    # would pass for the wrong reason.
    run _ignored "session.yaml"
    [ "$status" -ne 0 ]
}
