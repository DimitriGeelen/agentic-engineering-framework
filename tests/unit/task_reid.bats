#!/usr/bin/env bats
# T-1367: fw task reid — safely rename a task's ID.
#
# Handles the G-052 duplicate-ID repair workflow: renames the file AND updates
# the `id:` frontmatter atomically. Refuses when NEW-ID already exists.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJECT="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJECT/.tasks/active" "$PROJECT/.tasks/completed" "$PROJECT/.context/working"
    touch "$PROJECT/.framework.yaml"
    # Seed one task
    cat > "$PROJECT/.tasks/active/T-500-hello-world.md" <<'EOF'
---
id: T-500
name: "Hello world"
status: started-work
workflow_type: build
---

# T-500: Hello world

## Updates

### 2026-01-01T00:00:00Z — created
EOF
    export PROJECT_ROOT="$PROJECT"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "task reid: success case — renames file and updates frontmatter" {
    cd "$PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" task reid T-500 T-999
    [ "$status" -eq 0 ]

    # Old file gone
    [ ! -f "$PROJECT/.tasks/active/T-500-hello-world.md" ]
    # New file exists with correct slug preserved
    [ -f "$PROJECT/.tasks/active/T-999-hello-world.md" ]

    # Frontmatter `id:` updated
    grep -qE "^id: T-999\s*$" "$PROJECT/.tasks/active/T-999-hello-world.md"
    # Old id: is gone
    if grep -qE "^id: T-500\s*$" "$PROJECT/.tasks/active/T-999-hello-world.md"; then false; fi
    # Update entry appended
    grep -q "reid \[fw-task\]" "$PROJECT/.tasks/active/T-999-hello-world.md"
    grep -q "T-500 → T-999" "$PROJECT/.tasks/active/T-999-hello-world.md"
}

@test "task reid: errors when OLD-ID not found" {
    cd "$PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" task reid T-777 T-888
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi "No task file found"
}

@test "task reid: errors when NEW-ID already exists" {
    # Seed a second task
    cat > "$PROJECT/.tasks/active/T-501-collision.md" <<'EOF'
---
id: T-501
name: "Collision"
status: captured
---
EOF
    cd "$PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" task reid T-500 T-501
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi "already exists"

    # Original files intact
    [ -f "$PROJECT/.tasks/active/T-500-hello-world.md" ]
    [ -f "$PROJECT/.tasks/active/T-501-collision.md" ]
}

@test "task reid: errors on invalid ID format" {
    cd "$PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" task reid 500 T-999
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi "T-NNNN"
}

@test "task reid: works for tasks in completed/" {
    mv "$PROJECT/.tasks/active/T-500-hello-world.md" \
       "$PROJECT/.tasks/completed/T-500-hello-world.md"
    cd "$PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" task reid T-500 T-700
    [ "$status" -eq 0 ]
    [ -f "$PROJECT/.tasks/completed/T-700-hello-world.md" ]
    [ ! -f "$PROJECT/.tasks/completed/T-500-hello-world.md" ]
    grep -qE "^id: T-700\s*$" "$PROJECT/.tasks/completed/T-700-hello-world.md"
}

@test "task reid: missing args prints usage" {
    cd "$PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" task reid
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi "Usage: fw task reid"
}
