#!/usr/bin/env bats
# T-4827: the block message must name the segment that actually failed the check.
#
# Field report (TermLink be.39 test C3): with focus empty, the block for
#   git status --short | head -30; echo ---; git log --oneline -5; …; fw runme pending
# said '"git status --short " is not on the read-only allowlist', although
# is_bash_safe_command('git status --short') is safe. The culprit-naming loop in
# _bash_gate_reason judged each segment without the git-cwd context
# (_FW_GIT_CWD from _FW_PAYLOAD_CWD / PROJECT_ROOT) the verdict used, so every git
# segment failed there and the first one was named. The verdict was right; the
# named culprit sent the reader to file an allowlist gap that does not exist.

load ../git_fence

setup() {
    _FW_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    GATE="$_FW_ROOT/agents/context/check-active-task.sh"
    [ -f "$GATE" ] || skip "hook not found"

    TEST_ROOT="$(mktemp -d)"
    P="$TEST_ROOT/p"
    mkdir -p "$P/.tasks/active" "$P/.context/working"
    git -C "$P" init -q
    echo "version: test" > "$P/.framework.yaml"
    echo "session_id: S-test" > "$P/.context/working/session.yaml"
    echo "completed: 2026-01-01T00:00:00Z" > "$P/.context/working/.onboarding-complete"
    P="$(cd "$P" && pwd -P)"
    # Empty focus, as in the field report.
    printf 'current_task:\n' > "$P/.context/working/focus.yaml"
    export CLAUDECODE=1
    unset FW_SAFE_MODE FW_SESSION_SCOPED_FOCUS FW_FOCUS_SESSION_KEY CONTEXT_DIR TASKS_DIR
    unset AI_AGENT _FW_PATHS_DERIVED_BY _FW_GIT_CWD
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

# gate_bash <command> — payload cwd is the project, as in a normal session.
gate_bash() {
    local input
    input=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","cwd":sys.argv[1],"tool_input":{"command":sys.argv[2]}}))' "$P" "$1")
    run env PROJECT_ROOT="$P" bash "$GATE" <<< "$input"
}

named_line() { echo "$output" | grep 'is not on the read-only allowlist' || true; }

@test "the field command is refused (the verdict is unchanged)" {
    gate_bash 'git status --short | head -30; echo ---; git log --oneline -5; echo ---; ./deploy.sh'
    [ "$status" -ne 0 ]
}

@test "the named culprit is the non-safe segment, not a git read" {
    gate_bash 'git status --short | head -30; echo ---; git log --oneline -5; echo ---; ./deploy.sh'
    [ "$status" -ne 0 ]
    local named; named="$(named_line)"
    echo "named: $named"; echo "$output"
    echo "$named" | grep -q '"./deploy.sh"'
    ! echo "$named" | grep -q 'git status' || false
}

@test "control: git status alone is safe in the same context" {
    gate_bash 'git status --short'
    [ "$status" -eq 0 ]
}

@test "a git segment after a cd to elsewhere is named when it is the real culprit" {
    # -C resolution follows the chain's cd: git -C into a non-project dir is not a
    # project read, so naming it there is correct.
    gate_bash "cd /; git -C $TEST_ROOT status; ./deploy.sh"
    [ "$status" -ne 0 ]
    named_line | grep -q '"git -C '
}

@test "every segment safe alone but the whole refused: no safe segment is named" {
    # A loop whose body changes directory: each segment passes alone, the loop is
    # refused as a whole (T-4396). The message must not blame a safe segment.
    gate_bash 'for d in a b; do cd "$d"; done'
    [ "$status" -ne 0 ]
    echo "$output"; [ -z "$(named_line)" ]
    echo "$output" | grep -q 'not recognised'
}
