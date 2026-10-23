#!/usr/bin/env bats
# T-4690: the tree is clean after a task-close commit.
#
# The post-commit footprint refresh (T-3130) corrected the episodic's counters
# one second AFTER the closing commit, so every close left
# .context/episodic/T-XXX.yaml modified. Pre-commit now writes the counters
# (counting the commit being made) into the staged episodic, and post-commit
# finds them `unchanged`.
#
# END-TO-END: a fixture repo with the real hooks installed, a fixture task
# closed through update-task.sh, then a real `git commit`. Task ids are built at
# runtime: a literal synthetic id in this file reads as focus drift to the
# PreToolUse gate that guards writing it (see t3432).

load ../test_helper

setup() {
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
          GIT_COMMON_DIR GIT_PREFIX GIT_REFLOG_ACTION CLAUDECODE
    TEST_TEMP_DIR="$(mktemp -d)"
    REPO="$TEST_TEMP_DIR/proj"
    mkdir -p "$REPO/.tasks/active" "$REPO/.tasks/completed" \
             "$REPO/.context/working" "$REPO/.context/episodic" "$REPO/src"
    git -C "$REPO" init -q -b feature
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    git -C "$REPO" config commit.gpgsign false
    printf 'framework_path: %s\n' "$FRAMEWORK_ROOT" > "$REPO/.framework.yaml"
    echo base > "$REPO/src/base.txt"
    # tracked, as in the framework repo (T-4231 keeps it tracked)
    printf -- '---\nkind: seed\n' > "$REPO/.context/working/feedback-stream.yaml"
    git -C "$REPO" add -A >/dev/null
    git -C "$REPO" commit -q --no-verify -m "T-001: base"
    ( cd "$REPO" && env -u CLAUDE_PROJECT_DIR -u PROJECT_ROOT -u TASKS_DIR \
        -u CONTEXT_DIR -u _FW_PATHS_DERIVED_BY -u _FW_PATHS_LOADED \
        "$FRAMEWORK_ROOT/bin/fw" git install-hooks >/dev/null 2>&1 )
    grep -q t4690-footprint-predict "$REPO/.git/hooks/pre-commit"
    TID="T-9$(printf 69)0"
    LIB="$FRAMEWORK_ROOT/lib/episodic_footprint.py"
    _make_task "$TID"
    # The task's work lands before the close, in its own commit.
    echo work > "$REPO/src/work.txt"
    git -C "$REPO" add -A >/dev/null
    git -C "$REPO" commit -q -m "$TID: work" >/dev/null 2>&1
}

