#!/usr/bin/env bats
# T-3098: check-worktree-governance-write PreToolUse hook — unit tests.
#
# Fixture is a REAL `git worktree add`, not a mocked path shape. That is the
# point of the task: detection must be the git-dir vs git-common-dir invariant
# (lib/paths.sh:fw_is_linked_worktree), not a ".claude/worktrees" substring, so
# the test has to exercise a genuine linked worktree for the assertion to mean
# anything.
#
# Four states named in the ACs:
#   linked worktree + .tasks/ → blocked
#   linked worktree + lib/    → allowed
#   MAIN checkout  + .tasks/  → allowed   ← the one that matters most: a false
#                                            positive here breaks every session
#   bypass env set            → allowed AND logged

setup() {
    _FW_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    HOOK="$_FW_ROOT/agents/context/check-worktree-governance-write.sh"
    [ -f "$HOOK" ] || skip "hook not found: $HOOK"

    TEST_ROOT="$(mktemp -d)"
    MAIN="$TEST_ROOT/main"
    mkdir -p "$MAIN"

    git -C "$MAIN" init -q 2>/dev/null
    mkdir -p "$MAIN/.tasks/active" "$MAIN/.context/working" "$MAIN/lib"
    echo "task" > "$MAIN/.tasks/active/T-0001-x.md"
    echo "ctx"  > "$MAIN/.context/working/focus.yaml"
    echo "src"  > "$MAIN/lib/thing.sh"
    git -C "$MAIN" add -A >/dev/null 2>&1
    git -C "$MAIN" -c user.email=t@t -c user.name=t commit -qm "T-3098: fixture" >/dev/null 2>&1

    WT="$TEST_ROOT/wt"
    git -C "$MAIN" worktree add -q -b t3098-fixture "$WT" >/dev/null 2>&1
    [ -d "$WT/.tasks/active" ] || skip "git worktree add did not reproduce tracked governance state"

    export CLAUDECODE=1
    unset FW_ALLOW_WORKTREE_GOVERNANCE_WRITE AI_AGENT
}

teardown() {
    if [ -n "${MAIN:-}" ] && [ -d "$MAIN" ]; then
        git -C "$MAIN" worktree remove --force "$WT" >/dev/null 2>&1 || true
    fi
    rm -rf "$TEST_ROOT" 2>/dev/null
}

# ── helper ────────────────────────────────────────────────────────────────────

# run_hook <cwd> <file_path> [tool_name]
run_hook() {
    local cwd="$1" fp="$2" tool="${3:-Write}"
    local input
    input=$(python3 -c '
import json, sys
print(json.dumps({"tool_name": sys.argv[3], "cwd": sys.argv[1],
                  "tool_input": {"file_path": sys.argv[2], "content": "x"}}))
' "$cwd" "$fp" "$tool")
    run env PROJECT_ROOT="$cwd" bash "$HOOK" <<< "$input"
}

# ── AC #7 state 1: linked worktree + .tasks/ → blocked ────────────────────────

@test "linked worktree: write to .tasks/ is blocked" {
    run_hook "$WT" "$WT/.tasks/active/T-0001-x.md"
    [ "$status" -eq 2 ]
    [[ "$output" == *"GOVERNANCE WRITE FROM A LINKED WORKTREE"* ]]
}

@test "linked worktree: write to .context/ is blocked" {
    run_hook "$WT" "$WT/.context/working/focus.yaml"
    [ "$status" -eq 2 ]
}

@test "linked worktree: relative governance path is resolved against cwd and blocked" {
    run_hook "$WT" ".tasks/active/T-0001-x.md"
    [ "$status" -eq 2 ]
}

# ── AC #3: block message names the correct move AND the bypass ────────────────

@test "block message names the main checkout as the correct move" {
    run_hook "$WT" "$WT/.tasks/active/T-0001-x.md"
    [ "$status" -eq 2 ]
    [[ "$output" == *"$MAIN"* ]]
    [[ "$output" == *"master"* ]]
}

@test "block message names the bypass env var" {
    run_hook "$WT" "$WT/.tasks/active/T-0001-x.md"
    [ "$status" -eq 2 ]
    [[ "$output" == *"FW_ALLOW_WORKTREE_GOVERNANCE_WRITE=1"* ]]
    [[ "$output" == *".gate-bypass-log.yaml"* ]]
}

# ── AC #7 state 2: linked worktree + non-governance path → allowed ────────────

@test "linked worktree: write to lib/ is allowed" {
    run_hook "$WT" "$WT/lib/thing.sh"
    [ "$status" -eq 0 ]
}

@test "linked worktree: absolute write into the MAIN checkout's .tasks/ is allowed" {
    # This is the move the block message recommends; it must not be refused.
    run_hook "$WT" "$MAIN/.tasks/active/T-0001-x.md"
    [ "$status" -eq 0 ]
}

# ── AC #7 state 3: MAIN checkout → never blocked (highest-risk false positive) ─

@test "main checkout: write to .tasks/ is allowed" {
    run_hook "$MAIN" "$MAIN/.tasks/active/T-0001-x.md"
    [ "$status" -eq 0 ]
}

@test "main checkout: write to .context/ is allowed" {
    run_hook "$MAIN" "$MAIN/.context/working/focus.yaml"
    [ "$status" -eq 0 ]
}

@test "non-git directory: governance-shaped write is allowed" {
    mkdir -p "$TEST_ROOT/plain/.tasks/active"
    run_hook "$TEST_ROOT/plain" "$TEST_ROOT/plain/.tasks/active/T-0002-y.md"
    [ "$status" -eq 0 ]
}

# ── AC #7 state 4: bypass → allowed AND logged ────────────────────────────────

@test "bypass env: write is allowed and logged Tier-2 with the path" {
    export FW_ALLOW_WORKTREE_GOVERNANCE_WRITE=1
    run_hook "$WT" "$WT/.tasks/active/T-0001-x.md"
    [ "$status" -eq 0 ]
    local log="$WT/.context/working/.gate-bypass-log.yaml"
    [ -f "$log" ]
    grep -q "flag: 'FW_ALLOW_WORKTREE_GOVERNANCE_WRITE'" "$log"
    grep -q "caller: 'check-worktree-governance-write'" "$log"
    # AC #5: the entry must record the path, so "does any real workflow need
    # this?" is answerable from the register.
    grep -q "file: '$WT/.tasks/active/T-0001-x.md'" "$log"
}

@test "bypass env: no log entry is written when the gate would not have blocked" {
    export FW_ALLOW_WORKTREE_GOVERNANCE_WRITE=1
    run_hook "$MAIN" "$MAIN/.tasks/active/T-0001-x.md"
    [ "$status" -eq 0 ]
    [ ! -f "$MAIN/.context/working/.gate-bypass-log.yaml" ]
}

# ── pass-throughs ─────────────────────────────────────────────────────────────

@test "non-write tool in a worktree is allowed" {
    run_hook "$WT" "$WT/.tasks/active/T-0001-x.md" "Read"
    [ "$status" -eq 0 ]
}

@test "outside agent control the gate is advisory, not blocking" {
    unset CLAUDECODE
    run_hook "$WT" "$WT/.tasks/active/T-0001-x.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"would block under agent control"* ]]
}
