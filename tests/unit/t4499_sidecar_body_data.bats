#!/usr/bin/env bats
#
# T-4499: the Human-AC tick guard (check-human-ac-tick, Bash leg) refused
# `fw sidecar send ... --body '<text>'` because the message quoted an example git
# command with a variable --output option (`git log --output="$F"`) next to a .tasks
# path. lib/shell_write_scan.py turned the backticks inside the single-quoted body
# into command breaks (_tokens) and read the backtick body as a substitution
# (_substitutions), so `git log --output=$F` became a git command with an unresolved
# --output target in a command that names a guarded path.
#
# Fix: _blank_data_args blanks a SINGLE-quoted --body value of `fw sidecar send`
# before scanning. Double-quoted bodies stay scanned (bash runs $(..)/`..` there).
#
# Both directions go through the real hook under CLAUDECODE=1.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    HOOK_SH="$FRAMEWORK_ROOT/agents/context/check-human-ac-tick.sh"
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active"
    T=".tasks/active/T-9999-test.md"
    printf -- '---\nid: T-9999\n---\n' > "$TEST_ROOT/$T"
    BT='`'
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

# ── the field report: message bodies are data ──────────────────────────────────

@test "T-4499: single-quoted --body quoting a backticked git --output=\$F next to a .tasks path is allowed" {
    assert_allowed "bin/fw sidecar send --to peer --conversation c --body 'T-4485: ${BT}git log --output=\"\$F\"${BT} is now refused; see $T'"
}

@test "T-4499: --body= form, \$(..) in the body, and a .agentic-framework fw path are allowed" {
    assert_allowed "bin/fw sidecar send --to peer --body='run \$(git diff --output=\$OUT) on $T'"
    assert_allowed ".agentic-framework/bin/fw sidecar send --to peer --conversation c --body 'sed -i s/a/b/ $T; echo x > $T'"
    assert_allowed "cd /x && fw sidecar send --to peer --body '${BT}git show --output \$F${BT} $T'"
}

# ── real writes in the same command line are still refused ────────────────────

@test "T-4499: a redirect into .tasks after a sidecar body is still refused" {
    assert_refused "bin/fw sidecar send --to peer --body 'hello' > $T"
    assert_refused "bin/fw sidecar send --to peer --body 'hello'; sed -i s/a/b/ $T"
}

@test "T-4499: a double-quoted --body runs its substitutions, so it is still scanned" {
    assert_refused "bin/fw sidecar send --to peer --body \"\$(sed -i s/a/b/ $T)\""
    assert_refused "bin/fw sidecar send --to peer --body \"${BT}git log --output=\$F${BT} $T\""
}

@test "T-4499: a quote-attached body, another verb, or a fake quote inside double quotes is not exempt" {
    assert_refused "bin/fw sidecar send --to peer --body 'x'\"\$(sed -i s/a/b/ $T)\""
    assert_refused "bin/fw bus post --summary '${BT}git log --output=\$F${BT}' $T"
    assert_refused "echo \"fw sidecar send --body '\" ; sed -i s/a/b/ $T ; echo \"'\""
}

@test "T-4499: the git --output vector itself is still refused outside a body" {
    assert_refused "git log --output=\$F $T"
}
