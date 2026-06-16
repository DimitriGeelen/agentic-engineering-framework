#!/usr/bin/env bats
# T-2421 (T-2419 GO): Recommendation gate for partial-complete BUILD-class tasks.
#
# Sibling of T-2204 inception filing-time gate. This suite pins:
#   - emit_review refuses URL emission for partial-complete build/refactor/test/decommission
#     when ## Recommendation is missing or empty (the T-2417 close-cascade class).
#   - emit_review honours FW_ALLOW_EMPTY_RECOMMENDATION=1 env-var bypass with Tier-2 log.
#   - emit_review still fires for inception tasks (no regression of T-2206).
#   - emit_review passes when build is fully-complete (no unticked Human ACs).
#   - emit_review passes when build has zero Human ACs.
#   - update-task.sh check_recommendation_for_review honours FW_ALLOW_EMPTY_RECOMMENDATION=1
#     env-var bypass in addition to the existing --skip-recommendation flag (T-1890 parity).

load ../test_helper

UPDATE_TASK="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
REVIEW_LIB="$FRAMEWORK_ROOT/lib/review.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$PROJECT_ROOT/.tasks/active" \
             "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.tasks/templates" \
             "$PROJECT_ROOT/.context/working" \
             "$PROJECT_ROOT/.context/episodic"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    cp "$FRAMEWORK_ROOT/.tasks/templates/zzz-default.md" \
       "$PROJECT_ROOT/.tasks/templates/default.md" 2>/dev/null || \
       echo "# template" > "$PROJECT_ROOT/.tasks/templates/default.md"
    unset FW_ALLOW_EMPTY_RECOMMENDATION
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Make a task fixture. Args: id, workflow_type, human_acs (yaml-list-string for
# ### Human bullets), rec_block (literal markdown for ## Recommendation or empty).
_make_task() {
    local id="$1"
    local wf="$2"
    local human_acs="$3"
    local rec_block="$4"
    local task_file="$PROJECT_ROOT/.tasks/active/${id}-fixture.md"
    cat > "$task_file" <<EOF
---
id: $id
name: "fixture"
description: "T-2421 fixture"
status: started-work
workflow_type: $wf
owner: agent
horizon: now
tags: []
created: 2026-06-16T00:00:00Z
last_update: 2026-06-16T00:00:00Z
date_finished: null
---

# $id

## Acceptance Criteria

### Agent
- [x] Done

### Human
${human_acs}

${rec_block}

## Verification

EOF
    echo "$task_file"
}

# Run emit_review in a sourced subshell against a real fixture; capture stderr+stdout+exit.
_run_emit() {
    local id="$1"
    local task_file="$2"
    # Run in a subshell so test isolation is preserved; produce minimal env.
    run bash -c "
        export PROJECT_ROOT='$PROJECT_ROOT'
        export FRAMEWORK_ROOT='$FRAMEWORK_ROOT'
        source '$REVIEW_LIB'
        emit_review '$id' '$task_file' 2>&1
    "
}

# ── emit_review (lib/review.sh) tests ─────────────────────────────────────────

@test "t1: partial-complete build with empty Recommendation → emit_review BLOCKS" {
    f=$(_make_task "T-9001" "build" "- [ ] [REVIEW] do thing" "")
    _run_emit "T-9001" "$f"
    [ "$status" -ne 0 ]
    [[ "$output" == *"BLOCKED"* ]]
    [[ "$output" == *"empty ## Recommendation"* ]]
    [[ "$output" == *"FW_ALLOW_EMPTY_RECOMMENDATION=1"* ]]
}

@test "t2: partial-complete build with substantive Recommendation → emit_review allows" {
    f=$(_make_task "T-9002" "build" "- [ ] [REVIEW] do thing" "## Recommendation

**Recommendation:** GO
**Rationale:** evidence here")
    _run_emit "T-9002" "$f"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Open:"* ]]
    [[ "$output" == *"/review/T-9002"* ]]
}

@test "t3: fully-complete build (all Human ACs ticked) → emit_review allows even with empty Rec" {
    f=$(_make_task "T-9003" "build" "- [x] [REVIEW] do thing" "")
    _run_emit "T-9003" "$f"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Open:"* ]]
}

@test "t4: build with no Human ACs → emit_review allows even with empty Rec" {
    f=$(_make_task "T-9004" "build" "" "")
    _run_emit "T-9004" "$f"
    [ "$status" -eq 0 ]
}

@test "t5: FW_ALLOW_EMPTY_RECOMMENDATION=1 bypasses build gate, logs Tier-2" {
    f=$(_make_task "T-9005" "build" "- [ ] [REVIEW] do thing" "")
    run bash -c "
        export PROJECT_ROOT='$PROJECT_ROOT'
        export FRAMEWORK_ROOT='$FRAMEWORK_ROOT'
        export FW_ALLOW_EMPTY_RECOMMENDATION=1
        source '$REVIEW_LIB'
        emit_review 'T-9005' '$f' 2>&1
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"FW_ALLOW_EMPTY_RECOMMENDATION=1"* ]]
    [[ "$output" == *"logged"* ]]
    [ -f "$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml" ]
    grep -q "T-9005" "$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
    grep -q "FW_ALLOW_EMPTY_RECOMMENDATION" "$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
}

