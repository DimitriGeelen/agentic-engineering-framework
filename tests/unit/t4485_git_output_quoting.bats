#!/usr/bin/env bats
#
# T-4485 (SECURITY): T-4367's git --output check matched RAW words, so every shell
# spelling that produces the word `--output=FILE` only after bash has processed it —
# quotes, a backslash, a variable, a parameter default, a loop variable — read as SAFE
# while git wrote FILE. Reported by ring20-dashboard (msg 9fc80de4, probe
# tmp/t4367_probe.sh) on v1.8.13.
#
# Fix: the diff-family verbs are judged on the words bash will hand git
# (lib/shell_write_scan.py git_output_risk: dequoted, brace-expanded), and any
# expansion bash performs before git sees the word ($, a backtick, an unquoted glob)
# fails closed. The write scanner reads the same shapes as an unresolved target.
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

# --- the field probe, every line ------------------------------------------------------

@test "T-4485: double-quoted --output is NOT SAFE" {
    _refused 'git diff "--output=/tmp/x"' 'git log -p "--output=/tmp/x"' 'git diff "--output" /tmp/x'
}

@test "T-4485: single-quoted --output is NOT SAFE" {
    _refused "git diff '--output=/tmp/x'" "git show '--out'=/tmp/x HEAD"
}

@test "T-4485: backslash-split --output is NOT SAFE" {
    _refused 'git diff --out\put=/tmp/x' 'git diff \--output=/tmp/x'
}

@test "T-4485: ANSI-C quoted --output is NOT SAFE" {
    _refused "git diff \$'--output=/tmp/x'" "git diff \$'\\x2d-output=/tmp/x'"
}

@test "T-4485: a variable carrying --output is NOT SAFE" {
    _refused 'o=--output=/tmp/x; git diff $o' 'git diff $o' 'git diff "$o"' 'git diff ${o}'
}

@test "T-4485: a parameter default carrying --output is NOT SAFE" {
    _refused 'git diff ${O:---output=/tmp/x}' 'git log "${O:---output=/tmp/x}"'
}

@test "T-4485: a loop variable passed to git diff is NOT SAFE" {
    _refused 'for o in --output=/tmp/x; do git diff $o; done' \
             'for o in a; do git log "$o"; done'
}

@test "T-4485: command substitution and backticks stay NOT SAFE" {
    _refused 'git diff $(echo --output=/tmp/x)' 'git diff `echo --output=/tmp/x`'
}

@test "T-4485: brace expansion and unquoted globs are NOT SAFE" {
    _refused 'git diff {--output=/tmp/x,HEAD}' 'git diff --ou*' 'git diff *'
}

# --- controls: plain reads stay SAFE ----------------------------------------------------

@test "T-4485 control: plain diff-family reads stay SAFE" {
    local c
    for c in 'git diff HEAD' 'git log --oneline -5' 'git diff "HEAD"' \
             'git log --format="%h %s" -3' "git diff -- '*.py'" 'git show HEAD:README.md' \
             'git diff --stat HEAD~1' 'git log -g HEAD@{1}' 'git diff --output-indicator-new=+'; do
        is_bash_safe_command "$c" || { echo "GATED (expected safe): $c"; false; }
    done
}

# --- write scanner reads the same shapes ------------------------------------------------

@test "T-4485: shell_write_scan reports every expansion shape aimed at a task file" {
    run python3 -I -c '
import sys
sys.path.insert(0, sys.argv[1] + "/lib")
import shell_write_scan as s
P = sys.argv[1]
T = ".tasks/active/T-1.md"
bad = [
    "git diff \"--output=%s\"" % T,
    "git diff --out\\put=%s" % T,
    "o=--output=%s; git diff $o" % T,
    "git diff ${O:---output=%s}" % T,
    "for o in --output=%s; do git diff $o; done" % T,
    "git log -p \"--output=%s\"" % T,
    "git diff {--output=%s,HEAD}" % T,
]
for c in bad:
    assert s.scan(c, P), "no hit: " + c
assert not s.scan("git diff HEAD", P)
assert s.git_output_risk("git diff \"--output=/tmp/x\"")
assert s.git_output_risk("git diff $o")
assert not s.git_output_risk("git log --format=\"%h %s\" -3")
assert not s.git_output_risk("git status $o")
' "$ROOT"
    echo "$output"
    [ "$status" -eq 0 ]
}
