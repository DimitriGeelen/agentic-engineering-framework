#!/usr/bin/env bats
# T-4433: fw doctor surfaces task_debt.py's 'unparsed: N (files)' stderr (T-4430)

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
    git commit -q -m "T-4433: baseline"
}

teardown() {
    cd /
    rm -rf "$TMPREPO"
}

@test "doctor names a task whose last_update is unparseable" {
    cd "$TMPREPO"
    printf -- '---\nid: T-9001\nname: "bad stamp"\nstatus: started-work\nlast_update: not-a-date\n---\n' \
        > .tasks/active/T-9001-bad-stamp.md
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= run bash "$FW" doctor
    [[ "$output" == *"unparsed: 1"* ]]
    [[ "$output" == *"T-9001-bad-stamp.md"* ]]
}

@test "doctor prints no unparsed line when every last_update parses" {
    cd "$TMPREPO"
    printf -- '---\nid: T-9002\nname: "ok"\nstatus: started-work\nlast_update: 2999-01-01T00:00:00Z\n---\n' \
        > .tasks/active/T-9002-ok.md
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= run bash "$FW" doctor
    [[ "$output" != *"unparsed:"* ]]
    # T-4436: doctor must run to its summary. Without this, a doctor that died at
    # the task-debt check also printed no 'unparsed:' line and passed.
    [[ "$output" == *"Project $TMPREPO"* ]]
}
