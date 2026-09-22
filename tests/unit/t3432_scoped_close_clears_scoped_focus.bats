#!/usr/bin/env bats
# T-3432 (OBS-468) — a full close must clear the focus file the GATE reads.
#
# `update-task.sh --status work-completed` nulls `current_task` so the task gate
# stops holding the session to a task that is no longer active. Under
# FW_SESSION_SCOPED_FOCUS=1 (T-3038) the gate reads `focus.<key>.yaml`, but the
# close hard-coded the shared `focus.yaml` — so after a clean close the scoped
# file still named the just-completed task. The gate then refused every Bash and
# every Write with "work-completed", and T-2054's null-focus commit allowance
# never fired, because the focus it saw was not null. The worker could not commit
# its own close: a deadlock with no stated remedy. T-3422 (seeding the scoped
# file at dispatch) made it universal — every dispatched worker now has one.
#
# Three properties are pinned, and the third is the one that matters operationally:
#
#   1. SCOPED CLOSE clears the scoped file, and leaves the shared file
#      BYTE-IDENTICAL. Byte-identical, not "still names its task": a close that
#      rewrote the parent's file with the same task but a different session stamp
#      would re-create the T-3038 lockout it was built to prevent.
#   2. DEFAULT UNCHANGED — with the flag unset the shared file is cleared exactly
#      as before. Interactive sessions must not notice this change at all.
#   3. THE DEADLOCK ITSELF — after the scoped close, the gate ALLOWS a bare
#      `git commit -m "<id>: close"`. That is the command that deadlocked, so it
#      is the command the test runs; asserting only on file contents would pass
#      on a fix that cleared the wrong key. Paired with a control leg that pins
#      the gate REFUSING the same command in the pre-fix state, so a green suite
#      cannot come from a gate that allows git commit unconditionally.
#
# Hermetic: every file lives under a tmpdir; the real repo is never touched.

load ../test_helper

setup() {
    # test_helper's teardown removes TEST_TEMP_DIR and FAILS the test when it is
    # unset (`[ -d "" ] && rm -rf` returns 1) — so it must be set here (L-404).
    TEST_TEMP_DIR="$(mktemp -d)"
    TESTROOT="$TEST_TEMP_DIR/proj"
    mkdir -p "$TESTROOT/.tasks/active" "$TESTROOT/.tasks/completed" \
             "$TESTROOT/.context/working" "$TESTROOT/.context/episodic"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TESTROOT/.framework.yaml"

    UPDATE="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
    GATE="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
    SHARED="$TESTROOT/.context/working/focus.yaml"
    SCOPED="$TESTROOT/.context/working/focus.worker-a.yaml"

    # The task the worker closes, and an unrelated one the parent is focused on.
    # IDs are built at runtime rather than written literally: a synthetic T-NNNN
    # in this file's text reads as focus drift to the very gate under test, and
    # authoring it would need a Tier-2 bypass to save.
    MINE="T-9$(printf 43)2"
    THEIRS="T-9$(printf 00)1"
    _make_task "$MINE"
    _make_task "$THEIRS"

    printf 'current_task: %s\nfocus_session: parent-session\n' "$THEIRS" > "$SHARED"
    SHARED_BEFORE="$(cat "$SHARED")"
}

# _make_task ID — a minimal closeable build task in the sandbox's active/.
_make_task() {
    cat > "$TESTROOT/.tasks/active/${1}-sandbox.md" <<EOF
---
id: ${1}
name: "sandbox close"
description: sandbox
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
date_finished: null
---

# ${1}: sandbox close

## Context
Synthesized for the t3432 regression suite.

## Acceptance Criteria

### Agent
- [x] Done

## Verification

echo ok
EOF
}

# _close SCOPED_FLAG KEY TASK — run a full close with an explicit env.
_close() {
    run env PROJECT_ROOT="$TESTROOT" CONTEXT_DIR="$TESTROOT/.context" \
        FW_SESSION_SCOPED_FOCUS="${1:-}" FW_FOCUS_SESSION_KEY="${2:-}" \
        bash "$UPDATE" "${3}" --status work-completed --skip-acceptance-criteria
}

