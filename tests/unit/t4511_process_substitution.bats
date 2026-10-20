#!/usr/bin/env bats
#
# T-4511 (SECURITY, G-121): process substitution runs a command whatever the outer
# verb is, and the read-only allowlist judged only the outer verb: `cat <(touch x)`,
# `grep x <(touch x)` and `diff <(touch a) <(touch b)` read as SAFE (the redirect scan
# only sees `>`). Reported by ring20-dashboard (msg af2bbc85).
#
# Fix: is_bash_safe_command refuses `<(` / `>(` anywhere on the line
# (_fw_has_process_subst), skipping only an escaped character and, on a line with no
# double quote, single-quoted text. Classification only: nothing here is executed.
#
# `! cmd` at statement position is INERT in bats (L-628), so NOT-SAFE assertions use
# `if cmd; then false; fi`.

load helpers/known_cwd

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    known_cwd_setup
    source "$ROOT/agents/context/lib/safe-commands.sh"
}

teardown() { known_cwd_teardown; }

_refused() {
    local c
    for c in "$@"; do
        if is_bash_safe_command "$c"; then echo "SAFE (expected gated): $c"; return 1; fi
    done
}

_safe() {
    local c
    for c in "$@"; do
        is_bash_safe_command "$c" || { echo "gated (expected SAFE): $c"; return 1; }
    done
}

@test "T-4511: the probe's process-substitution lines are NOT SAFE" {
    _refused 'cat <(touch pwned)' 'grep x <(touch pwned)' 'diff <(touch a) <(touch b)'
}

@test "T-4511: output substitution, chains, loops and nesting are NOT SAFE" {
    _refused 'cat >(touch x)' 'ls && cat <(x)' 'cat F | grep x <(y)' \
        'while read -r l; do echo "$l"; done < <(touch x)' \
        'X=$(cat <(touch x))' 'cat "$(cat <(x))"'
}

@test "T-4511: a quote inside double quotes does not hide a later substitution" {
    _refused "grep \"it's\" <(touch x)" "cat \"\$(echo ')')\" <(touch x)" "grep '\"' <(touch x)"
}

@test "T-4511: a quoted or escaped mention stays SAFE" {
    _safe "grep '<(' F" "grep -F '>(' F" 'grep \<\( F'
}

@test "T-4511: controls stay SAFE" {
    _safe 'git grep pattern' "awk '{print \$1}' F" 'sed -n 1p F' 'cat F' \
        'while read -r l; do echo "$l"; done < F' 'grep -c x F'
}
