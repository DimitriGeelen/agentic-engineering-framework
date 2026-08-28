#!/usr/bin/env bats
# T-3206: the continuous-run loop can say it is ARMED, not only why it stopped.
#
# T-3182 shipped six exit reasons and one iterate. Measured on a live wrapper,
# `.context/working/continuous-run.jsonl` did not exist — so an armed supervisor
# and an absent one were byte-identical on disk, which is the precise false green
# T-3182 was filed to kill. It survived inside its own fix because a log that only
# records endings cannot come into existence until the loop is already over.
#
# ── why these tests EXTRACT AND RUN the shipped source ────────────────────────
# 832 (offset 689): "a guard that reimplements the code it guards cannot detect
# that code being fixed — the tell is a check whose assertion would still hold if
# the source file were deleted." 577 (offset 690) sharpened it: prefer a guard
# that INVOKES its subject over one that RESTATES it.
#
# `fw doctor` takes 267s end-to-end, so invoking the whole command per state is
# not viable. Instead each test slices the SHIPPED block out of bin/fw or
# bin/claude-fw and executes those literal lines. That is borrowing the
# implementation, not describing it: delete the block and the extraction is empty
# and the test goes red, which is exactly what a restating guard cannot do.
# `assert_extracted` makes that failure mode explicit rather than incidental.
#
# ── on negations ──────────────────────────────────────────────────────────────
# `! cmd` at statement position is INERT in bats (POSIX exempts `set -e` after
# `!`, and bats reads only the last command's status). Uses `if cmd; then false; fi`.
# Origin T-3199; sibling lint tracked in T-3191.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    CFW="$REPO_ROOT/bin/claude-fw"
    FW="$REPO_ROOT/bin/fw"

    # A throwaway git repo: _record_loop_event resolves its log path via
    # `git rev-parse --show-toplevel`, so it must run inside one.
    SANDBOX="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$SANDBOX/.context/working"
    git -C "$SANDBOX" init -q 2>/dev/null || true
    LEDGER="$SANDBOX/.context/working/continuous-run.jsonl"
}

# Slice the real _record_loop_event out of bin/claude-fw and source it.
recorder() {
    sed -n '/^_record_loop_event() {/,/^}/p' "$CFW"
}

# Slice the real doctor ledger check out of bin/fw. `local` is illegal outside a
# function, so the block is wrapped in one — the block's own lines are untouched.
doctor_block() {
    sed -n '/# Check: continuous-run loop ledger (T-3206/,/# Check: on-PATH claude-fw drift/p' "$FW" \
        | head -n -1
}

assert_extracted() {
    # The whole extract-and-run design rests on this: if the block is gone, the
    # slice is empty and every downstream assertion would pass vacuously.
    [ -n "$1" ]
    [ "$(printf '%s' "$1" | wc -l)" -gt 5 ]
}

run_doctor_block() {
    local body
    body="$(doctor_block)"
    assert_extracted "$body"
    run bash -c "
        GREEN=''; YELLOW=''; CYAN=''; NC=''
        PROJECT_ROOT='$SANDBOX'
        warnings=0
        _blk() {
        $body
        }
        _blk
        echo \"WARNINGS=\$warnings\"
    "
}

# ── the start event: arm time, not end time ──────────────────────────────────

@test "CONTROL: a start event is recorded BEFORE the loop, not inside it" {
    # Ordering is the whole point. A start event emitted inside `while true`
    # would re-fire per iteration and still could not distinguish an armed loop
    # from an absent one at t=0, which is the state that was unobservable.
    local start_line loop_line
    start_line=$(grep -n '_record_loop_event start armed' "$CFW" | head -1 | cut -d: -f1)
    loop_line=$(grep -n '^while true; do' "$CFW" | head -1 | cut -d: -f1)
    [ -n "$start_line" ]
    [ -n "$loop_line" ]
    [ "$start_line" -lt "$loop_line" ]
}

@test "the recorder writes a start line with reason=armed" {
    local body; body="$(recorder)"; assert_extracted "$body"
    run bash -c "cd '$SANDBOX'; AUTO_RESTART=true; MAX_RESTARTS=5
        $body
        _record_loop_event start armed 'restart=enabled max_restarts=5 termlink=0'"
    [ "$status" -eq 0 ]
    [ -f "$LEDGER" ]
    run bash -c "python3 -c \"
import json;d=json.load(open('$LEDGER'))
assert d['event']=='start', d
assert d['reason']=='armed', d
assert d['wrapper_pid']>0, d
print(d['detail'])\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"max_restarts=5"* ]]
    [[ "$output" == *"restart=enabled"* ]]
}

@test "the start detail distinguishes an armed loop from a --no-restart one" {
    # Both write a start line; only the detail says whether the loop can restart.
    # Without this an operator reading the ledger cannot tell a supervisor that
    # WILL recover from one that merely ran once.
    run bash -c "grep -A3 '_record_loop_event start armed' '$CFW'"
    [ "$status" -eq 0 ]
    [[ "$output" == *'AUTO_RESTART'* ]]
    [[ "$output" == *'disabled'* ]]
    [[ "$output" == *'enabled'* ]]
}

