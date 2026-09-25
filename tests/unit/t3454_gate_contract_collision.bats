#!/usr/bin/env bats
# T-3454 — two gates prescribed mutually exclusive remedies, leaving a
# legitimate action with no permitted route.
#
# Measured deadlock: focus sits on a partial-complete task (work-completed,
# owner human, still in active/) and the action is committing a DIFFERENT,
# already-closed task's artefacts.
#
#   * the focus-drift gate (T-1730) refuses, and its block message prescribes
#     `FW_SWITCH_FOCUS=1 <cmd>` as the universal remedy — explicitly noting
#     that focusing the target is impossible because it is closed;
#   * adding that prefix broke `_fw_is_git_commit_clause`'s `^git commit`
#     anchor, so the commit stopped being recognised as a commit clause, fell
#     through to `_fw_single_command_is_safe`, and was refused as a write —
#     even though the T-3179 block message states a bare commit IS allowed here;
#   * dropping the prefix returns to the focus-drift refusal.
#
# Same class as T-3299 (G-020 blocking both escape routes its own message
# prescribes) but a DIFFERENT fix, so the two are not merged — see ## Decisions.
#
# Second, independent gap closed here: a leading `time` keyword made a line
# unclassifiable, so measuring the cost of an otherwise-permitted command
# turned it into a refusal. The pressure ran against measuring, in a framework
# whose repeated failure mode is acting on unmeasured cost (T-3450/T-3451/L-621).
#
# Every leg has a CONTROL run against the pre-fix library read from git, so
# this file distinguishes "fires correctly" from "always passes".

load ../test_helper

LIB="$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"
# The commit immediately BEFORE this task's fix. Pinned, not HEAD~1: this file
# must keep discriminating after later commits land on top of it.
PREFIX_REF="4578092c4"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    OLD_LIB="$TEST_TEMP_DIR/safe-commands.prefix.sh"
    git -C "$FRAMEWORK_ROOT" show "$PREFIX_REF:agents/context/lib/safe-commands.sh" > "$OLD_LIB"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Evaluate a predicate snippet against a given library copy.
_with() { run bash -c "source '$1'; $2"; }

# Apply a named predicate to a command. The command travels in the ENVIRONMENT,
# never interpolated into the shell source `bash -c` parses — otherwise the test
# harness expands the very constructs under test. Both shapes bit during
# authoring: `FOO=$(id) …` ran `id` in the harness before the predicate saw it,
# and `bash -c 'rm x'`'s inner quotes collided with the wrapper's. Each looked
# exactly like a failing assertion about the code.
#   $1 = library path, $2 = predicate name, $3 = command
_pred() {
    run env FW_T_LIB="$1" FW_T_P="$2" FW_T_CMD="$3" bash -c \
        'source "$FW_T_LIB"; if "$FW_T_P" "$FW_T_CMD"; then echo YES; else echo NO; fi'
}

# The composed verdict, as check-active-task.sh actually evaluates it: the
# write scan runs against the ORIGINAL line and outranks the safe-list. Testing
# is_bash_safe_command alone would be testing one half of a two-part gate —
# `sed -i` is safe-listed by that predicate on its own and always has been.
_verdict_snippet='if has_bash_write_pattern "$C"; then echo BLOCKED_WRITE; elif is_bash_safe_command "$C"; then echo ALLOWED; else echo BLOCKED_GATED; fi'

_verdict() {
    run env FW_T_LIB="$1" C="$2" bash -c \
        "source \"\$FW_T_LIB\"; $_verdict_snippet"
}

# ── The collision itself ──────────────────────────────────────────────────

@test "an env-prefixed commit is recognised as a commit clause" {
    _with "$LIB" '_fw_is_git_commit_clause "FW_SWITCH_FOCUS=1 git commit -m x" && echo YES'
    [ "$status" -eq 0 ]
    [[ "$output" == *"YES"* ]]
}

@test "CONTROL: the pre-fix library did NOT recognise it — the deadlock reproduces" {
    _with "$OLD_LIB" '_fw_is_git_commit_clause "FW_SWITCH_FOCUS=1 git commit -m x" && echo YES || echo NO'
    [ "$status" -eq 0 ]
    [[ "$output" == *"NO"* ]]
}

@test "the partial-complete allowance now admits the focus-drift gate's own remedy" {
    _with "$LIB" 'is_commit_checkpoint_command "FW_SWITCH_FOCUS=1 git commit -q -m msg" && echo YES'
    [ "$status" -eq 0 ]
    [[ "$output" == *"YES"* ]]
}

