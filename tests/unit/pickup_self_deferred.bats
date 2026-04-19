#!/usr/bin/env bats
# Unit tests for G-046 mitigation — pickup_is_self_completed
# Origin: T-1339

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_PROJECT=$(mktemp -d)
    mkdir -p "$TMP_PROJECT/.tasks/active" "$TMP_PROJECT/.tasks/completed"
    mkdir -p "$TMP_PROJECT/.context/pickup/inbox"
    export PROJECT_ROOT="$TMP_PROJECT"
    export LOCAL_NAME=$(basename "$TMP_PROJECT")
    # shellcheck source=lib/pickup.sh
    source "$FRAMEWORK_ROOT/lib/pickup.sh"
}

teardown() {
    rm -rf "$TMP_PROJECT"
}

write_envelope() {
    local file="$1" project="$2" task="$3"
    cat > "$file" <<EOF
type: learning
source:
  project: "$project"
  task_id: "$task"
  summary: "test summary"
EOF
}

@test "self + completed → is_self_completed returns 0 (defer)" {
    touch "$TMP_PROJECT/.tasks/completed/T-999-done-task.md"
    write_envelope "$TMP_PROJECT/.context/pickup/inbox/p1.yaml" "$LOCAL_NAME" "T-999"
    run pickup_is_self_completed "$TMP_PROJECT/.context/pickup/inbox/p1.yaml"
    [ "$status" -eq 0 ]
}

@test "self + active (not completed) → returns 1 (proceed)" {
    touch "$TMP_PROJECT/.tasks/active/T-500-still-active.md"
    write_envelope "$TMP_PROJECT/.context/pickup/inbox/p2.yaml" "$LOCAL_NAME" "T-500"
    run pickup_is_self_completed "$TMP_PROJECT/.context/pickup/inbox/p2.yaml"
    [ "$status" -eq 1 ]
}

@test "cross-project → returns 1 (proceed)" {
    touch "$TMP_PROJECT/.tasks/completed/T-123-done.md"
    write_envelope "$TMP_PROJECT/.context/pickup/inbox/p3.yaml" "other-project" "T-123"
    run pickup_is_self_completed "$TMP_PROJECT/.context/pickup/inbox/p3.yaml"
    [ "$status" -eq 1 ]
}

@test "missing task_id → returns 1 (proceed)" {
    cat > "$TMP_PROJECT/.context/pickup/inbox/p4.yaml" <<EOF
type: learning
source:
  project: "$LOCAL_NAME"
  summary: "no task ref"
EOF
    run pickup_is_self_completed "$TMP_PROJECT/.context/pickup/inbox/p4.yaml"
    [ "$status" -eq 1 ]
}
