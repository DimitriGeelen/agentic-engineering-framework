#!/usr/bin/env bats
# T-2958: P-011 must not eval a line whose backticks bash will command-substitute.
#
# The gate evals each Verification line. Markdown writes code with backticks, so
# `grep -q "``" f` reaches eval as `grep -q "" f` — matches any file — and a
# code-fence regex inside "…" runs its middle as a command. Both lines PARSE, so
# T-2991's preflight lets them through. T-446 shipped the collapsed-regex shape;
# T-1413 escaped that one line and the rule never generalised.
#
# The e2e test proves the refusal on evidence: the offending line would create a
# file if eval'd, and the file must not exist afterwards.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    LIB="$FRAMEWORK_ROOT/lib/verification-port.sh"
    [ -f "$LIB" ] || skip "lib/verification-port.sh not found"
    source "$LIB"
}

teardown() {
    if [ -n "${P:-}" ]; then rm -rf "$P"; fi
    unset FW_ALLOW_BACKTICK_VERIFICATION
    return 0
}

_flagged()     { [ -n "$(find_unquoted_backtick_lines "$1")" ]; }
_not_flagged() { [ -z "$(find_unquoted_backtick_lines "$1")" ]; }

# --- the defect itself: these parse, and they pass emptily ---

@test "T-2958: the collapsed pair parses and passes against a backtick-free file" {
    f="$BATS_TEST_TMPDIR/plain"; printf 'x\n' > "$f"
    line='grep -q "``" '"$f"
    [ -z "$(find_unparseable_verification_lines "$line")" ]
    ( eval "$line" )
}

# --- flagged ---

@test "T-2958: a backtick pair inside double quotes is flagged" {
    _flagged 'grep -q "``" f'
}

@test "T-2958: the T-446 code-fence regex inside double quotes is flagged" {
    _flagged 'python3 -c "import re; re.sub(r'"'"'```[a-z]*```'"'"','"'"''"'"',t)"'
}

@test "T-2958: a bare legacy substitution is flagged" {
    _flagged 'test "x" = `echo x`'
}

@test "T-2958: a backtick after a single-quoted span is still flagged" {
    _flagged "grep -q 'a' f && echo \`\`"
}

# --- not flagged ---

@test "T-2958: a backtick inside single quotes is not flagged" {
    _not_flagged "grep -q '\`\`\`' f"
}

@test "T-2958: a backslash-escaped backtick is not flagged (bare and in double quotes)" {
    _not_flagged 'grep -q "\`\`" f'
    _not_flagged 'echo \`x\`'
}

@test "T-2958: an ANSI-C string and \$(...) are not flagged" {
    _not_flagged "printf \$'\\x60\\'' x"
    _not_flagged 'test "$(echo x)" = x'
}

@test "T-2958: single quotes nested in \$(...) inside double quotes are honoured" {
    _not_flagged "test \"\$(grep -cE '^\\| \`[^\`]+\`' f)\" -ge 1"
}

@test "T-2958: a backtick in a trailing comment is not flagged" {
    _not_flagged 'true # see `x`'
}

@test "T-2958: check_verification_backticks refuses, and the bypass lets it through" {
    run check_verification_backticks 'grep -q "``" f'
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'FW_ALLOW_BACKTICK_VERIFICATION'
    FW_ALLOW_BACKTICK_VERIFICATION=1 run check_verification_backticks 'grep -q "``" f'
    [ "$status" -eq 0 ]
}

# --- end to end through the real close gate ---

_make_project() {
    P="$(mktemp -d)"
    mkdir -p "$P/.tasks/active" "$P/.tasks/completed" "$P/.context/working"
    { printf -- '---\nid: T-9999\nname: "fixture"\nstatus: started-work\n'
      printf 'workflow_type: build\nowner: agent\nhorizon: now\n'
      printf 'created: 2026-08-31T00:00:00Z\nlast_update: 2026-08-31T00:00:00Z\n---\n\n'
      printf '# T-9999: fixture\n\n## Context\n\nx\n\n## Acceptance Criteria\n\n### Agent\n- [x] done\n\n'
      printf '## Verification\n\n%s\n\n' "$1"
      printf '## Decisions\n\n'; } > "$P/.tasks/active/T-9999-fixture.md"
}

_close() {
    PROJECT_ROOT="$P" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        timeout 120 bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" \
        T-9999 --status work-completed 2>&1
}

@test "T-2958: the close gate refuses the line before eval reaches it" {
    _make_project 'touch ran && grep -q "``" ran'
    run _close
    [ "$status" -ne 0 ]
    echo "$output" | grep -q 'backtick(s) bash will substitute'
    [ ! -e "$P/ran" ]
    [ -f "$P/.tasks/active/T-9999-fixture.md" ]
}

@test "T-2958: a single-quoted backtick line is not refused by this check" {
    _make_project "grep -q '\`' /dev/null || true"
    run _close
    [[ "$output" != *'backtick(s) bash will substitute'* ]]
}
