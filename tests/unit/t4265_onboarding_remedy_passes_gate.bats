#!/usr/bin/env bats
# T-4265: the T-532 onboarding gate advertises `fw onboarding skip` as the way
# out, so its own bootstrap exemption (check-active-task.sh) must admit it.
# General rule (L-597): every remedy a block message prints must pass the gate.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
    ROOT="$(mktemp -d)"
    mkdir -p "$ROOT/.context/working" "$ROOT/.tasks/active"
    echo "session_id: S-test" > "$ROOT/.context/working/session.yaml"
    echo "version: test" > "$ROOT/.framework.yaml"
    printf 'current_task: T-9401\nfocus_session: S-test\npriorities: []\n' > "$ROOT/.context/working/focus.yaml"
    cat > "$ROOT/.tasks/active/T-9401-x.md" <<MD
---
id: T-9401
name: "current"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
---
MD
    cat > "$ROOT/.tasks/active/T-9402-onb.md" <<MD
---
id: T-9402
name: "onboarding"
status: captured
workflow_type: inception
owner: agent
horizon: now
tags: [onboarding]
---
MD
    export PROJECT_ROOT="$ROOT" CLAUDECODE=1
}

teardown() { rm -rf "$ROOT" 2>/dev/null; }

hook_write() {
    run bash "$HOOK" <<< "$(python3 -c "
import json,sys
print(json.dumps({'tool_name':'Write','tool_input':{'file_path':sys.argv[1]+'/src/a.py','content':'x'},'cwd':sys.argv[1]}))" "$ROOT")"
}

hook_bash() {
    run bash "$HOOK" <<< "$(python3 -c "
import json,sys
print(json.dumps({'tool_name':'Bash','tool_input':{'command':sys.argv[1]},'cwd':sys.argv[2]}))" "$1" "$ROOT")"
}

@test "onboarding skip/status admitted under every fw path spelling, focus null" {
    : > "$ROOT/.context/working/focus.yaml"
    for fw in "fw" "bin/fw" ".agentic-framework/bin/fw" "/abs/path/bin/fw"; do
        for sub in skip status; do
            hook_bash "$fw onboarding $sub"
            [ "$status" -eq 0 ] || { echo "blocked: $fw onboarding $sub"; echo "$output"; false; }
        done
    done
}

@test "every remedy printed by the onboarding block passes the gate" {
    hook_write
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "Onboarding tasks incomplete"
    remedies=$(echo "$output" | grep -E '^  [^ ]*fw (work-on|onboarding) ')
    [ -n "$remedies" ]
    echo "$remedies" | grep -q "onboarding skip"
    : > "$ROOT/.context/working/focus.yaml"
    while IFS= read -r cmd; do
        cmd="${cmd#"${cmd%%[![:space:]]*}"}"
        hook_bash "$cmd"
        [ "$status" -eq 0 ] || { echo "remedy blocked: $cmd"; echo "$output"; false; }
    done <<< "$remedies"
}

@test "redirected onboarding skip stays blocked (exemption not widened)" {
    : > "$ROOT/.context/working/focus.yaml"
    hook_bash "bin/fw onboarding skip > .claude/settings.json"
    [ "$status" -eq 2 ]
}