@test "the recorder is non-fatal when the log cannot be written" {
    # It runs on exit paths. A broken recorder must never change the wrapper's
    # exit code or block a restart.
    local body; body="$(recorder)"; assert_extracted "$body"
    chmod 500 "$SANDBOX/.context/working"
    run bash -c "cd '$SANDBOX'
        $body
        _record_loop_event start armed 'detail'; echo RC=\$?"
    chmod 700 "$SANDBOX/.context/working"
    [ "$status" -eq 0 ]
    [[ "$output" == *"RC=0"* ]]
}

# ── the doctor surface: THREE outcomes, not two ──────────────────────────────

@test "absent ledger reports never-recorded rather than staying silent" {
    # Silence is the failure mode being fixed: it is indistinguishable from a
    # healthy loop that simply has nothing to say.
    run_doctor_block
    [[ "$output" == *"never recorded"* ]]
    [[ "$output" == *"claude-fw"* ]]
}

@test "a start line from a LIVE wrapper reports ARMED and confirms the pid" {
    printf '{"ts":"2026-08-28T14:00:00Z","event":"start","reason":"armed","restart_count":0,"wrapper_pid":%d,"detail":"restart=enabled max_restarts=5"}\n' "$$" > "$LEDGER"
    run_doctor_block
    [[ "$output" == *"ARMED"* ]]
    [[ "$output" == *"is alive"* ]]
    [[ "$output" == *"WARNINGS=0"* ]]
}

@test "a start line from a DEAD wrapper is a warning, not a green ARMED" {
    # The killed-outright case: SIGKILL or a host reboot leaves a start line with
    # no exit line after it. Reporting that as ARMED would be a new false green
    # of exactly the shape this task exists to remove.
    dead=$(bash -c 'echo $$')
    while kill -0 "$dead" 2>/dev/null; do dead=$((dead + 1)); done
    printf '{"ts":"2026-08-28T14:00:00Z","event":"start","reason":"armed","restart_count":0,"wrapper_pid":%d}\n' "$dead" > "$LEDGER"
    run_doctor_block
    [[ "$output" == *"GONE with no exit record"* ]]
    [[ "$output" == *"WARNINGS=1"* ]]
}

@test "an exit line reports STOPPED and names the reason" {
    printf '{"ts":"2026-08-28T14:05:00Z","event":"exit","reason":"max-restarts","restart_count":5,"wrapper_pid":123,"detail":"restart_count reached MAX_RESTARTS=5","exit_code":0}\n' > "$LEDGER"
    run_doctor_block
    [[ "$output" == *"STOPPED"* ]]
    [[ "$output" == *"max-restarts"* ]]
    [[ "$output" == *"MAX_RESTARTS=5"* ]]
    [[ "$output" == *"WARNINGS=1"* ]]
}

@test "the LAST line wins — a restarted loop is armed, not stopped" {
    # An exit followed by a later start is a loop that came back. Reading the
    # first line, or any line but the last, would report a live loop as dead.
    {
      printf '{"ts":"2026-08-28T14:00:00Z","event":"exit","reason":"no-signal","restart_count":1,"wrapper_pid":123}\n'
      printf '{"ts":"2026-08-28T14:09:00Z","event":"iterate","reason":"restart","restart_count":2,"wrapper_pid":%d}\n' "$$"
    } > "$LEDGER"
    run_doctor_block
    [[ "$output" == *"ARMED"* ]]
    if printf '%s' "$output" | grep -q "STOPPED"; then false; fi
}

@test "an empty ledger is its own state, not armed and not stopped" {
    printf '' > "$LEDGER"
    run_doctor_block
    [[ "$output" == *"never recorded an event"* ]]
    if printf '%s' "$output" | grep -q "ARMED"; then false; fi
    if printf '%s' "$output" | grep -q "STOPPED"; then false; fi
}

@test "a corrupt ledger line does not crash the check" {
    printf 'not json at all\n' > "$LEDGER"
    run_doctor_block
    [ "$status" -eq 0 ]
}

@test "the three states are mutually distinguishable" {
    # The task's claim in one assertion: armed / stopped / never-recorded must
    # produce three DIFFERENT outputs. Any two collapsing is the original defect.
    printf '{"ts":"t","event":"start","reason":"armed","restart_count":0,"wrapper_pid":%d}\n' "$$" > "$LEDGER"
    run_doctor_block; local armed="$output"
    printf '{"ts":"t","event":"exit","reason":"no-signal","restart_count":0,"wrapper_pid":1}\n' > "$LEDGER"
    run_doctor_block; local stopped="$output"
    rm -f "$LEDGER"
    run_doctor_block; local never="$output"
    [ "$armed" != "$stopped" ]
    [ "$stopped" != "$never" ]
    [ "$armed" != "$never" ]
}
