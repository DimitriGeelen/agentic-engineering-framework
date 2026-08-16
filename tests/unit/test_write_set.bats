#!/usr/bin/env bats
# T-2337 (arc-011 M1 §3) — disjoint write-set validator.
#
# Pins `lib/write_set.py` + `fw write-set check` behaviour: read `write_set:`
# frontmatter from two task files, expand globs, report disjoint | overlap |
# undecidable. The orchestrator consults this before emitting parallel
# dispatch for the arc-011 headline_mechanic.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    TEST_REPO="$TEST_TEMP_DIR/repo"
    mkdir -p "$TEST_REPO/.tasks/active" "$TEST_REPO/.tasks/completed" "$TEST_REPO/docs/reports"
    cd "$TEST_REPO"
    export PROJECT_ROOT="$TEST_REPO"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_write_task() {
    # _write_task <id> <write-set-yaml-block-or-empty>
    local id="$1" ws_block="$2"
    local fn=".tasks/active/${id}-test.md"
    cat > "$fn" <<EOF
---
id: $id
name: "$id test fixture"
description: "test fixture for T-2337"
status: started-work
workflow_type: build
owner: agent
horizon: now
$ws_block
---

# $id

## Acceptance Criteria
- [ ] body
EOF
}

@test "non-overlapping write_set is 'converging', not 'disjoint' (T-3039)" {
    # CHANGED BY T-3039, and the change is the point rather than a relaxation.
    # This test previously asserted exit 0 + 'disjoint' — which was true of the
    # DECLARED lists and false of the tasks: both also write inbox.yaml,
    # learnings.yaml, focus.yaml and session.yaml, because the framework writes
    # those on every task's behalf. Exit 0 here was a green light to parallelise
    # into the 27-site RMW set that T-3042 lost data in.
    _write_task "T-PAR-A" "write_set: [docs/reports/T-PAR-A.md]"
    _write_task "T-PAR-B" "write_set: [docs/reports/T-PAR-B.md]"
    run "$FRAMEWORK_ROOT/bin/fw" write-set check T-PAR-A T-PAR-B
    [ "$status" -eq 1 ]
    [[ "$output" == *"converging"* ]]
}

@test "--declared-only still reports the old 'disjoint' for the same pair (T-3039)" {
    # The pre-T-3039 comparison is retained behind an explicit flag, so the
    # original contract is still exercised and the behaviour change is visible
    # as a deliberate seam rather than a deleted assertion.
    _write_task "T-PAR-A" "write_set: [docs/reports/T-PAR-A.md]"
    _write_task "T-PAR-B" "write_set: [docs/reports/T-PAR-B.md]"
    run "$FRAMEWORK_ROOT/bin/fw" write-set check T-PAR-A T-PAR-B --declared-only
    [ "$status" -eq 0 ]
    [[ "$output" == *"disjoint"* ]]
}

@test "overlap case — two tasks writing to the same path return exit 1 + 'overlap'" {
    _write_task "T-COL-A" "write_set: [docs/SHARED.md]"
    _write_task "T-COL-B" "write_set: [docs/SHARED.md]"
    run "$FRAMEWORK_ROOT/bin/fw" write-set check T-COL-A T-COL-B
    [ "$status" -eq 1 ]
    [[ "$output" == *"overlap"* ]]
}

@test "glob-collision case — recursive glob and concrete path that match same file return overlap" {
    # Create the concrete file so the glob has something to expand against
    mkdir -p "$TEST_REPO/.tasks/active"
    touch "$TEST_REPO/.tasks/active/T-X.md"
    _write_task "T-GLOB-A" "write_set: ['**/T-*.md']"
    _write_task "T-GLOB-B" "write_set: ['.tasks/active/T-X.md']"
    run "$FRAMEWORK_ROOT/bin/fw" write-set check T-GLOB-A T-GLOB-B
    [ "$status" -eq 1 ]
    [[ "$output" == *"overlap"* ]]
}

@test "undecidable case — task without write_set frontmatter returns exit 2 + 'undecidable'" {
    _write_task "T-NO-A" "write_set: [docs/foo.md]"
    _write_task "T-NO-B" ""   # no write_set field at all
    run "$FRAMEWORK_ROOT/bin/fw" write-set check T-NO-A T-NO-B
    [ "$status" -eq 2 ]
    [[ "$output" == *"undecidable"* ]]
}

@test "missing-task-file error — unknown task id returns exit 2 + error on stderr" {
    _write_task "T-EXIST" "write_set: [foo.md]"
    run "$FRAMEWORK_ROOT/bin/fw" write-set check T-EXIST T-DOES-NOT-EXIST
    [ "$status" -eq 2 ]
    [[ "$output" == *"not found"* ]] || [[ "$output" == *"error"* ]]
}

@test "fw write-set --help prints usage and exits 0" {
    run "$FRAMEWORK_ROOT/bin/fw" write-set --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"check"* ]]
    [[ "$output" == *"disjoint"* ]]
    [[ "$output" == *"overlap"* ]]
}

@test "fw write-set check with missing args returns exit 64 + usage" {
    run "$FRAMEWORK_ROOT/bin/fw" write-set check
    [ "$status" -eq 64 ]
    [[ "$output" == *"usage"* ]]
}

@test "empty write_set list is still DECLARED — decidable, and converging (T-3039)" {
    # The property this test was written to protect is that an empty list is
    # distinguishable from a missing field: `[]` means "I declare that I write
    # nothing", not "I did not say". That still holds — the verdict is decidable
    # (not 'undecidable'), which is what read_write_set()'s empty-list branch
    # exists for.
    #
    # What changed is the verdict word: a task cannot actually write nothing.
    # Being a framework task means writing focus.yaml and session.yaml at
    # minimum, so 'converging' is the honest answer and 'disjoint' never was.
    _write_task "T-EMPTY" "write_set: []"
    _write_task "T-NORMAL" "write_set: [docs/foo.md]"
    run "$FRAMEWORK_ROOT/bin/fw" write-set check T-EMPTY T-NORMAL
    [ "$status" -eq 1 ]
    [[ "$output" == *"converging"* ]]
    [[ "$output" != *"undecidable"* ]]

    # The declared-only view proves the empty list was parsed as a declaration
    # rather than silently treated as absent.
    run "$FRAMEWORK_ROOT/bin/fw" write-set check T-EMPTY T-NORMAL --declared-only
    [ "$status" -eq 0 ]
    [[ "$output" == *"disjoint"* ]]
}
