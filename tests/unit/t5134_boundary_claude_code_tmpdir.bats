#!/usr/bin/env bats
# T-5134 (dimitri-mint-dev T-226): with CLAUDE_CODE_TMPDIR set, Claude Code keeps the
# session scratchpad and task-output files under <dir>/claude-<uid>/. The boundary hook
# allows Bash reads there, and only there: the rest of <dir>, another account's subtree
# and the rest of /var/tmp stay refused, as before.
#
# The hook is FED each command; nothing here is executed.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
    TMPROOT="$(mktemp -d /var/tmp/t5134.XXXXXX)"
    U="$(id -u)"
    OTHER=$((U + 1))
    unset PROJECT_ROOT CLAUDE_CODE_TMPDIR
    CWD="$FRAMEWORK_ROOT"
}

teardown() { rm -rf "$TMPROOT"; }

hook() {   # hook <command> [CLAUDE_CODE_TMPDIR] -> 0 allowed, 2 blocked
    local json
    json=$(python3 -c 'import json,sys
print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]},"cwd":sys.argv[2]}))' "$1" "$CWD")
    if [ $# -ge 2 ]; then
        output=$(printf '%s' "$json" | CLAUDE_CODE_TMPDIR="$2" bash "$HOOK" 2>&1)
    else
        output=$(printf '%s' "$json" | bash "$HOOK" 2>&1)
    fi
}

assert_rc() {   # assert_rc <want> <command> [tmpdir]
    local want="$1"; shift
    local rc=0
    hook "$@" || rc=$?
    [ "$rc" -eq "$want" ] || { echo "want rc=$want, got rc=$rc for: $1 (tmpdir=${2-unset})" >&2; echo "$output" >&2; return 1; }
}

@test "control: without CLAUDE_CODE_TMPDIR the session subtree is refused (the reported case)" {
    assert_rc 2 "cat $TMPROOT/claude-$U/proj/sess/tasks/x.output"
}

@test "with CLAUDE_CODE_TMPDIR: a file under <dir>/claude-<uid>/ is readable" {
    assert_rc 0 "cat $TMPROOT/claude-$U/proj/sess/tasks/x.output" "$TMPROOT"
}

@test "with CLAUDE_CODE_TMPDIR: the rest of <dir> stays refused" {
    assert_rc 2 "cat $TMPROOT/other/file" "$TMPROOT"
}

@test "with CLAUDE_CODE_TMPDIR: another account's subtree stays refused" {
    assert_rc 2 "cat $TMPROOT/claude-$OTHER/proj/x" "$TMPROOT"
}

@test "with CLAUDE_CODE_TMPDIR: a name that only starts like the subtree stays refused" {
    assert_rc 2 "cat $TMPROOT/claude-${U}0/x" "$TMPROOT"
}

@test "with CLAUDE_CODE_TMPDIR: the rest of /var/tmp stays refused" {
    assert_rc 2 "cat /var/tmp/somewhere-else/x" "$TMPROOT"
}

@test "a relative or empty CLAUDE_CODE_TMPDIR adds nothing" {
    assert_rc 2 "cat $TMPROOT/claude-$U/x" "relative/dir"
    assert_rc 2 "cat $TMPROOT/claude-$U/x" ""
}

@test "CLAUDE_CODE_TMPDIR=/ does not open /claude-<uid> wider than before" {
    assert_rc 2 "cat /var/tmp/x" "/"
}
