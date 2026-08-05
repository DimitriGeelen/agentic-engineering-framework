#!/usr/bin/env bats
# T-2815: the T-532 onboarding gate (check-active-task.sh) must exclude
# owner:human tasks from its blocking scan, since an agent session can never
# satisfy their exit condition (fw inception decide refuses under
# $CLAUDECODE=1; agents must never tick a ### Human AC). An owner:agent
# onboarding task must still block, unchanged (regression guard).

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
    [ -f "$HOOK" ] || skip "hook script not found"

    ROOT="$(mktemp -d)"
    mkdir -p "$ROOT/.context/working" "$ROOT/.tasks/active"
    echo "session_id: S-test" > "$ROOT/.context/working/session.yaml"
    echo "version: test" > "$ROOT/.framework.yaml"
    cat > "$ROOT/.context/working/focus.yaml" <<YAML
current_task: T-9301
focus_session: S-test
priorities: []
YAML

    export PROJECT_ROOT="$ROOT"
    export CLAUDECODE=1
}

teardown() {
    rm -rf "$ROOT" 2>/dev/null
}

create_current_task() {
    cat > "$ROOT/.tasks/active/T-9301-x.md" <<MD
---
id: T-9301
name: "current non-onboarding task"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
---
# T-9301
## Acceptance Criteria
### Agent
- [ ] Real AC one

## Verification
MD
}

create_onboarding_task() {  # $1=id  $2=owner  $3=status
    cat > "$ROOT/.tasks/active/${1}-onb.md" <<MD
---
id: $1
name: "onboarding task"
status: $3
workflow_type: inception
owner: $2
horizon: now
tags: [onboarding, inception]
---
# $1
## Acceptance Criteria
### Human
- [ ] [REVIEW] taste check
### Agent
- [ ] fw inception decide $1 go
MD
}

run_hook() {
    local file_path="$1"
    local input
    input=$(python3 -c "
import json, sys
print(json.dumps({'tool_name': 'Write', 'tool_input': {'file_path': sys.argv[1], 'content': 'x'}, 'cwd': sys.argv[2]}))
" "$file_path" "$ROOT")
    run bash "$HOOK" <<< "$input"
}

@test "owner:human incomplete onboarding task does NOT block other work" {
    create_current_task
    create_onboarding_task T-9302 human captured
    run_hook "$ROOT/src/other-file.py"
    [ "$status" -eq 0 ]
}

@test "owner:agent incomplete onboarding task DOES block other work (unchanged)" {
    create_current_task
    create_onboarding_task T-9303 agent captured
    run_hook "$ROOT/src/other-file.py"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "Onboarding tasks incomplete"
    echo "$output" | grep -q "T-9303"
}

@test "mixed set: owner:human exempted, owner:agent still blocks and is the only one named" {
    create_current_task
    create_onboarding_task T-9304 human captured
    create_onboarding_task T-9305 agent captured
    run_hook "$ROOT/src/other-file.py"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "T-9305"
    ! echo "$output" | grep -q "T-9304"
}

@test "all onboarding tasks exempt or completed → marker written, work allowed" {
    create_current_task
    create_onboarding_task T-9306 human captured
    run_hook "$ROOT/src/other-file.py"
    [ "$status" -eq 0 ]
    [ -f "$ROOT/.context/working/.onboarding-complete" ]
}
