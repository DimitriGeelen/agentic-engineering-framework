#!/usr/bin/env bats
# T-2964 — `fw inception decide` refused on sovereignty grounds before ever
# looking at whether the target was an inception. Reported by 832 as OBS-047.
#
# Origin: 832's operator ruled verbally on their T-340. Their agent ran
# `fw inception decide T-340 go`. Two gates refused in series — the Tier 0 hook,
# then the $CLAUDECODE=1 sovereignty block. Both refusals were CORRECT for a
# command aimed at an inception. T-340 is `workflow_type: build`; the ruling it
# carried was a Human AC. Neither gate validates the target's type, because both
# dispatch on the COMMAND NAME before any argument is read.
#
# The damage is not a poor error message. It is that two independent refusals
# agreeing read as CORROBORATION, so the agent concluded "sovereignty-gated, hand
# it to the operator" and handed over a command that could not have worked —
# with confidence proportional to how many gates had blocked it. The ruling went
# unrecorded across three attempts.
#
# Sibling evidence that this site was the outlier rather than the pattern: all
# four sovereignty gates in lib/arc.sh already validate their target first
# (_arc_exists / _arc_require_status ahead of the CLAUDECODE check).
#
# COUNTERFACTUAL: restore the pre-fix ordering (move the CLAUDECODE block back
# above the find_task_file / workflow_type checks) and leg 1 goes red at the
# assertion that the message names workflow_type — not merely at an exit code.
# Leg 2 stays green under both orderings, which is the point: it pins that the
# fix did not buy leg 1 by weakening the sovereignty gate.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export AGENTS_DIR="$FRAMEWORK_ROOT/agents"
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
    export NO_COLOR=1
    mkdir -p "$TEST_TEMP_DIR/.tasks/active" "$TEST_TEMP_DIR/.context/working"

    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh"
    source "$FRAMEWORK_ROOT/lib/paths.sh"
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
    source "$FRAMEWORK_ROOT/lib/inception.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_make_task() {
    local task_id="$1" wf="$2"
    cat > "$TEST_TEMP_DIR/.tasks/active/$task_id-test.md" <<EOF
---
id: $task_id
name: "Test task"
status: started-work
workflow_type: $wf
owner: agent
horizon: now
created: 2026-08-13T00:00:00Z
last_update: 2026-08-13T00:00:00Z
---

# $task_id: Test task
EOF
}

@test "build target under CLAUDECODE=1 refuses on TYPE, not on sovereignty" {
    _make_task "T-9001" "build"
    CLAUDECODE=1 run do_inception_decide T-9001 go --rationale "verbal ruling"

    [ "$status" -ne 0 ]
    # The refusal must name the actual fault…
    [[ "$output" == *"not an inception task"* ]]
    [[ "$output" == *"workflow_type: build"* ]]
    # …and must NOT claim this is the human's decision to make, which is the
    # wrong hypothesis 832's agent acted on.
    [[ "$output" != *"belong to the human"* ]]
    [[ "$output" != *"Agents must not invoke"* ]]
}

@test "build-target refusal names the mechanism that DOES apply" {
    _make_task "T-9002" "build"
    CLAUDECODE=1 run do_inception_decide T-9002 go --rationale "verbal ruling"

    # A refusal is where the agent's next hypothesis comes from. Naming only the
    # fault leaves it to guess the remedy — 832's agent guessed /inception/T-340
    # and got a 404.
    [[ "$output" == *"task review T-9002"* ]]
    [[ "$output" == *"--type inception"* ]]
}

@test "inception target under CLAUDECODE=1 still refuses on sovereignty" {
    _make_task "T-9003" "inception"
    CLAUDECODE=1 run do_inception_decide T-9003 go --rationale "verbal ruling"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Agents must not invoke"* ]]
    [[ "$output" == *"belong to the human"* ]]
    # The reorder must not have leaked a type complaint onto the valid path.
    [[ "$output" != *"not an inception task"* ]]
}

@test "unknown task refuses as not-found, not as a type error" {
    CLAUDECODE=1 run do_inception_decide T-9999 go --rationale "verbal ruling"

    [ "$status" -ne 0 ]
    [[ "$output" == *"not found in active tasks"* ]]
    [[ "$output" != *"not an inception task"* ]]
}

@test "human path on a build target is refused by TYPE, not waved through" {
    # --i-am-human clears sovereignty but must not clear the type check: 832's
    # operator ran the command themselves and hit the same wall, which is what
    # made the sovereignty reading look confirmed.
    _make_task "T-9004" "build"
    run do_inception_decide T-9004 go --rationale "verbal ruling" --i-am-human

    [ "$status" -ne 0 ]
    [[ "$output" == *"not an inception task"* ]]
}
