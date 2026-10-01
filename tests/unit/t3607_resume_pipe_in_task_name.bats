#!/usr/bin/env bats
# T-3607: resume.sh packed get_active_tasks() as "count|tasks|human_count|human_tasks"
# and split it with IFS='|'. An active task whose NAME contains '|' shifted the
# fields, so human_count received task-name text and `resume status` died in
# arithmetic. Runs against a fixture project, not the live corpus, so it does
# not depend on whatever names happen to be active today.

load ../test_helper

RESUME="$FRAMEWORK_ROOT/agents/resume/resume.sh"

setup() {
    FIX="$(mktemp -d)"
    mkdir -p "$FIX/.tasks/active" "$FIX/.tasks/completed" "$FIX/.context/working" "$FIX/.context/handovers"
    git -C "$FIX" init -q
    git -C "$FIX" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "T-0001: subject with a | pipe"
    cat > "$FIX/.tasks/active/T-0001-pipe.md" <<'EOF'
---
id: T-0001
name: "count tests: ls tests/unit/*.bats | wc -l"
status: started-work
owner: agent
---
EOF
    cat > "$FIX/.tasks/active/T-0002-human.md" <<'EOF'
---
id: T-0002
name: "awaiting review | with pipe"
status: work-completed
owner: human
---
EOF
    unset TASKS_DIR CONTEXT_DIR _FW_PATHS_DERIVED_BY
    export PROJECT_ROOT="$FIX"
}

teardown() {
    rm -rf "$FIX"
}

@test "resume status survives a pipe in an active task name" {
    run "$RESUME" status
    [ "$status" -eq 0 ]
    [[ "$output" != *"syntax error"* ]]
    [[ "$output" == *"2 total (1 actionable, 1 awaiting human)"* ]]
    [[ "$output" == *"T-0001: count tests: ls tests/unit/*.bats | wc -l"* ]]
}

@test "resume quick survives a pipe in an active task name" {
    run "$RESUME" quick
    [ "$status" -eq 0 ]
    [[ "$output" != *"syntax error"* ]]
}
