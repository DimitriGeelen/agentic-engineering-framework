#!/usr/bin/env bats
# T-4284 — the project-boundary hook must not read free TEXT as a redirect or a path.
#
# WRITE side: a multi-line quoted argument of a TermLink segment was split on its inner
# newline (_split_segments), only the first line was blanked as TermLink, and the stray
# closing quote then left the prompt text unquoted, so `<project>` read as a redirect.
# READ side (since T-3768): the value of a free-text option (`-m`, `--body`, `--name`, …)
# that starts with an outside path was judged as a path read.
#
# The hook is FED each command; nothing here is executed. The outside path is built at
# run time so this file's own text is never a command the live hook sees.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
    R="/$(printf 'ro%s' ot)"
    OUT="$R/.t4284-probe"                  # outside the project, never created
    LT='<'; GT='>'
    SCRATCH="/tmp/claude-${LT}uid${GT}/${LT}project${GT}/${LT}session${GT}/scratchpad/..."
    NL=$'\n'
    unset PROJECT_ROOT
    CWD="$FRAMEWORK_ROOT"
}

# Drive the hook with <command>; cwd from $CWD. Returns 0 = allowed, 2 = blocked.
hook() {
    local json
    json=$(python3 -c 'import json,sys
print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]},"cwd":sys.argv[2]}))' "$1" "$CWD")
    output=$(printf '%s' "$json" | bash "$HOOK" 2>&1)
    return $?
}

assert_blocked() {
    local rc=0
    hook "$1" || rc=$?
    [ "$rc" -eq 2 ] || { echo "expected BLOCKED (rc 2), got rc=$rc for: $1" >&2; echo "$output" >&2; return 1; }
}

assert_allowed() {
    local rc=0
    hook "$1" || rc=$?
    [ "$rc" -eq 0 ] || { echo "expected ALLOWED (rc 0), got rc=$rc for: $1" >&2; echo "$output" >&2; return 1; }
}

# ── WRITE side: angle brackets inside a quoted argument are text ──────────────

@test "write: single-line dispatch prompt with <uid>/<project> is allowed" {
    assert_allowed "bin/fw termlink dispatch --task T-1 --prompt \"use ($SCRATCH) ok\""
}

@test "write: MULTI-LINE dispatch prompt with <uid>/<project> is allowed (the origin)" {
    assert_allowed "bin/fw termlink dispatch --task T-1 --prompt \"line one${NL}line two ($SCRATCH) ok\""
}

@test "write: multi-line sidecar body with angle brackets is allowed" {
    assert_allowed "bin/fw sidecar send --to a --body \"line one${NL}see $SCRATCH a ${GT} b\""
}

@test "write control: plain redirect to an outside path still blocks" {
    assert_blocked "echo hi ${GT} $OUT"
}

@test "write control: appending quoted redirect to an outside path still blocks" {
    assert_blocked "echo hi ${GT}${GT} \"$OUT\""
}

@test "write control: fd redirect to an outside path still blocks" {
    assert_blocked "echo hi 2${GT}$OUT"
}

@test "write control: a real read after a multi-line TermLink segment still blocks" {
    assert_blocked "bin/fw termlink dispatch --task T-1 --prompt \"a${NL}b\" && cat $OUT"
}

# ── READ side: free-text option values are text, not path operands ───────────

@test "read: commit message that starts with an outside path is allowed" {
    assert_allowed "git commit -m \"$OUT is mentioned here\" -- README.md"
}

@test "read: multi-line commit message mentioning an outside path is allowed" {
    assert_allowed "git commit -m \"subject${NL}${NL}$OUT is mentioned\" -- README.md"
}

@test "read: dispatch prompt that is an outside path is allowed" {
    assert_allowed "bin/fw termlink dispatch --task T-1 --prompt=\"$OUT\""
}

@test "read: sidecar body naming an outside path is allowed" {
    assert_allowed "bin/fw sidecar send --to a --conversation c --body '$OUT see notes'"
}

@test "read: task name / description naming an outside path are allowed" {
    assert_allowed "bin/fw task create --name \"$OUT\" --description \"see $OUT\""
}

@test "read control: cat of an outside file still blocks (plain, quoted, escaped)" {
    assert_blocked "cat $OUT"
    assert_blocked "cat \"$OUT\""
    assert_blocked "cat ${R%t}\\t/.t4284-probe"
}

@test "read control: quoted outside path to cp / tee still blocks" {
    assert_blocked "cp \"$OUT\" ."
    assert_blocked "tee \"$OUT\" ${LT} README.md"
}

@test "read control: git pathspec / -C outside path still blocks" {
    assert_blocked "git commit -m \"x\" $OUT"
    assert_blocked "git -C $OUT commit -m \"y\""
}

@test "read control: substitution inside a commit message is still judged" {
    assert_blocked "git commit -m \"\$(cat $OUT)\""
}

@test "read control: free-text spellings are not text for other commands (zip -m, gzip --name)" {
    assert_blocked "zip -m out.zip $OUT"
    assert_blocked "gzip --name $OUT"
}
