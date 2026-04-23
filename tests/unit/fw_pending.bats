#!/usr/bin/env bats
# T-1397 (T-1268 B1): fw pending registry — register/list/resolve

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TMPREPO=$(mktemp -d)
    cd "$TMPREPO"
    git init -q
    git config user.email "test@test"
    git config user.name "test"
    mkdir -p .context/working .tasks/active .tasks/completed .tasks/templates
    touch .tasks/templates/zzz-default.md
    echo "real" > README.md
    git add -A
    git commit -q -m "T-1397: baseline"
}

teardown() {
    cd /
    rm -rf "$TMPREPO"
}

@test "fw pending register creates file on first call and returns U-001" {
    cd "$TMPREPO"
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        run bash "$FW" pending register \
            --command "echo hello" \
            --reason "smoke test" \
            --task T-1397
    [ "$status" -eq 0 ]
    [[ "$output" == *"U-001"* ]]
    [ -f "$TMPREPO/.context/working/pending-updates.yaml" ]
    grep -q "pending_updates:" "$TMPREPO/.context/working/pending-updates.yaml"
}

@test "fw pending register assigns sequential IDs" {
    cd "$TMPREPO"
    for i in 1 2 3; do
        PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
            run bash "$FW" pending register --command "echo $i" --reason "r$i" --task T-1397
        [ "$status" -eq 0 ]
    done
    grep -c "id: U-" "$TMPREPO/.context/working/pending-updates.yaml" | grep -q "^3$"
    grep -q "id: U-001" "$TMPREPO/.context/working/pending-updates.yaml"
    grep -q "id: U-002" "$TMPREPO/.context/working/pending-updates.yaml"
    grep -q "id: U-003" "$TMPREPO/.context/working/pending-updates.yaml"
}

@test "fw pending list shows pending entries by default" {
    cd "$TMPREPO"
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        bash "$FW" pending register --command "echo a" --reason "r" --task T-1397 >/dev/null
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        run bash "$FW" pending list
    [ "$status" -eq 0 ]
    [[ "$output" == *"U-001"* ]]
    [[ "$output" == *"[pending]"* ]]
    [[ "$output" == *"echo a"* ]]
}

@test "fw pending resolve flips status and stamps resolved_date" {
    cd "$TMPREPO"
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        bash "$FW" pending register --command "echo a" --reason "r" --task T-1397 >/dev/null
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        run bash "$FW" pending resolve U-001 --note "done by human"
    [ "$status" -eq 0 ]
    grep -q "status: resolved" "$TMPREPO/.context/working/pending-updates.yaml"
    grep -q "resolution_note: done by human" "$TMPREPO/.context/working/pending-updates.yaml"
    grep -Eq "resolved_date: '?20" "$TMPREPO/.context/working/pending-updates.yaml"
}

@test "fw pending list filter: pending excludes resolved, all includes both" {
    cd "$TMPREPO"
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        bash "$FW" pending register --command "echo a" --reason "ra" --task T-1397 >/dev/null
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        bash "$FW" pending register --command "echo b" --reason "rb" --task T-1397 >/dev/null
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        bash "$FW" pending resolve U-001 --note "finished" >/dev/null

    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        run bash "$FW" pending list
    [ "$status" -eq 0 ]
    [[ "$output" != *"U-001"* ]]
    [[ "$output" == *"U-002"* ]]

    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        run bash "$FW" pending list --status all
    [ "$status" -eq 0 ]
    [[ "$output" == *"U-001"* ]]
    [[ "$output" == *"U-002"* ]]
    [[ "$output" == *"[resolved]"* ]]
    [[ "$output" == *"[pending]"* ]]
}

@test "fw pending resolve on unknown id returns error" {
    cd "$TMPREPO"
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        bash "$FW" pending register --command "echo a" --reason "r" --task T-1397 >/dev/null
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        run bash "$FW" pending resolve U-999
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "fw pending register requires --command, --reason, --task" {
    cd "$TMPREPO"
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        run bash "$FW" pending register --command "echo a"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}