@test "CONTROL: the pre-fix library refused that same remedy — no line satisfied both gates" {
    _with "$OLD_LIB" 'is_commit_checkpoint_command "FW_SWITCH_FOCUS=1 git commit -q -m msg" && echo YES || echo NO'
    [ "$status" -eq 0 ]
    [[ "$output" == *"NO"* ]]
}

@test "a bare commit is still recognised (the fix did not move the baseline)" {
    _with "$LIB" '_fw_is_git_commit_clause "git commit -m x" && echo YES'
    [ "$status" -eq 0 ]
    [[ "$output" == *"YES"* ]]
}

# ── No gate weakened: execution-causing prefixes stay refused ─────────────

@test "execution-causing env names are still NOT recognised as commit clauses" {
    # The strip stops at a denied name, so the residue does not look like a
    # commit clause and the allowance is never reached. One denylist, reused.
    local c
    for c in "PATH=/tmp git commit -m x" \
             "LD_PRELOAD=/evil.so git commit -m x" \
             "GIT_EDITOR=evil git commit" \
             "GIT_SSH_COMMAND=evil git commit -m x" \
             "IFS=x git commit" \
             "BASH_ENV=/evil git commit"; do
        _with "$LIB" "_fw_is_git_commit_clause \"$c\" && echo YES || echo NO"
        [ "$status" -eq 0 ]
        [[ "$output" == *"NO"* ]]
    done
}

@test "command substitution still disqualifies the commit allowance" {
    _pred "$LIB" is_commit_checkpoint_command 'FOO=$(id) git commit -m x'
    [ "$status" -eq 0 ]
    [ "$output" = "NO" ]
}

@test "--no-verify still voids the allowance, prefix or not" {
    _with "$LIB" 'is_commit_checkpoint_command "FW_SWITCH_FOCUS=1 git commit --no-verify -m x" && echo YES || echo NO'
    [ "$status" -eq 0 ]
    [[ "$output" == *"NO"* ]]
}

# ── The `time` gap (OBS-511) ──────────────────────────────────────────────

@test "a time-prefixed read is allowed, so measuring a permitted command is permitted" {
    _verdict "$LIB" "time git status"
    [ "$output" = "ALLOWED" ]
}

@test "CONTROL: the pre-fix library refused the same time-prefixed read" {
    _verdict "$OLD_LIB" "time git status"
    [ "$output" = "BLOCKED_GATED" ]
}

@test "POSIX 'time -p' is stripped too" {
    _verdict "$LIB" "time -p git status"
    [ "$output" = "ALLOWED" ]
}

@test "env prefix and time interleave in either order" {
    _verdict "$LIB" "FOO=1 time git status"
    [ "$output" = "ALLOWED" ]
    _verdict "$LIB" "time FOO=1 git status"
    [ "$output" = "ALLOWED" ]
}

@test "a time-prefixed WRITE is still blocked — stripping exposes the remainder, it does not excuse it" {
    local c
    # The nested-quote case is built with a printf so the wrapper never has to
    # re-parse it; see the _pred comment on why interpolation lies here.
    local nested
    nested=$(printf '%s' "time bash -c 'rm x'")
    for c in "time rm -rf /tmp/x" "time -p tee f" "time sed -i s/a/b/ f" "$nested"; do
        _verdict "$LIB" "$c"
        [ "$output" = "BLOCKED_WRITE" ]
    done
}

@test "a denied env name after time is still denied" {
    _verdict "$LIB" "time PATH=/tmp cat x"
    [ "$output" != "ALLOWED" ]
}

@test "/usr/bin/time is NOT stripped — it is a program with its own file-writing options" {
    # `/usr/bin/time -o FILE` writes a file. Only the shell keyword is inert.
    _with "$LIB" '_FW_ENV_STRIPPED=""; _fw_strip_env_prefixes "/usr/bin/time git status"; echo "$_FW_ENV_STRIPPED"'
    [ "$status" -eq 0 ]
    [[ "$output" == "/usr/bin/time git status" ]]
}

@test "the strip terminates on input that is only prefixes" {
    # The loop rewrites its own subject; a shape that never shrinks must not spin.
    _with "$LIB" '_FW_ENV_STRIPPED=""; _fw_strip_env_prefixes "time"; echo "[$_FW_ENV_STRIPPED]"'
    [ "$status" -eq 0 ]
    [[ "$output" == "[time]" ]]
}
