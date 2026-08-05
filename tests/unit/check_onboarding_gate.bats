#!/usr/bin/env bats
# T-2815: PreToolUse Write/Edit hook tests for check-onboarding-gate.
#
# Mirrors tests/unit/check_inception_recommendation.bats shape: build the
# stdin JSON envelope Claude Code would send, invoke the hook, assert exit
# code + stderr.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    HOOK="$REPO_ROOT/agents/context/check-onboarding-gate.sh"
    TMP="$(mktemp -d)"
    unset PROJECT_ROOT
    export CLAUDECODE=1
    unset AI_AGENT
    unset FW_ALLOW_ONBOARDING_UNRESOLVABLE
}

teardown() {
    rm -rf "$TMP"
}

write_envelope() {
    local file_path="$1"
    local content="$2"
    python3 -c "
import json, sys
print(json.dumps({
    'tool_name': 'Write',
    'tool_input': {'file_path': '$file_path', 'content': $content},
}))
"
}

@test "non-task file path passes silently" {
    payload='{"tool_name":"Write","tool_input":{"file_path":"/tmp/other.md","content":"hello"}}'
    run bash -c "echo '$payload' | bash $HOOK"
    [ "$status" -eq 0 ]
}

@test "non-onboarding task passes silently" {
    content=$(python3 -c "import json; print(json.dumps('''---
id: T-9201
owner: agent
workflow_type: inception
tags: [some-other-tag]
status: captured
---
## Acceptance Criteria
### Agent
- [ ] fw inception decide T-9201 go
'''))")
    payload=$(write_envelope "/.tasks/active/T-9201-x.md" "$content")
    run bash -c "echo '$payload' | bash $HOOK"
    [ "$status" -eq 0 ]
}

# --- L-530 both-states: the exempted branch (owner:human) ---
@test "owner:human onboarding inception with unticked Human AC PASSES (sanctioned escape valve)" {
    content=$(python3 -c "import json; print(json.dumps('''---
id: T-9202
owner: human
workflow_type: inception
tags: [onboarding, inception]
status: captured
---
## Acceptance Criteria
### Human
- [ ] [REVIEW] problem statement is clear
### Agent
- [ ] fw inception decide T-9202 go
'''))")
    payload=$(write_envelope "/.tasks/active/T-9202-x.md" "$content")
    run bash -c "echo '$payload' | bash $HOOK"
    [ "$status" -eq 0 ]
}

# --- L-530 both-states: the genuinely-broken branch (owner:agent, inception) ---
@test "owner:agent onboarding inception BLOCKS (inception-decide-blocked)" {
    content=$(python3 -c "import json; print(json.dumps('''---
id: T-9203
owner: agent
workflow_type: inception
tags: [onboarding, inception]
status: captured
---
## Acceptance Criteria
### Agent
- [ ] fw inception decide T-9203 go
'''))")
    payload=$(write_envelope "/.tasks/active/T-9203-x.md" "$content")
    run bash -c "echo '$payload' | bash $HOOK"
    [ "$status" -eq 2 ]
    [[ "$output" =~ "ONBOARDING GATE DEADLOCK" ]]
    [[ "$output" =~ "inception-decide-blocked" ]]
    [[ "$output" =~ "FW_ALLOW_ONBOARDING_UNRESOLVABLE=1" ]]
}

# --- L-530 both-states: owner:agent build task with unticked Human AC ---
@test "owner:agent onboarding build with unticked Human AC BLOCKS (human-ac-present)" {
    content=$(python3 -c "import json; print(json.dumps('''---
id: T-9204
owner: agent
workflow_type: build
tags: [onboarding]
status: captured
---
## Acceptance Criteria
### Agent
- [ ] do the thing
### Human
- [ ] [REVIEW] taste check
'''))")
    payload=$(write_envelope "/.tasks/active/T-9204-x.md" "$content")
    run bash -c "echo '$payload' | bash $HOOK"
    [ "$status" -eq 2 ]
    [[ "$output" =~ "human-ac-present" ]]
}

# --- L-530 both-states: the all-agent set passes ---
@test "owner:agent onboarding build with only Agent ACs PASSES" {
    content=$(python3 -c "import json; print(json.dumps('''---
id: T-9205
owner: agent
workflow_type: build
tags: [onboarding]
status: captured
---
## Acceptance Criteria
### Agent
- [ ] do the thing
'''))")
    payload=$(write_envelope "/.tasks/active/T-9205-x.md" "$content")
    run bash -c "echo '$payload' | bash $HOOK"
    [ "$status" -eq 0 ]
}

@test "onboarding build with all ticked Human ACs PASSES" {
    content=$(python3 -c "import json; print(json.dumps('''---
id: T-9206
owner: agent
workflow_type: build
tags: [onboarding]
status: captured
---
## Acceptance Criteria
### Agent
- [ ] do the thing
### Human
- [x] [REVIEW] already checked
'''))")
    payload=$(write_envelope "/.tasks/active/T-9206-x.md" "$content")
    run bash -c "echo '$payload' | bash $HOOK"
    [ "$status" -eq 0 ]
}

@test "work-completed onboarding task PASSES regardless of shape" {
    content=$(python3 -c "import json; print(json.dumps('''---
id: T-9207
owner: agent
workflow_type: inception
tags: [onboarding, inception]
status: work-completed
---
## Acceptance Criteria
### Agent
- [x] fw inception decide T-9207 go
'''))")
    payload=$(write_envelope "/.tasks/active/T-9207-x.md" "$content")
    run bash -c "echo '$payload' | bash $HOOK"
    [ "$status" -eq 0 ]
}

@test "FW_ALLOW_ONBOARDING_UNRESOLVABLE=1 bypass passes + logs Tier-2" {
    mkdir -p "$TMP/.context/working"
    content=$(python3 -c "import json; print(json.dumps('''---
id: T-9208
owner: agent
workflow_type: inception
tags: [onboarding, inception]
status: captured
---
## Acceptance Criteria
### Agent
- [ ] fw inception decide T-9208 go
'''))")
    payload=$(write_envelope "/.tasks/active/T-9208-x.md" "$content")
    export FW_ALLOW_ONBOARDING_UNRESOLVABLE=1
    export PROJECT_ROOT="$TMP"
    run bash -c "echo '$payload' | bash $HOOK"
    unset FW_ALLOW_ONBOARDING_UNRESOLVABLE
    unset PROJECT_ROOT
    [ "$status" -eq 0 ]
    [ -f "$TMP/.context/working/.gate-bypass-log.yaml" ]
    grep -q "FW_ALLOW_ONBOARDING_UNRESOLVABLE" "$TMP/.context/working/.gate-bypass-log.yaml"
    grep -q "check-onboarding-gate" "$TMP/.context/working/.gate-bypass-log.yaml"
}

@test "unset CLAUDECODE produces advisory NOTE, not block" {
    unset CLAUDECODE
    content=$(python3 -c "import json; print(json.dumps('''---
id: T-9209
owner: agent
workflow_type: inception
tags: [onboarding, inception]
status: captured
---
## Acceptance Criteria
### Agent
- [ ] fw inception decide T-9209 go
'''))")
    payload=$(write_envelope "/.tasks/active/T-9209-x.md" "$content")
    run bash -c "unset CLAUDECODE; echo '$payload' | bash $HOOK"
    [ "$status" -eq 0 ]
}

@test "non-Write tool (Read) passes silently" {
    payload='{"tool_name":"Read","tool_input":{"file_path":"/.tasks/active/T-9210-x.md"}}'
    run bash -c "echo '$payload' | bash $HOOK"
    [ "$status" -eq 0 ]
}
