#!/usr/bin/env bats
# T-1279: Concurrent fw work-on must allocate distinct task IDs.
#
# Prior bug: generate_id() read max_id, then (later) wrote the file. N parallel
# invocations all observed the same max_id and all wrote T-${max+1}.
# Fix: keylock around the read-compute-write sequence.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    # Build a minimal test project
    PROJECT="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJECT/.tasks/active" "$PROJECT/.tasks/completed" \
             "$PROJECT/.tasks/templates" "$PROJECT/.context/working" \
             "$PROJECT/.context/locks"
    touch "$PROJECT/.framework.yaml"
    # Copy the default task template (required by create-task.sh)
    cp "$FRAMEWORK_ROOT/.tasks/templates/default.md" "$PROJECT/.tasks/templates/default.md"
    # Seed one existing task so max_id starts at 100
    cat > "$PROJECT/.tasks/active/T-100-seed.md" <<EOF
---
id: T-100
name: "Seed"
status: captured
---
EOF
    export PROJECT_ROOT="$PROJECT"
    export TASKS_DIR="$PROJECT/.tasks"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "task-id race: 5 parallel create-task.sh invocations produce 5 distinct IDs" {
    # Launch 5 parallel creates
    for i in 1 2 3 4 5; do
        (
            PROJECT_ROOT="$PROJECT" TASKS_DIR="$PROJECT/.tasks" \
                "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" \
                --name "race-test-$i" \
                --description "parallel race test $i" \
                --type build --owner agent \
                >/dev/null 2>&1
        ) &
    done
    wait

    # Collect IDs from created files (exclude the seed)
    local ids
    ids=$(ls "$PROJECT/.tasks/active/" | grep -E '^T-[0-9]+-race-test-' | \
          grep -oE 'T-[0-9]+' | sort -u)
    local count
    count=$(echo "$ids" | wc -l)
    echo "Got IDs: $ids" >&2
    [ "$count" -eq 5 ]

    # Also: every created file should have a matching id: in frontmatter
    for f in "$PROJECT/.tasks/active/"*race-test-*.md; do
        local filename_id file_id
        filename_id=$(basename "$f" | grep -oE 'T-[0-9]+')
        file_id=$(grep -m1 '^id:' "$f" | awk '{print $2}')
        [ "$filename_id" = "$file_id" ]
    done
}

@test "task-id race: 10 parallel create-task.sh invocations produce 10 distinct IDs" {
    for i in $(seq 1 10); do
        (
            PROJECT_ROOT="$PROJECT" TASKS_DIR="$PROJECT/.tasks" \
                "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" \
                --name "race-$i" \
                --description "race $i" \
                --type build --owner agent \
                >/dev/null 2>&1
        ) &
    done
    wait

    local count
    count=$(ls "$PROJECT/.tasks/active/" | grep -E '^T-[0-9]+-race-' | \
            grep -oE 'T-[0-9]+' | sort -u | wc -l)
    [ "$count" -eq 10 ]
}

@test "task-id race: keylock source present in create-task.sh" {
    grep -q 'keylock.sh' "$FRAMEWORK_ROOT/agents/task-create/create-task.sh"
    grep -q 'keylock_acquire "task-id-allocation"' "$FRAMEWORK_ROOT/agents/task-create/create-task.sh"
}
