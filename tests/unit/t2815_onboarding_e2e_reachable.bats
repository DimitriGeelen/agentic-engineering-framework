#!/usr/bin/env bats
# T-2815 AC1 — end-to-end proof: a real `fw init` seeded project reaches a
# clean non-onboarding Write under $CLAUDECODE=1 once every owner:agent
# onboarding task is work-completed, EVEN THOUGH T-002 (owner:human,
# workflow_type: inception) never reaches work-completed. Before this task's
# fix, T-002's presence alone (any status other than work-completed) blocked
# the onboarding-gate scan in check-active-task.sh unconditionally — this
# test pins the seeded set's exit condition as agent-reachable per T-2815
# AC1's exact wording ("a clean run from fw init to a non-onboarding Write
# that succeeds").
#
# Mirrors tests/unit/greenfield_seed_audit_prototype.bats's seeded_run
# pattern: seed via the framework's own `fw init`, then operate against the
# seeded project's own vendored fw in a scrubbed env.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-onboarding-e2e-XXXXXX)"
    export FRAMEWORK_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "T-2815 AC1: seeded set reaches agent-reachable exit condition with T-002 untouched" {
    local proj="$TEST_TEMP_DIR/proj"
    mkdir -p "$proj"

    run "$FRAMEWORK_ROOT/bin/fw" init "$proj"
    [ "$status" -eq 0 ]

    # Premise: T-002 is seeded owner:human, workflow_type:inception, still captured.
    grep -q "^owner: human" "$proj/.tasks/active/T-002-"*.md
    grep -q "^workflow_type: inception" "$proj/.tasks/active/T-002-"*.md
    grep -q "^status: captured" "$proj/.tasks/active/T-002-"*.md

    # Simulate the agent completing every owner:agent onboarding task
    # (T-001, T-003, T-004, T-005) via direct status flip — the point under
    # test is the onboarding-gate SCAN, not the full completion machinery
    # each of those tasks separately exercises.
    for id in T-001 T-003 T-004 T-005; do
        f=$(ls "$proj/.tasks/active/${id}-"*.md)
        sed -i 's/^status:.*/status: work-completed/' "$f"
    done

    # T-002 remains untouched — this is the crux of the proof: the exit
    # condition is reachable WITHOUT T-002 ever reaching work-completed.
    grep -q "^status: captured" "$proj/.tasks/active/T-002-"*.md

    # Simulate the PreToolUse gate Claude Code fires on a Write to a
    # non-onboarding source file, under agent control, from a clean env
    # (no inherited PROJECT_ROOT — same fresh_run discipline as
    # upgrade_fresh_machine_simulation.bats / T-2703).
    local input
    input=$(python3 -c "
import json, sys
print(json.dumps({
    'tool_name': 'Write',
    'tool_input': {'file_path': sys.argv[1] + '/src/auth.py', 'content': 'x'},
    'cwd': sys.argv[1],
}))
" "$proj")

    # Focus must point at a non-onboarding started-work task for the hook's
    # earlier status-validation branch to pass before it reaches the
    # onboarding-gate check.
    mkdir -p "$proj/.tasks/active"
    cat > "$proj/.tasks/active/T-9401-work.md" <<MD
---
id: T-9401
name: "Add authentication"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
---
# T-9401
## Acceptance Criteria
### Agent
- [ ] Real AC one

## Verification
MD
    local session_id
    session_id=$(grep "^session_id:" "$proj/.context/working/session.yaml" | sed 's/session_id:[[:space:]]*//')
    cat > "$proj/.context/working/focus.yaml" <<YAML
current_task: T-9401
focus_session: $session_id
priorities: []
YAML

    run env -i \
        PATH="/usr/local/bin:/usr/bin:/bin" \
        HOME="$TEST_TEMP_DIR/home" \
        CLAUDECODE=1 \
        bash -c "echo '$input' | '$proj/.agentic-framework/agents/context/check-active-task.sh'"
    echo "hook exit: $status"
    echo "$output"
    [ "$status" -eq 0 ]
}
