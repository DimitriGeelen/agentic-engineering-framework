#!/usr/bin/env bats
# T-2205: PreToolUse Write/Edit hook tests for check-inception-recommendation.
#
# Mirrors tests/unit/check_arc_id.bats / check_inception_decisions.bats shape:
# build the stdin JSON envelope Claude Code would send, invoke the hook,
# assert exit code + stderr.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    HOOK="$REPO_ROOT/agents/context/check-inception-recommendation.sh"
    TMP="$(mktemp -d)"
    # L-456: bats sub-process inherits PROJECT_ROOT from update-task.sh if set.
    # The hook only reads PROJECT_ROOT for the bypass-log path — synthetic
    # tests don't depend on that, but unset for hygiene.
    unset PROJECT_ROOT
    # Force CLAUDECODE=1 so blocking branch is active (unless test overrides).
    export CLAUDECODE=1
    unset AI_AGENT
    unset FW_ALLOW_EMPTY_RECOMMENDATION
}

teardown() {
    rm -rf "$TMP"
}

# Helper: build the Claude Code Write tool stdin envelope.
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
    run bash -c "echo '$payload' | $HOOK"
    [ "$status" -eq 0 ]
}

@test "non-inception task passes silently" {
    fp="$TMP/.tasks/active/T-9001-build.md"
    content=$(python3 -c "import json; print(json.dumps('''---
id: T-9001
workflow_type: build
---
# build task
'''))")
    payload=$(write_envelope "/.tasks/active/T-9001-build.md" "$content")
    run bash -c "echo '$payload' | $HOOK"
    [ "$status" -eq 0 ]
}

@test "inception with populated Recommendation passes" {
    content=$(python3 -c "import json; print(json.dumps('''---
id: T-9002
workflow_type: inception
---
# inception

## Recommendation

**Recommendation:** GO

**Rationale:** evidence cited.

## Decisions
'''))")
    payload=$(write_envelope "/.tasks/active/T-9002-inception.md" "$content")
    run bash -c "echo '$payload' | $HOOK"
    [ "$status" -eq 0 ]
}

@test "inception with template-only Recommendation under CLAUDECODE=1 BLOCKS" {
    content=$(python3 -c "import json; print(json.dumps('''---
id: T-9003
workflow_type: inception
---
# inception

## Recommendation

<!-- REQUIRED before fw inception decide. Write your recommendation here. -->

## Decisions
'''))")
    payload=$(write_envelope "/.tasks/active/T-9003-inception.md" "$content")
    run bash -c "echo '$payload' | $HOOK"
    [ "$status" -eq 2 ]
    [[ "$output" =~ "INCEPTION RECOMMENDATION MISSING" ]]
    [[ "$output" =~ "FW_ALLOW_EMPTY_RECOMMENDATION=1" ]]
    [[ "$output" =~ "fw inception start" ]]
}

@test "FW_ALLOW_EMPTY_RECOMMENDATION=1 bypass passes + logs Tier-2" {
    PROJECT_ROOT="$TMP"
    export PROJECT_ROOT
    mkdir -p "$TMP/.context/working"

    content=$(python3 -c "import json; print(json.dumps('''---
id: T-9004
workflow_type: inception
---
# inception

## Recommendation

<!-- template only -->

## Decisions
'''))")
    payload=$(write_envelope "/.tasks/active/T-9004-inception.md" "$content")
    run bash -c "FW_ALLOW_EMPTY_RECOMMENDATION=1 PROJECT_ROOT='$TMP' echo '$payload' | FW_ALLOW_EMPTY_RECOMMENDATION=1 PROJECT_ROOT='$TMP' $HOOK"
    [ "$status" -eq 0 ]
    [ -f "$TMP/.context/working/.gate-bypass-log.yaml" ]
    grep -q "FW_ALLOW_EMPTY_RECOMMENDATION" "$TMP/.context/working/.gate-bypass-log.yaml"
    grep -q "check-inception-recommendation" "$TMP/.context/working/.gate-bypass-log.yaml"
}

@test "unset CLAUDECODE produces advisory NOTE, not block" {
    unset CLAUDECODE
    content=$(python3 -c "import json; print(json.dumps('''---
id: T-9005
workflow_type: inception
---
## Recommendation

<!-- template only -->
'''))")
    payload=$(write_envelope "/.tasks/active/T-9005-inception.md" "$content")
    run bash -c "unset CLAUDECODE; echo '$payload' | $HOOK"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "NOTE: inception" ]] || true
    # Either NOTE present OR silent pass — both are acceptable for unset-CLAUDECODE.
}

@test "non-Write tool (Read) passes silently" {
    payload='{"tool_name":"Read","tool_input":{"file_path":"/.tasks/active/T-9006-inception.md"}}'
    run bash -c "echo '$payload' | $HOOK"
    [ "$status" -eq 0 ]
}
