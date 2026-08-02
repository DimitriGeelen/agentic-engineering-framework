#!/usr/bin/env bats
# T-2743: the capture-then-pipe idiom is SIGPIPE-safe only below the pipe buffer.
#
# `.tasks/templates/default.md` prescribes `out=$(cmd 2>&1); echo "$out" | grep -q PAT`
# as THE SIGPIPE-safe form for ## Verification (L-387), and T-2090 hardened it to
# single-pipe-only. Both are correct for small captures. Above the 65536-byte pipe
# buffer, with a match early in the stream, the idiom reintroduces exactly the
# SIGPIPE it exists to prevent: echo blocks on the full pipe, grep -q exits on the
# match, echo takes SIGPIPE, and the pipeline exits 141 under pipefail.
#
# These tests pin the MECHANISM, not the wording of the hint. Prose can be
# reworded; the 64KB threshold is a property of the kernel and of how P-011 runs
# each line (`set -eo pipefail`, agents/task-create/update-task.sh).
#
# Origin OBS-137: measured against a live Watchtower page at 146,366 bytes,
# rc=141 on 3/3 runs — deterministic, not racy. Found because a real verification
# line on T-2741 passed by hand and failed at the gate.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "${TEST_TEMP_DIR:?}"
}

# Emit a payload with the match token at the very top, then padding past the
# pipe buffer. Match-early + big-tail is the shape that strands the writer.
_big_payload_cmd() {
    printf 'MATCHME\n'
    # 200KB of padding — comfortably past the 65536-byte pipe buffer.
    head -c 200000 /dev/zero | tr '\0' 'x'
    printf '\n'
}
export -f _big_payload_cmd

# Run a line the way P-011 does: `set -eo pipefail`, one shell per line.
_as_gate() {
    bash -c "set -eo pipefail; $1"
}

@test "T-2743 CONTROL: below the pipe buffer, the template idiom is fine" {
    run _as_gate 'out=$(printf "MATCHME\n%s\n" "$(head -c 1000 /dev/zero | tr "\0" "x")"); echo "$out" | grep -q MATCHME'
    [ "$status" -eq 0 ]
}

@test "T-2743: above the pipe buffer with an early match, the template idiom exits 141" {
    run _as_gate 'out=$(_big_payload_cmd); echo "$out" | grep -q MATCHME'
    [ "$status" -eq 141 ]
}

@test "T-2743: the file-redirect form of the same check passes" {
    run _as_gate "_big_payload_cmd > '$TEST_TEMP_DIR/out.txt' && grep -q MATCHME '$TEST_TEMP_DIR/out.txt'"
    [ "$status" -eq 0 ]
}

@test "T-2743: the file-redirect form still FAILS when the pattern is genuinely absent" {
    # Without this, the previous test is satisfied by any command that exits 0 —
    # it would not distinguish "the check works" from "the check cannot fail".
    run _as_gate "_big_payload_cmd > '$TEST_TEMP_DIR/out.txt' && grep -q NOTPRESENT '$TEST_TEMP_DIR/out.txt'"
    [ "$status" -ne 0 ]
    [ "$status" -ne 141 ]
}

@test "T-2743: the file-redirect form propagates the PRODUCING command's failure" {
    # The reason to prefer `cmd > file && grep` over `out=$(cmd); echo|grep` even
    # when size is not a concern: `out=$(cmd)` discards cmd's exit code, so a
    # failing producer yields an empty capture and the line's verdict comes from
    # grep alone. Here the producer fails and the line must fail with it.
    run _as_gate "false > '$TEST_TEMP_DIR/out.txt' && grep -q ANYTHING '$TEST_TEMP_DIR/out.txt'"
    [ "$status" -ne 0 ]
}

@test "T-2743: rehearsing without pipefail hides the failure — that is why by-hand is not a rehearsal" {
    # Same line, same payload, no `set -eo pipefail`: exits 0. This is precisely
    # the gap between running a verification line in your terminal and running it
    # under P-011, and it is why T-2741's line read green by hand and 141 at close.
    run bash -c 'out=$(_big_payload_cmd); echo "$out" | grep -q MATCHME'
    [ "$status" -eq 0 ]
}

@test "T-2743: the template teaches the corrected form" {
    local tpl="$FRAMEWORK_ROOT/.tasks/templates/default.md"
    run grep -q "65536-byte pipe buffer" "$tpl"
    [ "$status" -eq 0 ]
    run grep -q "DOES NOT REHEARSE THE GATE" "$tpl"
    [ "$status" -eq 0 ]
}
