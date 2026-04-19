#!/usr/bin/env bats
# Unit tests for G-047 mitigation — pickup_inject_origin_frontmatter
# adds source_task_id_in_origin + source_project_in_origin to frontmatter.
# Origin: T-1340 (initial), T-1342 (extracted helper for test isolation).

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP=$(mktemp -d)
    # shellcheck source=lib/pickup.sh
    source "$FRAMEWORK_ROOT/lib/pickup.sh"
}

teardown() {
    rm -rf "$TMP"
}

write_task_fixture() {
    local file="$1"
    cat > "$file" <<'EOF'
---
id: T-9999
name: "fixture task"
description: >
  fixture
status: captured
workflow_type: inception
owner: agent
horizon: next
tags: [pickup, learning]
related_tasks: []
created: 2026-04-19T00:00:00Z
last_update: 2026-04-19T00:00:00Z
date_finished: null
---

# T-9999: fixture task
EOF
}

@test "injects source_task_id_in_origin and source_project_in_origin" {
    write_task_fixture "$TMP/task.md"
    run pickup_inject_origin_frontmatter "$TMP/task.md" "T-500" "remote-project"
    [ "$status" -eq 0 ]
    grep -q "^source_task_id_in_origin: T-500$" "$TMP/task.md"
    grep -q "^source_project_in_origin: \"remote-project\"$" "$TMP/task.md"
}

@test "idempotent — second call does not duplicate fields" {
    write_task_fixture "$TMP/task.md"
    pickup_inject_origin_frontmatter "$TMP/task.md" "T-500" "remote-project"
    pickup_inject_origin_frontmatter "$TMP/task.md" "T-500" "remote-project"
    count=$(grep -c "^source_task_id_in_origin:" "$TMP/task.md")
    [ "$count" -eq 1 ]
}

@test "preserves existing frontmatter and body" {
    write_task_fixture "$TMP/task.md"
    pickup_inject_origin_frontmatter "$TMP/task.md" "T-500" "remote-project"
    grep -q "^id: T-9999$" "$TMP/task.md"
    grep -q "^name: \"fixture task\"$" "$TMP/task.md"
    grep -q "^# T-9999: fixture task$" "$TMP/task.md"
}

@test "missing file returns non-zero" {
    run pickup_inject_origin_frontmatter "$TMP/does-not-exist.md" "T-500" "remote-project"
    [ "$status" -ne 0 ]
}