@test "t6: refactor workflow_type also triggers the build-leg gate" {
    f=$(_make_task "T-9006" "refactor" "- [ ] [REVIEW] do thing" "")
    _run_emit "T-9006" "$f"
    [ "$status" -ne 0 ]
    [[ "$output" == *"BLOCKED"* ]]
    [[ "$output" == *"refactor"* ]]
}

@test "t7: inception gate still fires (no regression of T-2206)" {
    f=$(_make_task "T-9007" "inception" "- [ ] [REVIEW] decide" "")
    _run_emit "T-9007" "$f"
    [ "$status" -ne 0 ]
    [[ "$output" == *"BLOCKED"* ]]
    [[ "$output" == *"Inception"* ]]
}

# ── update-task.sh env-var parity test ────────────────────────────────────────

@test "t8: update-task.sh honours FW_ALLOW_EMPTY_RECOMMENDATION=1 env-var" {
    # Use risk:high (F6 needs-human signal) instead of Human AC so the test
    # doesn't drag in auto_emit_review_if_partial which fails on no-Watchtower
    # in the bats temp dir. The env-var bypass is the same code path either way.
    local task_file="$PROJECT_ROOT/.tasks/active/T-9008-fixture.md"
    cat > "$task_file" <<EOF
---
id: T-9008
name: "fixture"
description: "T-2421 t8 fixture"
status: started-work
workflow_type: refactor
owner: agent
horizon: now
tags: []
created: 2026-06-16T00:00:00Z
last_update: 2026-06-16T00:00:00Z
date_finished: null
risk: high
---

# T-9008

## Acceptance Criteria

### Agent
- [x] done

## Verification

EOF
    export FW_ALLOW_EMPTY_RECOMMENDATION=1
    run "$UPDATE_TASK" T-9008 --status work-completed
    unset FW_ALLOW_EMPTY_RECOMMENDATION
    [ "$status" -eq 0 ]
    [[ "$output" == *"FW_ALLOW_EMPTY_RECOMMENDATION=1 bypass"* ]]
    [ -f "$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml" ]
    grep -q "T-9008" "$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
    grep -q "FW_ALLOW_EMPTY_RECOMMENDATION" "$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
}

@test "t9: update-task.sh without bypass still blocks empty Rec on partial-complete" {
    f=$(_make_task "T-9009" "build" "- [ ] [REVIEW] do thing" "")
    run "$UPDATE_TASK" T-9009 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"Recommendation"* ]]
    [[ "$output" == *"FW_ALLOW_EMPTY_RECOMMENDATION"* ]]
}

@test "t10: block message names both bypass mechanisms (T-1890 parity)" {
    f=$(_make_task "T-9010" "build" "- [ ] [REVIEW] do thing" "")
    _run_emit "T-9010" "$f"
    [ "$status" -ne 0 ]
    # Env var named in block message (emit_review side)
    [[ "$output" == *"FW_ALLOW_EMPTY_RECOMMENDATION=1"* ]]

    # update-task.sh side: both --skip-recommendation AND FW_ALLOW_EMPTY_RECOMMENDATION
    # must appear in its block message
    run "$UPDATE_TASK" T-9010 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"--skip-recommendation"* ]]
    [[ "$output" == *"FW_ALLOW_EMPTY_RECOMMENDATION"* ]]
}
