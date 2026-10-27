#!/usr/bin/env bats
# T-4820: gate deadlock in a linked worktree that has no focus.yaml of its own.
#
# Field report (055 be.37 test C): with the shell cwd inside a linked worktree
# whose .context/working/focus.yaml does not exist, check-active-task refused
# every Bash command — a plain `cd <main checkout>` included — while
# check-worktree-governance-write refused creating that focus file with Write.
# The only exit was a bootstrap line typed from the main checkout.
#
# Fixture is a REAL `git worktree add` of a temp repo (never of this repo):
# fw_is_linked_worktree keys on git-dir vs git-common-dir, so a mocked path
# shape would not exercise it. focus.yaml is deliberately untracked, which is
# what leaves the worktree without one.

load ../git_fence

setup() {
    _FW_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    GATE="$_FW_ROOT/agents/context/check-active-task.sh"
    GOV="$_FW_ROOT/agents/context/check-worktree-governance-write.sh"
    [ -f "$GATE" ] && [ -f "$GOV" ] || skip "hooks not found"

    TEST_ROOT="$(mktemp -d)"
    MAIN="$TEST_ROOT/main"
    WT="$TEST_ROOT/wt"
    mkdir -p "$MAIN/.tasks/active" "$MAIN/.context/working"
    git -C "$MAIN" init -q
    echo "version: test" > "$MAIN/.framework.yaml"
    echo "session_id: S-test" > "$MAIN/.context/working/session.yaml"
    echo "completed: 2026-01-01T00:00:00Z" > "$MAIN/.context/working/.onboarding-complete"
    cat > "$MAIN/.tasks/active/T-0001-t.md" <<'MD'
---
id: T-0001
name: "t"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
---
# T-0001
## Acceptance Criteria
### Agent
- [ ] Real AC one
MD
    git -C "$MAIN" add .framework.yaml .tasks .context/working/session.yaml \
        .context/working/.onboarding-complete
    git -C "$MAIN" -c user.email=t@t -c user.name=t commit -qm "T-4820: fixture"
    # Main checkout has an active focus; it is untracked, so the worktree has none.
    printf 'current_task: T-0001\nfocus_session: S-test\n' > "$MAIN/.context/working/focus.yaml"

    git -C "$MAIN" worktree add -q -b t4820-fixture "$WT" >/dev/null 2>&1
    [ -d "$WT/.context/working" ] || skip "worktree did not carry tracked .context/working"
    [ ! -f "$WT/.context/working/focus.yaml" ] || skip "worktree unexpectedly has focus.yaml"

    MAIN="$(cd "$MAIN" && pwd -P)"
    WT="$(cd "$WT" && pwd -P)"
    export CLAUDECODE=1
    unset FW_SAFE_MODE FW_SESSION_SCOPED_FOCUS FW_FOCUS_SESSION_KEY CONTEXT_DIR TASKS_DIR
    unset FW_ALLOW_WORKTREE_GOVERNANCE_WRITE AI_AGENT _FW_PATHS_DERIVED_BY
}

teardown() {
    [ -n "${MAIN:-}" ] && git -C "$MAIN" worktree remove --force "$WT" >/dev/null 2>&1 || true
    rm -rf "$TEST_ROOT" 2>/dev/null
}

# gate_bash <cwd> <command> — PROJECT_ROOT simulates bin/fw resolving to MAIN
gate_bash() {
    local input
    input=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","cwd":sys.argv[1],"tool_input":{"command":sys.argv[2]}}))' "$1" "$2")
    run env PROJECT_ROOT="$MAIN" bash "$GATE" <<< "$input"
}

gate_write() {  # <cwd> <file_path>
    local input
    input=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","cwd":sys.argv[1],"tool_input":{"file_path":sys.argv[2],"content":"x"}}))' "$1" "$2")
    run env PROJECT_ROOT="$MAIN" bash "$GATE" <<< "$input"
}

# ── the deadlock legs ─────────────────────────────────────────────────────────

@test "worktree without focus.yaml: plain cd back to the main checkout passes the task gate" {
    gate_bash "$WT" "cd $MAIN"
    [ "$status" -eq 0 ]
}

@test "worktree without focus.yaml: a governed Bash command is decided on the main checkout's focus, not refused as 'session not active'" {
    gate_bash "$WT" "true && echo work > out.txt"
    [[ "$output" != *"session not active"* ]]
    [ "$status" -eq 0 ]
}

