#!/usr/bin/env bats
#
# T-4857: ring20-dashboard security review of be.46 (msg 72cf84a0, finding 1).
# lib/shell_write_scan.py:scan computed the guarded-path MENTION on the command AFTER
# _blank_data_args removed a `fw sidecar send --body` value. A guarded path that
# appeared only inside the body was therefore invisible to the mention gate, and a
# later write whose target the text cannot resolve went through:
#
#     fw sidecar send --to x --body '.tasks/active/T-1.md'; sed -i s/a/b/ "$_"
#
# bash sets $_ to the previous command's last argument, so sed edits the task file.
# Fix: the mention is read from the ORIGINAL command; blanking only stops the body
# text being parsed as commands (T-4499, T-4817).
#
# The other two concerns, checked here so the verdict is pinned:
#   * `!$` is history expansion, off in non-interactive bash (the Bash tool), so it is
#     a literal `!$` word, not the previous argument.
#   * a non-framework `*/fw` (_FW_VERB) only matters through the mention: running an
#     arbitrary program on a guarded path is outside the text gate (the program is not
#     opened, T-2742), and with the mention read from the original its body no longer
#     hides anything.
#
# Every case goes through the real hook under CLAUDECODE=1 against a temp project.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    HOOK_SH="$FRAMEWORK_ROOT/agents/context/check-human-ac-tick.sh"
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active"
    T=".tasks/active/T-9999-test.md"
    printf -- '---\nid: T-9999\n---\n' > "$TEST_ROOT/$T"
    export PROJECT_ROOT="$TEST_ROOT"
    export CLAUDECODE=1
    unset FW_ALLOW_HUMAN_AC_TICK AI_AGENT
}

teardown() { rm -rf "$TEST_ROOT" 2>/dev/null; }

run_hook_bash() {
    local input
    input=$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}, "cwd": sys.argv[2]}))
' "$1" "$TEST_ROOT")
    run bash "$HOOK_SH" <<< "$input"
}

assert_refused() {
    run_hook_bash "$1"
    [ "$status" -eq 2 ]
    [[ "$output" == *"SHELL WRITE TO A TASK FILE BLOCKED"* ]]
}

assert_allowed() {
    run_hook_bash "$1"
    [ "$status" -eq 0 ]
}

# ── the real hole: a guarded path only in the body, reused through $_ ─────────

@test "T-4857: \$_ after a body naming a task file, then sed -i \"\$_\", is refused" {
    assert_refused "fw sidecar send --to x --body '$T'; sed -i s/a/b/ \"\$_\""
}

@test "T-4857: unquoted \$_ reuse after && is refused" {
    assert_refused "fw sidecar send --to x --body '$T' && sed -i s/a/b/ \$_"
}

@test "T-4857: \${_} redirect target after the body is refused" {
    assert_refused "fw sidecar send --to x --body '$T'; echo x > \"\${_}\""
}

@test "T-4857: a non-framework */fw body naming a task file feeding \$_ is refused" {
    assert_refused "/tmp/evil/fw sidecar send --to x --body '$T'; cp /dev/null \"\$_\""
}

@test "T-4857: bash really hands \$_ the previous last argument (the premise)" {
    run bash -c 'echo a "$1"; printf %s "$_"' _ "$T"
    [ "${lines[1]}" = "$T" ]
}

# ── not a hole: !$ is literal in non-interactive bash ─────────────────────────

@test "T-4857: history expansion is off in non-interactive bash (!\$ is literal)" {
    run bash -c 'set -o | grep -E "^histexpand[[:space:]]+off"'
    [ "$status" -eq 0 ]
    run bash -c 'echo a; printf %s !$'
    [ "$output" = $'a\n!$' ]
}

# ── unchanged: bodies stay data, real writes stay refused ─────────────────────

@test "T-4857: a body that only mentions a task path in text is still allowed" {
    assert_allowed "fw sidecar send --to x --body 'see $T for the RCA'"
}

@test "T-4857: a body quoting a git --output example next to a task path is allowed" {
    assert_allowed "fw sidecar send --to x --body 'it refused \`git log --output=\"\$F\"\` on $T'"
}

@test "T-4857: a body naming a task path, piped to tail, is allowed" {
    assert_allowed "fw sidecar send --to x --body 'see $T' 2>&1 | tail -3"
}

@test "T-4857: a body naming a task path with a resolvable non-guarded redirect is allowed" {
    assert_allowed "fw sidecar send --to x --body 'see $T' > /dev/null 2>&1"
}

@test "T-4857: a foreign */fw run on a task path with no shell write stays allowed (scope)" {
    assert_allowed "/tmp/evil/fw sidecar send --to x --body '$T'"
}
