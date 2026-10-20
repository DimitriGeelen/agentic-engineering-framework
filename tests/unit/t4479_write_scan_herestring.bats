#!/usr/bin/env bats
#
# T-4479 — termlink proposal 349 (their T-3178/T-3370), re-derived at HEAD.
#
# 1. SIGPIPE fail-open. check-active-task.sh runs with pipefail. The write
#    scan used `echo "$cmd" | grep -qE`: on a multi-line command larger than
#    the 64KB pipe buffer, grep -q matches line 1 and exits, echo takes
#    SIGPIPE, the pipeline returns 141, and the scan reported "no write".
#    Measured at HEAD: `rm x` + 5000 lines classified as a read 5/5. Fix:
#    herestrings. (The python -c check in is_bash_safe_command has the same
#    shape and was converted too, but is not tested here: the chain splitter
#    is quadratic, so a >64KB command does not reach it in useful time.)
# 2. `sed -n p notes-in-x.md` read as an in-place sed (`\bsed\b.*-i`). Fix:
#    anchor on a flag token. termlink's anchor let `-iE` and `--in` through;
#    the write corpus below pins both.
# 3. /dev/stdout and /dev/stderr join the /dev/null strip (T-3643).
#
# `! cmd` at statement position is INERT in bats (L-628) — negative
# assertions use `if cmd; then false; fi`.

load ../test_helper
load helpers/known_cwd

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    known_cwd_setup
    source "${T4479_LIB:-$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh}"
    BIG="$(yes 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' | head -n 5000)"
}

teardown() {
    known_cwd_teardown
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

_not_write() { if has_bash_write_pattern "$1"; then echo "WRITE: $1"; false; fi; }
_write()     { has_bash_write_pattern "$1" || { echo "NOT WRITE: ${1:0:60}"; false; }; }

@test "T-4409 fail-closed: no payload cwd and PWD != PROJECT_ROOT gates git status" {
    run known_cwd_assert_fail_closed "$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"
    [ "$status" -eq 0 ] || { echo "$output"; false; }
}

# ── 1. large multi-line commands under pipefail ──────────────────────────────

@test "T-4479 pipefail: 'rm x' + 240KB of lines is a write" {
    set -o pipefail
    _write "rm x
$BIG"
}
@test "T-4479 pipefail: 'tee x' + 240KB of lines is a write" {
    set -o pipefail
    _write "echo y | tee x
$BIG"
}
@test "T-4479 pipefail: '> out' + 240KB of lines is a write" {
    set -o pipefail
    _write "echo hi > out
$BIG"
}
@test "T-4479 pipefail: '2>out' + 240KB of lines is a write" {
    set -o pipefail
    _write "echo hi 2>out
$BIG"
}
@test "T-4479 pipefail: 'sed -i' + 240KB of lines is a write" {
    set -o pipefail
    _write "sed -i s/a/b/ f
$BIG"
}
@test "T-4479 control: the same large command without a write is a read" {
    set -o pipefail
    _not_write "cat f
$BIG"
}

# ── 2. sed -i anchored on a flag ─────────────────────────────────────────────

@test "T-4479: 'sed -n p notes-in-x.md' is a read" { _not_write "sed -n p notes-in-x.md"; }
@test "T-4479: 'sed -n p a/b-index.md' is a read"  { _not_write "sed -n p a/b-index.md"; }
@test "T-4479 neg: 'sed -i s/a/b/ f' is a write"      { _write "sed -i s/a/b/ f"; }
@test "T-4479 neg: 'sed -i.bak s/a/b/ f' is a write"  { _write "sed -i.bak s/a/b/ f"; }
@test "T-4479 neg: 'sed -iE s/a/b/ f' is a write"     { _write "sed -iE s/a/b/ f"; }
@test "T-4479 neg: 'sed -ni p f' is a write"          { _write "sed -ni p f"; }
@test "T-4479 neg: 'sed -Ei s/a/b/ f' is a write"     { _write "sed -Ei s/a/b/ f"; }
@test "T-4479 neg: 'sed -E -i s/a/b/ f' is a write"   { _write "sed -E -i s/a/b/ f"; }
@test "T-4479 neg: 'sed --in-place s/a/b/ f' is a write" { _write "sed --in-place s/a/b/ f"; }
@test "T-4479 neg: 'sed --in-place=.b s/a/b/ f' is a write" { _write "sed --in-place=.b s/a/b/ f"; }
@test "T-4479 neg: 'sed --in s/a/b/ f' is a write"    { _write "sed --in s/a/b/ f"; }
@test "T-4479 neg: 'sed \"-i\" s/a/b/ f' is a write"  { _write 'sed "-i" s/a/b/ f'; }
@test "T-4479 neg: \"sed -i'' s/a/b/ f\" is a write"  { _write "sed -i'' s/a/b/ f"; }
@test "T-4479 neg: 'cd d && sed -i s/a/b/ f' is a write" { _write "cd d && sed -i s/a/b/ f"; }

# ── 3. /dev/stdout and /dev/stderr are sinks ─────────────────────────────────

@test "T-4479: 'echo x >/dev/stderr' is a read"     { _not_write "echo x >/dev/stderr"; }
@test "T-4479: 'echo x > /dev/stdout' is a read"    { _not_write "echo x > /dev/stdout"; }
@test "T-4479: 'echo x 1>&2 2>/dev/stderr' is a read" { _not_write "echo x 1>&2 2>/dev/stderr"; }
@test "T-4479: 'cat f >>/dev/stdout' is a read"     { _not_write "cat f >>/dev/stdout"; }
@test "T-4479 neg: '>/dev/stdoutx' is a write"      { _write "echo x >/dev/stdoutx"; }
@test "T-4479 neg: '>/dev/stderr.bak' is a write"   { _write "echo x >/dev/stderr.bak"; }
@test "T-4479 neg: '>/dev/stdout/sub' is a write"   { _write "echo x >/dev/stdout/sub"; }
@test "T-4479 neg: another redirect still bites"    { _write "echo x >/dev/stderr; echo y > out"; }
