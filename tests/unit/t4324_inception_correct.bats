#!/usr/bin/env bats
# T-4324: a mis-clicked inception decision had no supported correction path.
# `fw inception decide` only finds active tasks, and GO/NO-GO moves the task to
# completed/ in the same call; the operator had to hand-revert two commits for
# T-2899 (15704c4ef), and the pending view still said "already decided: GO".
# `fw inception correct` re-records the verdict in place, operator-only, logged.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export TASKS_DIR="$TEST_TEMP_DIR/.tasks"
    export AGENTS_DIR="$FRAMEWORK_ROOT/agents"
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
    export NO_COLOR=1
    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
    unset CLAUDECODE
    mkdir -p "$TASKS_DIR/active" "$TASKS_DIR/completed" "$TEST_TEMP_DIR/.context"
    git -C "$TEST_TEMP_DIR" init -q
    git -C "$TEST_TEMP_DIR" config core.hooksPath /dev/null

    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
    source "$FRAMEWORK_ROOT/lib/inception.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# $1=id $2=dir (active|completed) $3=workflow $4=decision line value ("" = none)
_make_task() {
    local f="$TASKS_DIR/$2/$1-test.md"
    {
        printf -- '---\nid: %s\nname: "t"\nstatus: work-completed\nworkflow_type: %s\nowner: human\n---\n\n' "$1" "$3"
        printf '# %s\n\n## Recommendation\n\n**Recommendation:** NO-GO\n\n## Decision\n\n' "$1"
        [ -n "$4" ] && printf '**Decision**: %s\n\n**Rationale**: clicked\n\n**Date**: 2026-10-18T18:39:36Z\n' "$4"
        printf '\n## Updates\n\n### 2026-10-18T18:39:36Z — created\n'
    } > "$f"
    git -C "$TEST_TEMP_DIR" add -A
    git -C "$TEST_TEMP_DIR" commit -q -m "$1: inception decision ${4:-NONE} (via Watchtower)"
    echo "$f"
}

_pending_verdict() {
    python3 - "$FRAMEWORK_ROOT/lib" "$1" "$TEST_TEMP_DIR" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import operator_pending as op
d = op.inception_decision(Path(sys.argv[2]), Path(sys.argv[3]))
print(d["verdict"] if d else "NONE")
PY
}

@test "corrects GO to NO-GO on a completed inception, logged and committed" {
    f=$(_make_task T-9001 completed inception GO)
    run do_inception_correct T-9001 no-go --reason "pressed GO by mistake"
    [ "$status" -eq 0 ]
    grep -q '^\*\*Decision\*\*: NO-GO$' "$f"
    grep -q '^\*\*Rationale\*\*: pressed GO by mistake$' "$f"
    grep -q '^\*\*Corrected\*\*: from GO' "$f"
    [ "$(grep -c '^\*\*Decision\*\*:' "$f")" -eq 1 ]
    grep -q 'inception-decision-correction' "$f"
    grep -q '"task": "T-9001", "from": "GO", "to": "NO-GO"' "$TEST_TEMP_DIR/.context/inception-corrections.jsonl"
    # the Updates section after the Decision block survives
    grep -q '^## Updates' "$f"
    [ "$(git -C "$TEST_TEMP_DIR" log -1 --format=%s)" = "T-9001: inception decision NO-GO (corrected from GO)" ]
    [ "$(_pending_verdict "$f")" = "NO-GO" ]
}

@test "pending view honours the correction even when the newest decision commit still says GO" {
    f=$(_make_task T-9002 completed inception GO)
    printf '#!/bin/sh\nexit 1\n' > "$TEST_TEMP_DIR/pre-commit"; chmod +x "$TEST_TEMP_DIR/pre-commit"
    git -C "$TEST_TEMP_DIR" config core.hooksPath "$TEST_TEMP_DIR"
    run do_inception_correct T-9002 no-go --reason "mis-click"
    [ "$status" -eq 0 ]
    [[ "$output" == *"not committed"* ]]
    [ "$(git -C "$TEST_TEMP_DIR" log -1 --format=%s)" = "T-9002: inception decision GO (via Watchtower)" ]
    [ "$(_pending_verdict "$f")" = "NO-GO" ]
}

@test "refuses without a reason, writing nothing" {
    f=$(_make_task T-9003 completed inception GO)
    before=$(cat "$f")
    run do_inception_correct T-9003 no-go
    [ "$status" -ne 0 ]
    [ "$(cat "$f")" = "$before" ]
    [ ! -f "$TEST_TEMP_DIR/.context/inception-corrections.jsonl" ]
}

@test "refuses a non-inception task" {
    _make_task T-9004 completed build GO >/dev/null
    run do_inception_correct T-9004 no-go --reason r
    [ "$status" -ne 0 ]
    [[ "$output" == *"not an inception"* ]]
}

@test "refuses an undecided inception and points at decide" {
    _make_task T-9005 active inception "" >/dev/null
    run do_inception_correct T-9005 go --reason r
    [ "$status" -ne 0 ]
    [[ "$output" == *"inception decide"* ]]
}

@test "refuses when the verdict is unchanged" {
    _make_task T-9006 completed inception NO-GO >/dev/null
    run do_inception_correct T-9006 no-go --reason r
    [ "$status" -ne 0 ]
    [[ "$output" == *"already recorded"* ]]
}

@test "refuses an agent (CLAUDECODE=1) without --i-am-human, writing nothing" {
    f=$(_make_task T-9007 completed inception GO)
    before=$(cat "$f")
    CLAUDECODE=1 run do_inception_correct T-9007 no-go --reason r
    [ "$status" -ne 0 ]
    [[ "$output" == *"Agents must not correct"* ]]
    [ "$(cat "$f")" = "$before" ]
}

@test "--i-am-human passes the sovereignty gate and is recorded as the actor" {
    f=$(_make_task T-9008 completed inception NO-GO)
    CLAUDECODE=1 run do_inception_correct T-9008 go --reason r --i-am-human
    [ "$status" -eq 0 ]
    grep -q '^\*\*Decision\*\*: GO$' "$f"
    grep -q '"by": "i-am-human"' "$TEST_TEMP_DIR/.context/inception-corrections.jsonl"
}

@test "fw inception help lists the correct verb" {
    run show_inception_help
    [[ "$output" == *"correct <T-XXX> go|no-go"* ]]
}
