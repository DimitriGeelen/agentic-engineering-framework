#!/usr/bin/env bats
# T-1398 (T-1268 B2): fw doctor surfaces unresolved pending-updates entries

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TMPREPO=$(mktemp -d)
    cd "$TMPREPO"
    git init -q
    git config user.email "test@test"
    git config user.name "test"
    mkdir -p .context/working .context/audits .context/monitors .context/approvals .context/project .tasks/active .tasks/completed .tasks/templates
    touch .tasks/templates/zzz-default.md
    for d in working audits monitors approvals project; do
        touch ".context/$d/.gitkeep"
    done
    echo "real" > README.md
    git add -A
    git commit -q -m "T-1398: baseline"
}

teardown() {
    cd /
    rm -rf "$TMPREPO"
}

@test "fw doctor emits no pending warning when registry is absent" {
    cd "$TMPREPO"
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        run bash "$FW" doctor
    # doctor may exit 1 if other things are FAIL in the barebones tmprepo — that's fine
    [[ "$output" != *"Pending-updates registry"* ]]
}

@test "fw doctor warns when one or more entries are pending" {
    cd "$TMPREPO"
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        bash "$FW" pending register --command "echo a" --reason "need human action" --task T-1398 >/dev/null
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        run bash "$FW" doctor
    [[ "$output" == *"Pending-updates registry: 1 unresolved entry"* ]]
    [[ "$output" == *"Run: fw pending list"* ]]
}

@test "fw doctor does not warn when all entries are resolved" {
    cd "$TMPREPO"
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        bash "$FW" pending register --command "echo a" --reason "r" --task T-1398 >/dev/null
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        bash "$FW" pending resolve U-001 --note "done" >/dev/null
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        run bash "$FW" doctor
    [[ "$output" != *"Pending-updates registry:"* ]]
}
