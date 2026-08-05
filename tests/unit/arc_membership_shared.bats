#!/usr/bin/env bats
# T-1880 (T-NEW-15): pin shared shell API for arc-membership scans.
# Sibling to tests/unit/arc_membership_agent_surfaces.bats (which pins
# consumer-site behaviour). This file pins the SHARED LIBRARY itself.

setup() {
    # Synthetic PROJECT_ROOT — isolated per-test fixture.
    PROJECT_ROOT="$(mktemp -d)"
    guard_project_root
    export PROJECT_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"

    # 1: legacy-tag-only (pre-T-1850 representation)
    cat > "$PROJECT_ROOT/.tasks/active/T-9001-legacy-only.md" <<'EOF'
---
id: T-9001
arc_id:
tags: [arc:test-arc-x, build]
---
body
EOF

    # 2: arc_id-only (T-1850 migrated representation)
    cat > "$PROJECT_ROOT/.tasks/active/T-9002-arc-id-only.md" <<'EOF'
---
id: T-9002
arc_id: test-arc-x
tags: [build]
---
body
EOF

    # 3: BOTH arc_id and legacy tag (transitional dual-source)
    cat > "$PROJECT_ROOT/.tasks/completed/T-9003-both.md" <<'EOF'
---
id: T-9003
arc_id: test-arc-x
tags: [arc:test-arc-x, build]
---
body
EOF

    # 4: different arc (negative — must NOT match test-arc-x)
    cat > "$PROJECT_ROOT/.tasks/active/T-9004-other-arc.md" <<'EOF'
---
id: T-9004
arc_id: some-other-arc
tags: [arc:some-other-arc]
---
body
EOF

    # 5: no arc membership at all
    cat > "$PROJECT_ROOT/.tasks/active/T-9005-no-arc.md" <<'EOF'
---
id: T-9005
tags: [build]
---
body
EOF

    # 6: body string contains "arc:test-arc-x" but frontmatter does NOT —
    #    body-only mention must NOT match task_has_arc_membership.
    cat > "$PROJECT_ROOT/.tasks/active/T-9006-body-mention.md" <<'EOF'
---
id: T-9006
tags: [build]
---
This task references arc:test-arc-x in the body but no frontmatter membership.
EOF

    # Source the shared lib.
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # shellcheck disable=SC1090
    . "$REPO_ROOT/lib/arc_membership.sh"
}

teardown() {
    [ -n "${PROJECT_ROOT:-}" ] && [ -d "$PROJECT_ROOT" ] && rm -rf "$PROJECT_ROOT"
}

@test "arc_tasks_with_arc_id returns only arc_id-frontmatter matches" {
    run arc_tasks_with_arc_id "test-arc-x"
    [ "$status" -eq 0 ]
    # Should match T-9002 (arc_id only) and T-9003 (both). NOT T-9001
    # (legacy tag only, no arc_id field).
    [[ "$output" == *"T-9002"* ]]
    [[ "$output" == *"T-9003"* ]]
    [[ "$output" != *"T-9001"* ]]
    [[ "$output" != *"T-9004"* ]]
    [[ "$output" != *"T-9005"* ]]
}

@test "arc_tasks_with_tag returns only legacy-tag matches" {
    run arc_tasks_with_tag "arc:test-arc-x"
    [ "$status" -eq 0 ]
    # Should match T-9001 (legacy tag only) and T-9003 (both). NOT T-9002.
    [[ "$output" == *"T-9001"* ]]
    [[ "$output" == *"T-9003"* ]]
    [[ "$output" != *"T-9002"* ]]
    [[ "$output" != *"T-9004"* ]]
}

@test "arc_tasks_for returns union, deduplicated and sorted" {
    run arc_tasks_for "test-arc-x"
    [ "$status" -eq 0 ]
    # Expect exactly T-9001, T-9002, T-9003 — each once.
    count=$(printf '%s\n' "$output" | grep -cE '^T-900[123]$')
    [ "$count" -eq 3 ]
    # Sorted output
    expected=$'T-9001\nT-9002\nT-9003'
    [ "$output" = "$expected" ]
}

@test "arc_tasks_for returns empty for unknown slug" {
    run arc_tasks_for "no-such-arc"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "task_has_arc_membership: arc_id only → 0" {
    run task_has_arc_membership "$PROJECT_ROOT/.tasks/active/T-9002-arc-id-only.md"
    [ "$status" -eq 0 ]
}

@test "task_has_arc_membership: legacy tag only → 0" {
    run task_has_arc_membership "$PROJECT_ROOT/.tasks/active/T-9001-legacy-only.md"
    [ "$status" -eq 0 ]
}

@test "task_has_arc_membership: both → 0" {
    run task_has_arc_membership "$PROJECT_ROOT/.tasks/completed/T-9003-both.md"
    [ "$status" -eq 0 ]
}

@test "task_has_arc_membership: neither → 1" {
    run task_has_arc_membership "$PROJECT_ROOT/.tasks/active/T-9005-no-arc.md"
    [ "$status" -eq 1 ]
}

@test "task_has_arc_membership: body-only arc: mention → 1 (frontmatter-scoped)" {
    run task_has_arc_membership "$PROJECT_ROOT/.tasks/active/T-9006-body-mention.md"
    [ "$status" -eq 1 ]
}

@test "task_has_arc_membership: missing file → 1" {
    run task_has_arc_membership "$PROJECT_ROOT/.tasks/active/T-NOPE.md"
    [ "$status" -eq 1 ]
}

@test "arc_tasks_for empty slug returns empty (no glob blowup)" {
    run arc_tasks_for ""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "guard: re-sourcing the lib does not redefine functions" {
    # Source twice — second time must be a no-op (idempotent guard).
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # shellcheck disable=SC1090
    . "$REPO_ROOT/lib/arc_membership.sh"
    run arc_tasks_for "test-arc-x"
    [ "$status" -eq 0 ]
    count=$(printf '%s\n' "$output" | grep -cE '^T-')
    [ "$count" -eq 3 ]
}
