#!/usr/bin/env bats
# Issue #78: has_bash_write_pattern exempted every `2>`, so `cmd 2> file` (a truncating
# write) classified as read-only and passed the Tier-1 gate. The old leading class `[^2>&]`
# tested the character BEFORE the operator, but `2>&1` and `2> file` differ only AFTER it.
#
# Pins both directions: real file writes are WRITE; descriptor duplication and /dev/null
# discards are not. Also pins the /dev/null boundary (a /dev/null PREFIX of a real path must
# stay a write) and the SIGPIPE fail-open on large inputs.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    source "$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"
}

@test "#78: numbered-fd redirect to a file (the #78 bypass) — WRITE: bin/fw audit 2> out.txt" {
    run has_bash_write_pattern 'bin/fw audit 2> out.txt'
    [ "$status" -eq 0 ]
}

@test "#78: numbered-fd append to a file — WRITE: bin/fw audit 2>> out.txt" {
    run has_bash_write_pattern 'bin/fw audit 2>> out.txt'
    [ "$status" -eq 0 ]
}

@test "#78: &> writes both streams to a file — WRITE: bin/fw audit &> out.txt" {
    run has_bash_write_pattern 'bin/fw audit &> out.txt'
    [ "$status" -eq 0 ]
}

@test "#78: &>> appends both streams to a file — WRITE: bin/fw audit &>> out.txt" {
    run has_bash_write_pattern 'bin/fw audit &>> out.txt'
    [ "$status" -eq 0 ]
}

@test "#78: 3> is a write — WRITE: bin/fw audit 3> out.txt" {
    run has_bash_write_pattern 'bin/fw audit 3> out.txt'
    [ "$status" -eq 0 ]
}

@test "#78: 1> is a write — WRITE: bin/fw audit 1> out.txt" {
    run has_bash_write_pattern 'bin/fw audit 1> out.txt'
    [ "$status" -eq 0 ]
}

@test "#78: plain > is a write — WRITE: bin/fw audit > out.txt" {
    run has_bash_write_pattern 'bin/fw audit > out.txt'
    [ "$status" -eq 0 ]
}

@test "#78: plain >> is a write — WRITE: bin/fw audit >> out.txt" {
    run has_bash_write_pattern 'bin/fw audit >> out.txt'
    [ "$status" -eq 0 ]
}

@test "#78: trailing operator fails closed — WRITE: bin/fw audit >" {
    run has_bash_write_pattern 'bin/fw audit >'
    [ "$status" -eq 0 ]
}

@test "#78: 2>&1 duplicates a descriptor — not a write: bin/fw audit 2>&1" {
    run has_bash_write_pattern 'bin/fw audit 2>&1'
    [ "$status" -ne 0 ]
}

@test "#78: 1>&2 duplicates a descriptor — not a write: bin/fw audit 1>&2" {
    run has_bash_write_pattern 'bin/fw audit 1>&2'
    [ "$status" -ne 0 ]
}

@test "#78: >&2 duplicates to stderr — not a write: echo problem >&2" {
    run has_bash_write_pattern 'echo problem >&2'
    [ "$status" -ne 0 ]
}

@test "#78: 2>&- closes a descriptor — not a write: bin/fw audit 2>&-" {
    run has_bash_write_pattern 'bin/fw audit 2>&-'
    [ "$status" -ne 0 ]
}

@test "#78: 2>&1 | tail read idiom — not a write: git status 2>&1 | tail -5" {
    run has_bash_write_pattern 'git status 2>&1 | tail -5'
    [ "$status" -ne 0 ]
}

@test "#78: 2>/dev/null discards, opens no file — not a write: bin/fw audit 2>/dev/null" {
    run has_bash_write_pattern 'bin/fw audit 2>/dev/null'
    [ "$status" -ne 0 ]
}

@test "#78: 2> /dev/null with a space — not a write: cmd 2> /dev/null" {
    run has_bash_write_pattern 'cmd 2> /dev/null'
    [ "$status" -ne 0 ]
}

