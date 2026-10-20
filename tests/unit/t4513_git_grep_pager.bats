#!/usr/bin/env bats
#
# T-4513 (SECURITY, G-121): the read-only allowlist admitted `git grep` by verb name.
# git grep -O[CMD] / --open-files-in-pager[=CMD] STARTS CMD (default: the pager) on
# the matching files. Reported by ring20-dashboard (msg af2bbc85).
#
# Fix: agents/context/lib/safe-commands.sh _fw_git_grep_opens_pager — judged on the
# dequoted words (_fw_option_words): a short bundle with O before an argument-taking
# letter, any unambiguous prefix of --open-files-in-pager, or a word that begins with
# an expansion is refused. Classification only: nothing here is executed.
#
# `! cmd` at statement position is INERT in bats (L-628), so NOT-SAFE assertions use
# `if cmd; then false; fi`.

load helpers/known_cwd

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    known_cwd_setup
    cd "$ROOT"
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

@test "T-4513: the probe's git grep lines are NOT SAFE" {
    _refused "git grep -O pattern" "git grep --open-files-in-pager=touch pattern"
}

@test "T-4513: short bundles and an attached command are NOT SAFE" {
    _refused "git grep -Ovim pattern" "git grep -iO pattern" "git grep -nOcat x" \
        "git -C . grep -O pattern" "git --no-pager grep -O x"
}

@test "T-4513: the long option, its abbreviations and its separate value are NOT SAFE" {
    _refused "git grep --open-files-in-pager pattern" "git grep --open-f pattern" \
        "git grep --op=x pattern" "git grep --open-files-in-pager touch pattern"
}

@test "T-4513: a quoted or expanded option is NOT SAFE" {
    _refused "git grep -'O' pattern" "git grep \"--open-files-in-pager=x\" pattern" \
        'git grep "$P" pattern' "git grep \$'-O' pattern" "git grep -{O,n} pattern"
}

@test "T-4513: ordinary git grep and the G-121 controls stay SAFE" {
    _safe "git grep pattern" "git grep -n -e foo" "git grep -C3 foo" "git grep -i --or foo" \
        "git grep -e FOO" "git grep -eO" "git grep --only-matching foo" \
        "git grep -n 'T-4513' -- lib" "awk '{print \$1}' F" "sed -n 1p F"
}
