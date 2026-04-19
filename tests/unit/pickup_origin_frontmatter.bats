#!/usr/bin/env bats
# Unit tests for G-047 mitigation — pickup_create_inception injects
# source_task_id_in_origin + source_project_in_origin into new task frontmatter.
# Origin: T-1340

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_PROJECT=$(mktemp -d)
    mkdir -p "$TMP_PROJECT/.tasks/active" "$TMP_PROJECT/.tasks/completed" "$TMP_PROJECT/.tasks/templates"
    mkdir -p "$TMP_PROJECT/.context/pickup/inbox"
    export PROJECT_ROOT="$TMP_PROJECT"

    # Copy the inception template from the real framework so fw task create finds it
    cp "$FRAMEWORK_ROOT/.tasks/templates/inception.md" "$TMP_PROJECT/.tasks/templates/"
    cp "$FRAMEWORK_ROOT/.tasks/templates/default.md" "$TMP_PROJECT/.tasks/templates/"
    cp "$FRAMEWORK_ROOT/.tasks/templates/build.md" "$TMP_PROJECT/.tasks/templates/" 2>/dev/null || true

    # shellcheck source=lib/pickup.sh
    source "$FRAMEWORK_ROOT/lib/pickup.sh"
}

teardown() {
    rm -rf "$TMP_PROJECT"
}

write_envelope() {
    local file="$1" project="$2" task="$3" summary="${4:-Test pickup}"
    if [ -n "$task" ]; then
        cat > "$file" <<EOF
type: learning
source:
  project: "$project"
  task_id: "$task"
  summary: "$summary"
EOF
    else
        cat > "$file" <<EOF
type: learning
source:
  project: "$project"
  summary: "$summary"
EOF
    fi
}

@test "envelope with source_task → frontmatter gets source_task_id_in_origin and source_project_in_origin" {
    write_envelope "$TMP_PROJECT/.context/pickup/inbox/p1.yaml" "remote-project" "T-999" "My summary"
    run pickup_create_inception "$TMP_PROJECT/.context/pickup/inbox/p1.yaml"
    [ "$status" -eq 0 ]
    # find the newly-created task file
    new_file=$(find "$TMP_PROJECT/.tasks/active" -name "T-*.md" | head -1)
    [ -n "$new_file" ]
    grep -q "^source_task_id_in_origin: T-999$" "$new_file"
    grep -q "^source_project_in_origin: \"remote-project\"$" "$new_file"
}

@test "envelope without source_task → no frontmatter injection, task still created" {
    write_envelope "$TMP_PROJECT/.context/pickup/inbox/p2.yaml" "remote-project" "" "No task ref"
    run pickup_create_inception "$TMP_PROJECT/.context/pickup/inbox/p2.yaml"
    [ "$status" -eq 0 ]
    new_file=$(find "$TMP_PROJECT/.tasks/active" -name "T-*.md" | head -1)
    [ -n "$new_file" ]
    # No injected fields
    ! grep -q "^source_task_id_in_origin:" "$new_file"
    ! grep -q "^source_project_in_origin:" "$new_file"
}
