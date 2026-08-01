#!/usr/bin/env bats
# T-2712: fw init's "is this project fresh?" test must consider completed/ too.
#
# lib/init.sh gates onboarding-task seeding on has_existing_tasks, which checked
# only .tasks/active/. Completing a task MOVES it to .tasks/completed/, so a project
# that finished onboarding shows an empty active/, reads as fresh, and gets
# T-001..T-005 (greenfield) or T-001..T-006 (existing-project) written over IDs it
# already used and committed against.
#
# The guard's comment says "idempotent on --force re-init". It was idempotent only
# for projects that had made no progress.
#
# Test 4 is the NEGATIVE CONTROL: it asserts the fixture state (empty active/,
# populated completed/) is genuinely the state the old guard mis-read. Without it,
# test 1 could pass for the wrong reason.

load ../test_helper

# The guard's logic, extracted so the test exercises the decision, not the whole
# 900-line do_init. Mirrors lib/init.sh exactly.
guard_says_existing() {
    local target_dir="$1"
    local has_existing_tasks=false
    local d
    for d in active completed; do
        if [ -d "$target_dir/.tasks/$d" ] \
           && ls "$target_dir/.tasks/$d/"T-*.md >/dev/null 2>&1; then
            has_existing_tasks=true
            break
        fi
    done
    echo "$has_existing_tasks"
}

@test "T-2712: completed-only project is NOT fresh (the defect)" {
    p="$TEST_TEMP_DIR/proj"
    mkdir -p "$p/.tasks/active" "$p/.tasks/completed"
    printf -- '---\nid: T-001\n---\n' > "$p/.tasks/completed/T-001-define-project-goals.md"

    [ "$(guard_says_existing "$p")" = "true" ]
}

@test "T-2712: genuinely empty project is still fresh (no regression)" {
    p="$TEST_TEMP_DIR/proj"
    mkdir -p "$p/.tasks/active" "$p/.tasks/completed"

    [ "$(guard_says_existing "$p")" = "false" ]
}

@test "T-2712: project with active tasks is still not fresh (no regression)" {
    p="$TEST_TEMP_DIR/proj"
    mkdir -p "$p/.tasks/active" "$p/.tasks/completed"
    printf -- '---\nid: T-042\n---\n' > "$p/.tasks/active/T-042-in-flight.md"

    [ "$(guard_says_existing "$p")" = "true" ]
}

@test "T-2712: NEGATIVE CONTROL — active-only guard genuinely mis-reads the fixture" {
    p="$TEST_TEMP_DIR/proj"
    mkdir -p "$p/.tasks/active" "$p/.tasks/completed"
    printf -- '---\nid: T-001\n---\n' > "$p/.tasks/completed/T-001-define-project-goals.md"

    # The pre-fix guard, verbatim. If this ever reports "true", the fixture has
    # stopped reproducing the defect and test 1 proves nothing.
    old=false
    if [ -d "$p/.tasks/active" ] && ls "$p/.tasks/active/"T-*.md >/dev/null 2>&1; then
        old=true
    fi
    [ "$old" = "false" ]
}

@test "T-2712: lib/init.sh guard actually scans completed/" {
    # Comments stripped (L-519): the fix's own comment discusses completed/ at
    # length, so a naive grep would match the explanation rather than the code.
    body=$(sed 's/[[:space:]]*#.*//' "$FRAMEWORK_ROOT/lib/init.sh")
    echo "$body" | grep -q 'for _seed_dir_probe in active completed'
}

@test "T-2712: seed sets still contain the IDs that were being duplicated" {
    # Guards the premise: if seeds stop shipping T-001.., the collision this task
    # prevents would no longer be the collision described.
    [ -f "$FRAMEWORK_ROOT/lib/seeds/tasks/greenfield/T-001-"*.md ] \
        || ls "$FRAMEWORK_ROOT/lib/seeds/tasks/greenfield/"T-001-*.md >/dev/null 2>&1
}