@test "#78: >/dev/null — not a write: cmd >/dev/null" {
    run has_bash_write_pattern 'cmd >/dev/null'
    [ "$status" -ne 0 ]
}

@test "#78: >>/dev/null — not a write: cmd >>/dev/null" {
    run has_bash_write_pattern 'cmd >>/dev/null'
    [ "$status" -ne 0 ]
}

@test "#78: 2>/dev/stderr — not a write: cmd 2>/dev/stderr" {
    run has_bash_write_pattern 'cmd 2>/dev/stderr'
    [ "$status" -ne 0 ]
}

@test "#78: >/dev/stdout — not a write: cmd >/dev/stdout" {
    run has_bash_write_pattern 'cmd >/dev/stdout'
    [ "$status" -ne 0 ]
}

@test "#78: real write beside /dev/null is still a write — WRITE: cmd > out.txt 2>/dev/null" {
    run has_bash_write_pattern 'cmd > out.txt 2>/dev/null'
    [ "$status" -eq 0 ]
}

@test "#78: same mix, reversed order — WRITE: cmd 2>/dev/null > out.txt" {
    run has_bash_write_pattern 'cmd 2>/dev/null > out.txt'
    [ "$status" -eq 0 ]
}

@test "#78: /dev/null prefix of a real path is still a write — WRITE: cmd > /dev/nullish" {
    run has_bash_write_pattern 'cmd > /dev/nullish'
    [ "$status" -eq 0 ]
}

@test "#78: /dev/null.bak is a real file — WRITE: cmd > /dev/null.bak" {
    run has_bash_write_pattern 'cmd > /dev/null.bak'
    [ "$status" -eq 0 ]
}

@test "#78: /dev/null_backup is a real file — WRITE: cmd > /dev/null_backup" {
    run has_bash_write_pattern 'cmd > /dev/null_backup'
    [ "$status" -eq 0 ]
}

@test "#78: sed -i is a write — WRITE: sed -i 's/a/b/' f.txt" {
    run has_bash_write_pattern 'sed -i '\''s/a/b/'\'' f.txt'
    [ "$status" -eq 0 ]
}

@test "#78: sed -i.bak is a write — WRITE: sed -i.bak s/a/b/ f.txt" {
    run has_bash_write_pattern 'sed -i.bak s/a/b/ f.txt'
    [ "$status" -eq 0 ]
}

@test "#78: sed -ni is a write — WRITE: sed -ni s/a/b/ f.txt" {
    run has_bash_write_pattern 'sed -ni s/a/b/ f.txt'
    [ "$status" -eq 0 ]
}

@test "#78: sed --in-place is a write — WRITE: sed --in-place s/a/b/ f" {
    run has_bash_write_pattern 'sed --in-place s/a/b/ f'
    [ "$status" -eq 0 ]
}

@test "#78: sed -n is a read — not a write: sed -n '1,5p' plain.txt" {
    run has_bash_write_pattern 'sed -n '\''1,5p'\'' plain.txt'
    [ "$status" -ne 0 ]
}

@test "#78: -i inside a filename is not an in-place flag — not a write: sed -n '1,5p' data-in-flight.txt" {
    run has_bash_write_pattern 'sed -n '\''1,5p'\'' data-in-flight.txt'
    [ "$status" -ne 0 ]
}

@test "#78: a large matching command is still a WRITE (no SIGPIPE fail-open under pipefail)" {
    # The match is on the FIRST line and ~500KB follows. grep -q exits on the first matching
    # line, so an `echo "$cmd" | grep -q` producer overflows the pipe buffer and takes SIGPIPE;
    # under pipefail that reads as "no write pattern" -- failing OPEN. Passed via a file
    # because a single argv string this large exceeds MAX_ARG_STRLEN.
    { echo 'echo x > out.txt'; seq 1 60000 | sed 's/^/: /'; } > "$TEST_TEMP_DIR/cmd"
    run bash -c 'set -eo pipefail; source "$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"; has_bash_write_pattern "$(cat "$1")"' _ "$TEST_TEMP_DIR/cmd"
    [ "$status" -eq 0 ]
}
