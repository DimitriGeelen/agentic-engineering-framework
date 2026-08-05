#!/usr/bin/env bats
# tests/unit/arc_membership_dual_id.bats — T-1913
#
# Pins the slug↔NNN union behaviour in arc_tasks_for().
# Without this fix:
#   - `arc_tasks_for "<slug>"` returns only tasks with `arc_id: <slug>`
#   - `arc_tasks_for "<NNN>"` returns only tasks with `arc_id: <NNN>`
#   - Mixed-form corpora (the normal case post-T-1848 sequential IDs) get
#     a silent undercount.
#
# B-1 from the arc-005 critical re-audit (2026-05-18 session): the arc-grooming
# arc had 32 slug-form tasks + 3 NNN-form tasks = 35 total constituents, but
# `fw arc show arc-grooming` returned 32 while Watchtower returned 35.

load ../test_helper

setup() {
    export TEST_TMP="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TMP"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.context/arcs"
    mkdir -p "$PROJECT_ROOT/.tasks/active"
    mkdir -p "$PROJECT_ROOT/.tasks/completed"

    # Fixture arc YAML: id: arc-099, slug: test-dualid
    cat > "$PROJECT_ROOT/.context/arcs/test-dualid.yaml" <<'EOF'
id: arc-099
slug: test-dualid
name: "Fixture arc — slug↔NNN dual identity test"
status: in-progress
created: 2026-05-18T00:00:00Z
EOF

    # Task using slug form (legacy / pre-T-1848 style)
    cat > "$PROJECT_ROOT/.tasks/active/T-0001-fixture-slug.md" <<'EOF'
---
id: T-0001
name: "fixture using slug form"
arc_id: test-dualid
status: started-work
---
body
EOF

    # Task using NNN form (canonical / post-T-1848)
    cat > "$PROJECT_ROOT/.tasks/active/T-0002-fixture-nnn.md" <<'EOF'
---
id: T-0002
name: "fixture using NNN form"
arc_id: arc-099
status: started-work
---
body
EOF

    # Task using legacy arc:<slug> tag (pre-T-1850 migration)
    cat > "$PROJECT_ROOT/.tasks/completed/T-0003-fixture-tag.md" <<'EOF'
---
id: T-0003
name: "fixture using legacy arc:<slug> tag"
tags: [arc:test-dualid, other]
status: work-completed
---
body
EOF

    # Source the helper from the framework repo (this test runs from there).
    SCRIPT_DIR="$( cd -- "$( dirname -- "${BATS_TEST_FILENAME}" )/../.." &> /dev/null && pwd )"
    unset __ARC_MEMBERSHIP_SOURCED
    . "$SCRIPT_DIR/lib/arc_membership.sh"
}

teardown() {
    rm -rf "$TEST_TMP"
    unset __ARC_MEMBERSHIP_SOURCED
}

@test "_arc_resolve_dual_id resolves slug input to (slug, NNN) pair" {
    run _arc_resolve_dual_id test-dualid
    [ "$status" -eq 0 ]
    [[ "$output" == *"test-dualid"* ]]
    [[ "$output" == *"arc-099"* ]]
}

@test "_arc_resolve_dual_id resolves NNN input to (slug, NNN) pair" {
    run _arc_resolve_dual_id arc-099
    [ "$status" -eq 0 ]
    [[ "$output" == *"test-dualid"* ]]
    [[ "$output" == *"arc-099"* ]]
}

@test "_arc_resolve_dual_id emits empty for unknown input" {
    run _arc_resolve_dual_id no-such-arc-xyz
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "arc_tasks_for slug returns BOTH slug-form and NNN-form tasks" {
    run arc_tasks_for test-dualid
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-0001"* ]]
    [[ "$output" == *"T-0002"* ]]
    [[ "$output" == *"T-0003"* ]]
    # count: 3 distinct
    count=$(echo "$output" | grep -c "^T-")
    [ "$count" -eq 3 ]
}

@test "arc_tasks_for NNN returns the same 3 tasks as slug form" {
    run arc_tasks_for arc-099
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-0001"* ]]
    [[ "$output" == *"T-0002"* ]]
    [[ "$output" == *"T-0003"* ]]
}

@test "arc_tasks_for unknown input degrades to literal-only (no resolution)" {
    run arc_tasks_for no-such-arc-xyz
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "arc_tasks_with_arc_id matches single form only (regression pin)" {
    # This is the existing behaviour kept for callers that need strict
    # single-form match. The dual-id union lives in arc_tasks_for.
    run arc_tasks_with_arc_id test-dualid
    [[ "$output" == *"T-0001"* ]]
    [[ "$output" != *"T-0002"* ]]
}