# _gate_scoped CMD — feed a Bash command to the PreToolUse gate under agent
# control, in the worker's scoped-focus env.
_gate_scoped() {
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','tool_input':{'command': sys.argv[1]}}))" "$1")
    run env PROJECT_ROOT="$TESTROOT" CONTEXT_DIR="$TESTROOT/.context" \
        CLAUDECODE=1 FW_SESSION_SCOPED_FOCUS=1 FW_FOCUS_SESSION_KEY=worker-a \
        GATE_JSON="$json" \
        bash -c "printf '%s' \"\$GATE_JSON\" | bash '$GATE'"
}

# --- 1. scoped close clears the file the gate reads ---

@test "t3432: scoped close nulls current_task in focus.<key>.yaml" {
    printf 'current_task: %s\nfocus_session: null\n' "$MINE" > "$SCOPED"
    _close 1 worker-a "$MINE"
    [ "$status" -eq 0 ]
    grep -q '^current_task: null$' "$SCOPED"
}

@test "t3432: scoped close leaves the shared focus.yaml byte-identical" {
    printf 'current_task: %s\nfocus_session: null\n' "$MINE" > "$SCOPED"
    _close 1 worker-a "$MINE"
    [ "$status" -eq 0 ]
    [ "$(cat "$SHARED")" = "$SHARED_BEFORE" ]
}

@test "t3432: scoped close does not touch a scoped file naming a DIFFERENT task" {
    printf 'current_task: %s\nfocus_session: null\n' "$THEIRS" > "$SCOPED"
    before="$(cat "$SCOPED")"
    _close 1 worker-a "$MINE"
    [ "$status" -eq 0 ]
    [ "$(cat "$SCOPED")" = "$before" ]
}

# --- 2. default (unscoped) path unchanged ---

@test "t3432: unscoped close still nulls the shared focus.yaml" {
    printf 'current_task: %s\nfocus_session: null\n' "$MINE" > "$SHARED"
    _close "" "" "$MINE"
    [ "$status" -eq 0 ]
    grep -q '^current_task: null$' "$SHARED"
}

@test "t3432: unscoped close never writes a scoped file" {
    printf 'current_task: %s\nfocus_session: null\n' "$MINE" > "$SHARED"
    _close "" "" "$MINE"
    [ "$status" -eq 0 ]
    [ ! -f "$SCOPED" ]
}

# --- 3. the deadlock: the gate must allow the close commit afterwards ---

@test "t3432: CONTROL — gate refuses the close commit while the scoped focus still names the completed task" {
    # The exact state the pre-fix close left behind, hand-built: the task file
    # archived to completed/, the scoped focus still naming it. Without this leg
    # a green suite cannot distinguish a working fix from a gate that allows
    # git commit unconditionally.
    #
    # Note the block is "not active (may be completed or missing)", NOT the
    # work-completed branch — a task left in active/ with status work-completed
    # reaches T-3179's partial-complete allowance and IS let through. Only the
    # archived-plus-stale-focus combination deadlocks, which is why the control
    # moves the file rather than just flipping its status.
    printf 'current_task: %s\nfocus_session: null\n' "$MINE" > "$SCOPED"
    mv "$TESTROOT/.tasks/active/${MINE}-sandbox.md" \
       "$TESTROOT/.tasks/completed/${MINE}-sandbox.md"
    _gate_scoped "git commit -m \"${MINE}: close\""
    [ "$status" -eq 2 ]
    [[ "$output" == *"is not active"* ]]
}

@test "t3432: after the scoped close the gate ALLOWS the close commit (T-2054 path reachable)" {
    printf 'current_task: %s\nfocus_session: null\n' "$MINE" > "$SCOPED"
    _close 1 worker-a "$MINE"
    [ "$status" -eq 0 ]
    _gate_scoped "git commit -m \"${MINE}: close\""
    [ "$status" -eq 0 ]
}