@test "worktree without focus.yaml: Write to worktree source is governed by the main checkout's focus" {
    gate_write "$WT" "$WT/src.sh"
    [ "$status" -eq 0 ]
}

@test "worktree without focus.yaml: with main focus null, the block names the main checkout's focus file" {
    printf 'current_task: null\nfocus_session: S-test\n' > "$MAIN/.context/working/focus.yaml"
    gate_write "$WT" "$WT/src.sh"
    [ "$status" -eq 2 ]
    [[ "$output" == *"No active task"* ]]
    [[ "$output" == *"$MAIN/.context/working/focus.yaml"* ]]
}

@test "worktree without focus.yaml: the bootstrap focus verb passes the task gate" {
    gate_bash "$WT" "bin/fw context focus T-0001"
    [ "$status" -eq 0 ]
    gate_bash "$WT" ".agentic-framework/bin/fw work-on T-0001"
    [ "$status" -eq 0 ]
    gate_bash "$WT" "bin/fw context init"
    [ "$status" -eq 0 ]
}

@test "bare cd passes even when main focus is null and the cwd is a worktree" {
    printf 'current_task: null\n' > "$MAIN/.context/working/focus.yaml"
    gate_bash "$WT" "cd $MAIN"
    [ "$status" -eq 0 ]
}

@test "governance-write hook still refuses creating focus.yaml inside the worktree (focus lives in main)" {
    local input
    input=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","cwd":sys.argv[1],"tool_input":{"file_path":sys.argv[2],"content":"x"}}))' "$WT" "$WT/.context/working/focus.yaml")
    run env PROJECT_ROOT="$WT" bash "$GOV" <<< "$input"
    [ "$status" -eq 2 ]
    # ...and names the file the gate actually reads, so the refusal has a route.
    [[ "$output" == *"$MAIN/.context/working/focus.yaml"* ]] || [[ "$output" == *"fw context focus"* ]]
}

# ── reader/writer coherence ───────────────────────────────────────────────────

@test "fw_focus_file in a worktree without its own focus resolves to the main checkout's file" {
    run env -u CONTEXT_DIR -u TASKS_DIR PROJECT_ROOT="$WT" bash -c 'source "$1/lib/paths.sh"; fw_focus_file "$2"' _ "$_FW_ROOT" "$WT"
    [ "$status" -eq 0 ]
    [ "$output" = "$MAIN/.context/working/focus.yaml" ]
}

@test "fw_focus_file in a worktree WITH its own focus keeps the worktree file (T-2463)" {
    printf 'current_task: T-0001\n' > "$WT/.context/working/focus.yaml"
    run env -u CONTEXT_DIR -u TASKS_DIR PROJECT_ROOT="$WT" bash -c 'source "$1/lib/paths.sh"; fw_focus_file "$2"' _ "$_FW_ROOT" "$WT"
    [ "$output" = "$WT/.context/working/focus.yaml" ]
}

@test "fw context focus run inside the worktree writes the file the gate reads" {
    printf 'current_task: null\nfocus_session: S-test\n' > "$MAIN/.context/working/focus.yaml"
    cd "$WT"
    run env -u CLAUDE_PROJECT_DIR PROJECT_ROOT="$WT" "$_FW_ROOT/agents/context/context.sh" focus T-0001
    [ ! -f "$WT/.context/working/focus.yaml" ]
    grep -q 'current_task: T-0001' "$MAIN/.context/working/focus.yaml"
    gate_write "$WT" "$WT/src.sh"
    [ "$status" -eq 0 ]
}

@test "fw context init run inside the worktree does not fork a worktree focus.yaml" {
    cd "$WT"
    run env -u CLAUDE_PROJECT_DIR PROJECT_ROOT="$WT" "$_FW_ROOT/agents/context/context.sh" init
    [ ! -f "$WT/.context/working/focus.yaml" ]
    [ -f "$MAIN/.context/working/focus.yaml" ]
}

# ── controls: non-worktree behaviour unchanged ────────────────────────────────

@test "control: main checkout with no focus.yaml still blocks a governed write" {
    rm -f "$MAIN/.context/working/focus.yaml"
    gate_write "$MAIN" "$MAIN/src.sh"
    [ "$status" -eq 2 ]
}

@test "control: cd chained with a write is not exempted" {
    printf 'current_task: null\n' > "$MAIN/.context/working/focus.yaml"
    gate_bash "$MAIN" "cd $MAIN && echo x > f.txt"
    [ "$status" -eq 2 ]
}
