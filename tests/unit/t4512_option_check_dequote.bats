#!/usr/bin/env bats
#
# T-4512 (SECURITY, G-121): the read-only allowlist's option checks read raw or
# quote-stripped words, so `find . -'exec' touch {} \;` and `curl -'o' F URL` read as
# SAFE while find ran a command and curl wrote F. Reported by ring20-dashboard
# (msg af2bbc85). Same class as T-4485 (git --output), which fixed git alone.
#
# Fix: every option check reads the words the program gets, from one tokenizer
# (agents/context/lib/safe-commands.sh _fw_option_words -> lib/shell_write_scan.py
# option_words: dequoted, ANSI-C decoded, brace-expanded), and refuses what the text
# cannot resolve. Classification only: no command line here is executed.
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

@test "T-4512: find with a quoted or built action predicate is NOT SAFE" {
    _refused "find . -'exec' touch {} \\;" 'find . "-exec" touch {} \;' \
        'find . -e\xec touch {} \;' "find . \$'-exec' touch {} \\;" \
        "find . \$'\\x2dexec' touch {} \\;" 'find . -{exec,name} touch {} +' \
        "find . -'delete'" "find . -'fprint' out"
}

@test "T-4512: find with an expansion in predicate position is NOT SAFE" {
    _refused 'find . "$A" x' 'find . $A' 'find . `echo -delete`' 'find . -name x *'
}

@test "T-4512: curl/wget with a quoted or built output option is NOT SAFE" {
    _refused "curl -'o' pwned http://example.invalid" 'curl "-o" F http://e/' \
        "curl \$'-o' F http://e/" 'curl -{o,s} F http://e/' 'curl "--output=F" http://e/' \
        'curl "$O" F http://e/' "wget -'O' F https://e/"
}

@test "T-4512: sed/sort with a quoted or built in-place/output option is NOT SAFE" {
    _refused "sed -'i' s/a/b/ F" "sed \$'-i' s/a/b/ F" 'sed "--in-place" s/a/b/ F' \
        "sort -'o' F G" 'sort -{o,u} F G' 'sort "--output=F" G'
}

@test "T-4512: git branch/tag with a quoted write flag is NOT a read" {
    _refused "git branch -l x \$'-D'" "git tag -l x '-d'" 'git branch -l "$X"'
}

@test "T-4512: controls stay SAFE" {
    _safe 'find . -name "-delete"' "find . -name '*.md'" 'find . -type f -mtime -1 -print' \
        'find . -iname "*.md" -newer /tmp/ref' 'curl -s https://e/' \
        'curl -sf "$(bin/fw watchtower url)/page"' 'curl -H "Authorization: Bearer $T" https://e/' \
        'curl -o - https://e/' "sed -n '1p' F" 'sed -n 1p F' 'sort -k2 -t, F' \
        "awk '{print \$1}' F" 'git grep pattern' 'git branch -a' 'git tag -l "v1*"'
}

@test "T-4512: option_words kinds and refusals" {
    run python3 -I -c 'import sys
sys.path.insert(0, sys.argv[1])
import shell_write_scan as s
w, _ = s.option_words("find . -'"'"'exec'"'"' \"$X\" \"a$Y\" -{p,q}")
assert w == [("find","L"),(".","L"),("-exec","L"),("$X","E"),("a$Y","L"),("-p","L"),("-q","L")], w
for bad in ("curl $O F", "find . `x`", "find . -name *.md", "find \"x"):
    assert s.option_words(bad)[0] is None, bad
print("ok")' "$ROOT/lib"
    [ "$status" -eq 0 ]
    [ "$output" = ok ]
}
