#!/usr/bin/env bats
# T-3231 — the `--help` exemption must not skip every gate.
#
# Finding C2 of the arc-012 review. check-active-task.sh took an unconditional
# `exit 0` ahead of every gate whenever `--help` matched ANYWHERE in the command,
# including inside a quoted argument. Appending seven characters opted any command
# out of governance.
#
# WHY THIS DRIVES THE REAL HOOK rather than re-implementing its predicate: a guard
# that reimplements the code it guards cannot detect that code being fixed — or
# re-broken (peer 577-CashWeb's G-072 class, and the reason T-3228's suite extracts
# the real brake instead of copying it). Here we run the actual script.
#
# WHY THE TEMP PROJECT ROOT: with an active task in focus the gate allows
# everything, so exempt and non-exempt are INDISTINGUISHABLE. Testing this against
# the live repo produced a table of all-zeros twice — once before the fix, once
# after — which reads exactly like success. The fixture has no active task, which
# is the only state where the exemption is observable.
#
# THE TWO CONTROLS ARE LOAD-BEARING. `always_gated` proves the harness can gate;
# `t2410_origin_still_allowed` proves it can allow. A harness stuck at one answer
# passes half these tests while measuring nothing.

setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # T3231_HOOK_OVERRIDE lets the mutation harness point this suite at a
    # sandboxed copy, so mutation testing never edits the live governance hook.
    # Unset in normal runs, which is what the close gate executes.
    HOOK="${T3231_HOOK_OVERRIDE:-$REPO/agents/context/check-active-task.sh}"
    FIXTURE="$(mktemp -d)"
    mkdir -p "$FIXTURE/.context/working" "$FIXTURE/.tasks/active"
    printf 'current_task: null\n' > "$FIXTURE/.context/working/focus.yaml"
}

teardown() {
    [ -n "${FIXTURE:-}" ] && rm -rf "$FIXTURE"
}

# Returns 0 when the hook ALLOWS the command, non-zero when it GATES it.
hook_allows() {
    local cmd="$1" payload
    payload=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$cmd")
    printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$FIXTURE" PROJECT_ROOT="$FIXTURE" \
        bash "$HOOK" >/dev/null 2>&1
}

@test "control: a plain destructive write is gated (harness can gate)" {
    ! hook_allows 'rm -rf /important/data'
}

@test "control: a plain redirect is gated (harness can gate)" {
    ! hook_allows 'echo "x" > /etc/passwd'
}

@test "leg 2: --help appended to a destructive command no longer exempts" {
    ! hook_allows 'rm -rf /important/data --help'
}

@test "leg 1: --help hidden in a quoted payload no longer exempts a real write" {
    ! hook_allows 'echo "the --help flag" > /etc/passwd'
}

@test "T-2410 origin case still allowed (harness can allow)" {
    hook_allows 'fw upstream --help'
}

@test "T-2410 chained case still allowed" {
    hook_allows 'cd /tmp && fw upstream --help'
}

@test "--version gets the same narrowing as --help" {
    ! hook_allows 'rm -rf /important/data --version'
    hook_allows 'fw upstream --version'
}

@test "the exemption fails CLOSED when the write predicate is unavailable" {
    # If safe-commands.sh cannot be sourced, has_bash_write_pattern is undefined.
    # The condition must then be false (gate), never true (exempt). Simulated by
    # pointing the hook at a copy whose lib/ is empty.
    local sandbox; sandbox="$(mktemp -d)"
    mkdir -p "$sandbox/lib"
    cp "$HOOK" "$sandbox/check-active-task.sh"
    : > "$sandbox/lib/safe-commands.sh"
    local payload
    payload=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' 'rm -rf /important/data --help')
    run bash -c "printf '%s' '$payload' | CLAUDE_PROJECT_DIR='$FIXTURE' PROJECT_ROOT='$FIXTURE' bash '$sandbox/check-active-task.sh'"
    rm -rf "$sandbox"
    [ "$status" -ne 0 ]
}

# ── Leg 1 in isolation ────────────────────────────────────────────────────────
#
# The first draft of this suite could not tell leg 1 from leg 2: mutation M1
# (revert the quote-strip) reddened NOTHING, because the only quoted-payload test
# was `echo "… --help …" > /etc/passwd`, whose redirect survives stripping and is
# therefore caught by leg 2 anyway. A mutation that reddens nothing is a finding
# about the suite, not a clean bill of health — so here is the case where leg 1 is
# the ONLY thing gating.
#
# It needs a DIFFERENT fixture: an active task in focus, and a command attributed
# to another task. Nothing here is a write, so the write-pattern predicate never
# votes; the gate that should fire is focus-drift. Pre-fix, `--help` inside the
# quoted tag value skipped it — which makes this the more serious instance of C2,
# since focus-drift is the most-bypassed gate in the log.

setup_drift_fixture() {
    DRIFT="$(mktemp -d)"
    mkdir -p "$DRIFT/.context/working" "$DRIFT/.tasks/active"
    printf 'current_task: T-3231\n' > "$DRIFT/.context/working/focus.yaml"
    printf -- '---\nid: T-3231\nstatus: started-work\n---\n' > "$DRIFT/.tasks/active/T-3231-x.md"
    printf -- '---\nid: T-3229\nstatus: started-work\n---\n' > "$DRIFT/.tasks/active/T-3229-y.md"
}

drift_allows() {
    local cmd="$1" payload
    payload=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$cmd")
    printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$DRIFT" PROJECT_ROOT="$DRIFT" \
        bash "$HOOK" >/dev/null 2>&1
}

@test "control: a cross-task command is gated by focus-drift (fixture can gate)" {
    setup_drift_fixture
    run drift_allows 'bin/fw task update T-3229 --add-tag ui'
    rm -rf "$DRIFT"
    [ "$status" -ne 0 ]
}

@test "leg 1 isolated: --help in a quoted value no longer skips focus-drift" {
    setup_drift_fixture
    run drift_allows 'bin/fw task update T-3229 --add-tag "see --help first"'
    rm -rf "$DRIFT"
    [ "$status" -ne 0 ]
}