teardown() { [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"; return 0; }

_make_task() {
    cat > "$REPO/.tasks/active/${1}-sandbox.md" <<EOF
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
Synthesized for the t4690 suite.

## Acceptance Criteria

### Agent
- [x] Done

## Verification

echo ok
EOF
}

_close() {
    run env PROJECT_ROOT="$REPO" CONTEXT_DIR="$REPO/.context" \
        bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" "$TID" --status work-completed
    [ "$status" -eq 0 ]
    [ -f "$REPO/.context/episodic/$TID.yaml" ]
    grep -qE '^\s+git_mining: ok' "$REPO/.context/episodic/$TID.yaml"
}

_field() { grep -E "^\s+$1:" "$REPO/.context/episodic/$TID.yaml" | head -1 | sed 's/.*: *//'; }

# The counters in the committed episodic equal a fresh mine of the history.
_counters_match_history() {
    run python3 -c '
import sys; sys.path.insert(0, sys.argv[1])
from pathlib import Path
import episodic_footprint as ef
m = ef.mine(Path(sys.argv[2]), sys.argv[3])
print(" ".join(f"{k}={m[k]}" for k in ef.COUNTER_FIELDS))' "$FRAMEWORK_ROOT/lib" "$REPO" "$TID"
    [ "$status" -eq 0 ]
    local want="$output" got
    got="commits=$(_field commits) files_changed=$(_field files_changed) lines_added=$(_field lines_added) lines_removed=$(_field lines_removed)"
    echo "want: $want"; echo "got:  $got"
    [ "$want" = "$got" ]
}

@test "t4690: close + plain commit leaves the tree clean, counters measured" {
    _close
    git -C "$REPO" add -A >/dev/null
    run git -C "$REPO" commit -m "$TID: close"
    [ "$status" -eq 0 ]
    run git -C "$REPO" status --porcelain
    echo "$output"
    [ -z "$output" ]
    [ "$(_field commits)" = "2" ]
    _counters_match_history
    # the committed blob is the corrected one, not a stale copy
    git -C "$REPO" diff --quiet HEAD -- ".context/episodic/$TID.yaml"
}

@test "t4690: close + 'git commit -- <paths>' leaves the tree clean, other staging untouched" {
    _close
    # another worker's staged file in the shared index must stay staged, uncommitted
    echo theirs > "$REPO/src/theirs.txt"
    git -C "$REPO" add src/theirs.txt
    git -C "$REPO" add -A .tasks .context/episodic >/dev/null
    paths=$(git -C "$REPO" diff --cached --name-only -- .tasks .context/episodic | tr '\n' ' ')
    run bash -c "cd '$REPO' && git commit -m '$TID: close' -- $paths"
    [ "$status" -eq 0 ]
    run bash -c "git -C '$REPO' status --porcelain | grep -v '^?? '"
    echo "$output"
    [ "$output" = "A  src/theirs.txt" ]
    # the close's reviewer events went into the close commit, unnamed
    git -C "$REPO" show --name-only --format= HEAD | grep -qx .context/working/feedback-stream.yaml
    _counters_match_history
}

@test "t4690: two tasks closed in one commit both end clean and measured" {
    TID2="T-9$(printf 69)1"
    _make_task "$TID2"
    git -C "$REPO" add -A >/dev/null
    git -C "$REPO" commit -q -m "$TID2: start" >/dev/null 2>&1
    _close
    run env PROJECT_ROOT="$REPO" CONTEXT_DIR="$REPO/.context" \
        bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" "$TID2" --status work-completed
    [ "$status" -eq 0 ]
    git -C "$REPO" add -A >/dev/null
    run git -C "$REPO" commit -m "$TID: close; $TID2: close"
    [ "$status" -eq 0 ]
    run git -C "$REPO" status --porcelain
    echo "$output"
    [ -z "$output" ]
    _counters_match_history
    TID="$TID2" _counters_match_history
}

@test "t4690: a close committed under a message not naming the task is corrected by post-commit" {
    _close
    git -C "$REPO" add -A >/dev/null
    run git -C "$REPO" commit -m "T-001: sweep (does not name the closed task)"
    [ "$status" -eq 0 ]
    # The prediction (+1 commit) was wrong; post-commit re-checked the predicted
    # id and rewrote the counters from history (the old, dirtying behaviour).
    _counters_match_history
    [ "$(_field commits)" = "1" ]
    [ ! -f "$REPO/.git/fw-footprint-predicted" ]
}

@test "t4694: a later commit naming the closed task leaves the tree clean" {
    _close
    git -C "$REPO" add -A >/dev/null
    run git -C "$REPO" commit -m "$TID: close"
    [ "$status" -eq 0 ]
    run git -C "$REPO" status --porcelain
    [ -z "$output" ]
    before=$(git -C "$REPO" rev-parse "HEAD:.context/episodic/$TID.yaml")
    # A follow-up commit that names the closed task but does not close it.
    echo more > "$REPO/src/more.txt"
    git -C "$REPO" add src/more.txt
    run git -C "$REPO" commit -m "$TID: follow-up after close"
    [ "$status" -eq 0 ]
    run git -C "$REPO" status --porcelain
    echo "$output"
    [ -z "$output" ]
    # The footprint stays as committed at close.
    [ "$(git -C "$REPO" rev-parse "HEAD:.context/episodic/$TID.yaml")" = "$before" ]
    [ "$(_field commits)" = "2" ]
}

@test "t4694: --leave-committed still refreshes an episodic that is not committed" {
    _close
    # The episodic is untracked here: refreshing it changes nothing about cleanliness.
    run python3 "$LIB" "$TID" --leave-committed --project-root "$REPO" --commit x
    [ "$status" -eq 0 ]
    echo "$output"
    echo "$output" | grep -q "footprint refreshed" || [ "$(_field commits)" = "1" ]
    _counters_match_history
}

@test "t4690: a modified episodic without a task move is not predicted" {
    run python3 -c '
import sys; sys.path.insert(0, sys.argv[1])
import episodic_footprint as ef
a = "T-9" + "001"; b = "T-9" + "002"; c = "T-9" + "003"
ns = "\n".join([
    f"M\t.context/episodic/{a}.yaml",
    f"A\t.context/episodic/{b}.yaml",
    f"M\t.context/episodic/{c}.yaml",
    f"A\t.tasks/completed/{c}-x.md",
    f"D\t.tasks/active/{c}-x.md",
])
print(" ".join(ef.close_candidates(ns)))' "$FRAMEWORK_ROOT/lib"
    [ "$status" -eq 0 ]
    [ "$output" = "T-9002 T-9003" ]
}
