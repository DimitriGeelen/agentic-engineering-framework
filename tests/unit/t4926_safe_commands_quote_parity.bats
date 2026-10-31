#!/usr/bin/env bats
# T-4926 / T-4927 (SECURITY; ring20-dashboard forwarded review, msg ddc0cd83): the
# read-only classifier and bash disagreed about where a quoted string or a `$((` ends,
# so a write clause bash runs was never judged and passed as read-only:
#   - `$'…'` (ANSI-C): a backslash-escaped quote does not close it in bash;
#   - `"…"`: a backslash escapes `"`;
#   - `$((…)` is arithmetic only when it ends `))`, else a command substitution.
# Nothing here executes the commands: the classifier only reads the text.

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export PROJECT_ROOT="$ROOT" FRAMEWORK_ROOT="$ROOT"
    # shellcheck source=/dev/null
    source "$ROOT/agents/context/lib/safe-commands.sh"
}

_ro()  { is_bash_safe_command "$1" >/dev/null 2>&1; }

@test "a write hidden behind \$'…' with an escaped quote is not read-only" {
    ! _ro "cat \$'a\\'b' ; touch /tmp/t4926-x" || false
    ! _ro "echo \$'\\'' \$(touch /tmp/t4926-x)" || false
    ! _ro "cat \$'\\'' <(touch /tmp/t4926-x)" || false
    ! _ro "echo \\\\\$'a\\'b' ; touch /tmp/t4926-x" || false
}

@test "a write hidden behind a backslash-escaped double quote is not read-only" {
    ! _ro 'echo "a\"" ; touch /tmp/t4926-x' || false
}

@test "\$((…) that is really a command substitution is judged (T-4927)" {
    ! _ro 'echo $((touch /tmp/t4926-x); echo)' || false
    ! _ro 'echo $(( $(touch /tmp/t4926-x) ))' || false
}

@test "read-only commands with the same quoting stay read-only" {
    _ro "cat README.md"
    _ro "echo \$'a\\tb'"
    _ro 'echo "a\"b"'
    _ro "echo \\\$'x' README.md"
    _ro 'echo $((1+2))'
    _ro "git status 2>&1"
    _ro "grep -c 'x' README.md"
}

@test "the clause splitter keeps an escaped-quote string in one segment" {
    run bash -c 'source "$1/agents/context/lib/safe-commands.sh"; _fw_chain_split "$2" | tr "\0" "\n"' _ "$ROOT" "echo \$'a\\'b' ; touch x"
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c 'touch x')" -eq 1 ]
    printf '%s\n' "$output" | grep -qx ' touch x'
}

# T-4934 (ring20-dashboard msg f7af90f0): T-4926 itself read `$$'` as an ANSI-C string.
# `$$` is the PID; the quote after it is plain, so only an ODD run of `$` opens $'…'.
@test "\$\$' is the PID and a plain quote, not an ANSI-C string (T-4934)" {
    ! _ro "echo \$\$'\\' ; touch /tmp/t4926-x #'" || false
    _ro "echo \$\$'abc'"
    _ro "echo \$\$\$'a\\'b'"
}
