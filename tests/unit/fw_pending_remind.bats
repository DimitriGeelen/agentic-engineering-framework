#!/usr/bin/env bats
# T-1399 (T-1268 B4): fw pending remind

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
    git commit -q -m "T-1399: baseline"
}

teardown() {
    cd /
    rm -rf "$TMPREPO"
}

@test "fw pending remind: no registry file -> clean exit" {
    cd "$TMPREPO"
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        run bash "$FW" pending remind
    [ "$status" -eq 0 ]
    [[ "$output" == *"No pending-updates registry"* ]]
}

@test "fw pending remind: fresh entry (<24h) -> 0 stale" {
    cd "$TMPREPO"
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        bash "$FW" pending register --command "echo a" --reason "r" --task T-1399 >/dev/null
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        run bash "$FW" pending remind
    [ "$status" -eq 0 ]
    [[ "$output" == *"No stale pending entries"* ]]
}

@test "fw pending remind: threshold=0 reports all pending entries" {
    cd "$TMPREPO"
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        bash "$FW" pending register --command "echo a" --reason "need human" --task T-1399 >/dev/null
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= FW_PENDING_REMIND_STALE_HOURS=0 \
        run bash "$FW" pending remind
    [ "$status" -eq 0 ]
    [[ "$output" == *"Stale pending entries"* ]]
    [[ "$output" == *"U-001"* ]]
    [[ "$output" == *"need human"* ]]
    [[ "$output" == *"Total: 1"* ]]
}

@test "fw pending remind: resolved entries never reported even at threshold=0" {
    cd "$TMPREPO"
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        bash "$FW" pending register --command "echo a" --reason "r" --task T-1399 >/dev/null
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        bash "$FW" pending resolve U-001 --note "done" >/dev/null
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= FW_PENDING_REMIND_STALE_HOURS=0 \
        run bash "$FW" pending remind
    [ "$status" -eq 0 ]
    [[ "$output" == *"No stale pending entries"* ]]
}

@test "fw pending remind: entry with back-dated created is reported" {
    cd "$TMPREPO"
    mkdir -p .context/working
    cat > .context/working/pending-updates.yaml <<'EOF'
pending_updates:
  - id: U-001
    command: echo a
    reason: aged thing
    task: T-1399
    host: local
    agent: test
    created: '2020-01-01T00:00:00Z'
    status: pending
    resolved_date: null
    resolution_note: null
EOF
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        run bash "$FW" pending remind
    [ "$status" -eq 0 ]
    [[ "$output" == *"U-001"* ]]
    [[ "$output" == *"aged thing"* ]]
}
