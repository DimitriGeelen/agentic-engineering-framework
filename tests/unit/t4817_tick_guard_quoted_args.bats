#!/usr/bin/env bats
#
# T-4817: the Human-AC tick guard (check-human-ac-tick, Bash leg) refused
# `fw sidecar send --body '…'` whose body only QUOTED a `git log … "$f"` example next
# to a .tasks path (ring20 be.37 field test C addendum, msg 1df20c21).
#
# T-4499 exempted a --body value only when the word was one bare '…'. Any other
# quoting of the same literal text — the apostrophe idioms '…'"'"'…' and '…'\''…',
# $'…', or an escaped backtick in double quotes — fell through to _tokens /
# _substitutions, which read every backtick as a command. These cases use no `--`,
# so T-4816's end-of-options fix cannot mask them.
#
# Fix: lib/shell_write_scan.py:_blank_data_args lexes the word (_lex_spans) and
# blanks everything except the substitutions bash really runs, which stay scanned.
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
    Q="'"
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

# ── the field report: a quoted body is data, however it is quoted ─────────────

@test "T-4817: body with the '\"'\"' apostrophe idiom quoting git log \"\$f\" is allowed" {
    assert_allowed "fw sidecar send --to x --body ${Q}It refused ${BT}git log --oneline -3 \"\$f\"${BT} (f = $T). The report${Q}\"${Q}\"${Q}s C(b)${Q}"
}

@test "T-4817: body with the '\\'' apostrophe idiom is allowed" {
    assert_allowed "fw sidecar send --to x --body ${Q}a${Q}\\${Q}${Q}b ${BT}git log -1 \"\$f\"${BT} $T${Q}"
}

@test "T-4817: \$'...' body and escaped backticks in a double-quoted body are allowed" {
    assert_allowed "fw sidecar send --to x --body \$${Q}a\\${Q}b ${BT}git log -1 \"\$f\"${BT} $T${Q}"
    assert_allowed "fw sidecar send --to x --body \"It refused \\${BT}git log --oneline -3 \\\"\\\$f\\\"\\${BT} ($T)\""
    assert_allowed "fw sidecar send --to x --body \"a ${Q}b${Q} \\${BT}sed -i s/a/b/ $T\\${BT}\""
}

@test "T-4817: a multi-line body naming write commands is allowed" {
    assert_allowed "fw sidecar send --to x --body ${Q}(1) refused:
git log --oneline -1 \"\$f\"
(2) and: sed -i s/a/b/ $T; echo x > $T${Q}\"${Q}\"${Q}s end${Q}"
}

# ── what bash really runs is still a command ─────────────────────────────────

@test "T-4817: a real substitution inside a mixed-quoted body is still refused" {
    assert_refused "fw sidecar send --to x --body ${Q}it${Q}\"${Q}\"${Q}s ${Q}\"\$(sed -i s/a/b/ $T)\""
    assert_refused "fw sidecar send --to x --body \"a \\${BT}x\\${BT} ${BT}sed -i s/a/b/ $T${BT}\""
    assert_refused "fw sidecar send --to x --body \$${Q}a\\${Q}b${Q}\$(tee $T)"
}

@test "T-4817: a real write in the same command line is still refused" {
    assert_refused "fw sidecar send --to x --body ${Q}a${Q}\\${Q}${Q}b${Q} > $T"
    assert_refused "fw sidecar send --to x --body \"a \\${BT}b\\${BT}\"; sed -i s/a/b/ $T"
}

@test "T-4817: an unbalanced body is not exempt (fails closed)" {
    assert_refused "fw sidecar send --to x --body ${Q}a${Q}\"b ${BT}sed -i s/a/b/ $T${BT}"
}
