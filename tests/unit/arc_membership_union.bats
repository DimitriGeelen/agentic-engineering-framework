#!/usr/bin/env bats
# T-1874: _arc_tasks_for unions arc_id frontmatter + legacy arc:<slug> tag.
#
# Verifies the post-T-1850 migration blindness fix: fw arc show / fw arc list
# constituent-task counts must include tasks whose membership is declared via
# the canonical `arc_id:` frontmatter (T-1849), not only legacy `arc:<slug>`
# tags. Both forms coexist during the transition; this test pins the union
# semantics.

load ../test_helper

setup() {
    export PROJECT_ROOT="$(mktemp -d)"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.context/arcs"

    # Minimal arc YAML so _arc_exists passes if any caller checks it.
    cat > "$PROJECT_ROOT/.context/arcs/test-arc.yaml" <<'YAML'
id: arc-999
slug: test-arc
name: "Test arc"
status: in-progress
YAML

    # Task A: arc_id only (post-migration canonical form)
    cat > "$PROJECT_ROOT/.tasks/active/T-9001-a.md" <<'MD'
---
id: T-9001
name: "arc_id-only task"
status: started-work
tags: [unrelated]
arc_id: test-arc
---
body
MD

    # Task B: legacy arc:<slug> tag only (pre-migration form)
    cat > "$PROJECT_ROOT/.tasks/active/T-9002-b.md" <<'MD'
---
id: T-9002
name: "legacy-tag-only task"
status: started-work
tags: [arc:test-arc, other]
---
body
MD

    # Task C: BOTH set (transitional, should not double-count)
    cat > "$PROJECT_ROOT/.tasks/completed/T-9003-c.md" <<'MD'
---
id: T-9003
name: "both set"
status: work-completed
tags: [arc:test-arc]
arc_id: test-arc
---
body
MD

    # Task D: unrelated arc — neither matches
    cat > "$PROJECT_ROOT/.tasks/active/T-9004-d.md" <<'MD'
---
id: T-9004
name: "other arc"
status: started-work
tags: [arc:something-else]
arc_id: something-else
---
body
MD

    # Source lib/arc.sh from the framework under test
    FRAMEWORK_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    # shellcheck disable=SC1090
    source "${FRAMEWORK_ROOT}/lib/arc.sh"
}

teardown() {
    rm -rf "$PROJECT_ROOT"
}

@test "_arc_tasks_with_arc_id finds arc_id-only task" {
    run _arc_tasks_with_arc_id "test-arc"
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-9001"* ]]
    # legacy-tag-only must NOT be returned by this helper
    [[ "$output" != *"T-9002"* ]]
}

@test "_arc_tasks_with_arc_id finds both-set task" {
    run _arc_tasks_with_arc_id "test-arc"
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-9003"* ]]
}

@test "_arc_tasks_with_arc_id ignores other-arc task" {
    run _arc_tasks_with_arc_id "test-arc"
    [ "$status" -eq 0 ]
    [[ "$output" != *"T-9004"* ]]
}

@test "_arc_tasks_with_tag still finds legacy-tag-only task" {
    run _arc_tasks_with_tag "arc:test-arc"
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-9002"* ]]
    [[ "$output" != *"T-9001"* ]]
}

@test "_arc_tasks_for unions both helpers without duplicating" {
    run _arc_tasks_for "test-arc"
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-9001"* ]]
    [[ "$output" == *"T-9002"* ]]
    [[ "$output" == *"T-9003"* ]]
    [[ "$output" != *"T-9004"* ]]
    # T-9003 set in both must appear exactly once
    local count
    count=$(printf '%s\n' "$output" | grep -c "^T-9003$")
    [ "$count" -eq 1 ]
}

@test "_arc_tasks_for returns sorted, deduplicated output" {
    run _arc_tasks_for "test-arc"
    [ "$status" -eq 0 ]
    local lines sorted
    lines=$(printf '%s\n' "$output")
    sorted=$(printf '%s\n' "$output" | sort -u)
    [ "$lines" = "$sorted" ]
}

@test "_arc_tasks_for tolerates quoted arc_id value" {
    cat > "$PROJECT_ROOT/.tasks/active/T-9005-q.md" <<'MD'
---
id: T-9005
name: "quoted form"
status: started-work
arc_id: "test-arc"
---
body
MD
    run _arc_tasks_for "test-arc"
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-9005"* ]]
}

@test "_arc_tasks_for returns empty for unknown arc without erroring" {
    run _arc_tasks_for "nonexistent-arc"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
