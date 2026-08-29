#!/usr/bin/env bats
# T-3219 — the P-011 gate must not pass on a count it cannot reconcile.
#
# THE DEFECT. `run_verification_commands` counted `verify_total` before the loop,
# ran `eval "$cmd"` with stdout/stderr redirected but STDIN LEFT ALONE, and fed the
# loop from `done <<< "$verify_cmds"`. The command list was therefore the loop's own
# stdin, so a command that reads stdin consumed the remaining verification lines.
# The verdict asked only `[ "$verify_fail" -gt 0 ]`, which is green whenever nothing
# failed — including when most of the block never ran. Measured on the real gate:
#
#     Running 4 verification command(s)...
#       PASS: echo one
#       PASS: cat > /dev/null
#     Verification: 2/4 passed ✓
#
# A false green in the gate whose entire purpose is preventing false greens. The
# fraction was printed; nothing compared its halves.
#
# TWO LEGS, TESTED SEPARATELY BECAUSE THEY FAIL SEPARATELY.
#   leg 1  `< /dev/null` on the eval — prevents the swallow.
#   leg 2  reconcile pass+fail against total — CATCHES a swallow from any cause,
#          including leg 1 regressing. Not bypassable by --skip-verification.
# Leg 2 is unreachable while leg 1 holds, so every leg-2 test drives a copy of the
# shipped script with leg 1 deliberately removed. That is not a mock: it is the real
# function, minus one redirect, which is exactly the state it shipped in for months.
#
# SCOPE LIMIT, STATED RATHER THAN IMPLIED. These tests assert on the GATE'S OUTPUT,
# not on whether the task reaches completed/. In a synthetic project root the close
# is blocked further downstream (recommendation / RCA / disposition gates want
# framework state the fixture has not got), so "did it complete" cannot discriminate
# here — measured: the all-pass control blocks too, on pristine code. Asserting it
# would be asserting the harness. The subject under test is run_verification_commands
# and its output is the honest observable.
#
# `! cmd` at statement position is INERT in bats (L-628, T-3199) — this file uses
# `if cmd; then false; fi`.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SHIPPED="$REPO_ROOT/agents/task-create/update-task.sh"
    TMP="$BATS_TEST_TMPDIR/t3219"
    mkdir -p "$TMP"
}

# A synthetic project root holding one task whose ## Verification is $1.
mkproj() {
    local block="$1"
    PROJ="$TMP/proj.$RANDOM"
    mkdir -p "$PROJ/.tasks/active" "$PROJ/.tasks/completed" \
             "$PROJ/.context/working" "$PROJ/.context/episodic"
    git -C "$PROJ" init -q .
    git -C "$PROJ" config user.email t@t
    git -C "$PROJ" config user.name t
    git -C "$PROJ" commit -q --allow-empty -m init
    {
        cat <<'HDR'
---
id: T-901
name: "probe"
status: started-work
workflow_type: build
owner: agent
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---
# T-901: probe

## Acceptance Criteria

### Agent
- [x] probe

## Verification

HDR
        printf '%s\n' "$block"
    } > "$PROJ/.tasks/active/T-901-probe.md"
}

# Run a given copy of update-task.sh against the synthetic root.
run_gate() {
    local script="$1"; shift
    PROJECT_ROOT="$PROJ" TASKS_DIR="$PROJ/.tasks" CONTEXT_DIR="$PROJ/.context" \
        timeout 120 bash "$script" T-901 --status work-completed "$@" 2>&1
}

# update-task.sh computes FRAMEWORK_ROOT from its OWN location, with no env
# override, so a mutated copy must sit at <root>/agents/task-create/ or it
# sources //lib/paths.sh and dies before reaching the gate. Rather than mutate the
# real file in place — a crashed run would leave the repo's completion gate
# modified — build a symlink farm that looks like the framework root and put the
# mutant inside it. Everything resolves; nothing in the repo is touched.
fake_root() {
    local F="$TMP/fw"
    [ -d "$F/agents/task-create" ] && { printf '%s\n' "$F"; return 0; }
    mkdir -p "$F/agents/task-create"
    local e b
    for e in "$REPO_ROOT"/* "$REPO_ROOT"/.[!.]*; do
        b="$(basename "$e")"; [ "$b" = "agents" ] && continue
        ln -s "$e" "$F/$b" 2>/dev/null || true
    done
    for e in "$REPO_ROOT"/agents/*; do
        b="$(basename "$e")"; [ "$b" = "task-create" ] && continue
        ln -s "$e" "$F/agents/$b" 2>/dev/null || true
    done
    for e in "$REPO_ROOT"/agents/task-create/*; do
        ln -s "$e" "$F/agents/task-create/$(basename "$e")" 2>/dev/null || true
    done
    printf '%s\n' "$F"
}

# A copy of the shipped script with leg 1 (the stdin redirect) removed.
without_stdin_fix() {
    local F; F="$(fake_root)"
    local mut="$F/agents/task-create/no-stdin-fix.sh"
    sed 's|> /tmp/verify-\$\$.out 2>&1 < /dev/null; then|> /tmp/verify-$$.out 2>\&1; then|' \
        "$SHIPPED" > "$mut"
    if diff -q "$SHIPPED" "$mut" >/dev/null 2>&1; then
        echo "mutation changed no bytes — the stdin redirect is not where expected" >&2
        return 1
    fi
    printf '%s\n' "$mut"
}

SWALLOW_BLOCK='echo one
cat > /dev/null
echo three
echo four'

# ── leg 1: the swallow itself ────────────────────────────────────────────────

@test "T-3219: a stdin-reading command no longer swallows the remaining lines" {
    mkproj "$SWALLOW_BLOCK"
    run run_gate "$SHIPPED"
    echo "$output" | grep -q "Running 4 verification command"
    echo "$output" | grep -q "PASS: echo three"
    echo "$output" | grep -q "PASS: echo four"
    echo "$output" | grep -q "4/4 passed"
}

@test "T-3219: CONTROL — without the fix the same block reports 2/4 and calls it green" {
    # The pre-fix behaviour, reproduced from the real function. This is what
    # makes the test above evidence rather than an assertion about echo.
    local mut; mut="$(without_stdin_fix)"
    mkproj "$SWALLOW_BLOCK"
    run run_gate "$mut"
    echo "$output" | grep -q "Running 4 verification command"
    if echo "$output" | grep -q "PASS: echo three"; then
        echo "line three ran — the mutation did not reproduce the swallow" >&2
        false
    fi
}

# ── leg 2: the reconciliation guard ──────────────────────────────────────────

@test "T-3219: an unreconciled count is REFUSED, not reported as passed" {
    local mut; mut="$(without_stdin_fix)"
    mkproj "$SWALLOW_BLOCK"
    run run_gate "$mut"
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "does not reconcile"
    echo "$output" | grep -q "never ran"
    # and critically, it must NOT also claim success
    if echo "$output" | grep -q "passed ✓"; then
        echo "gate printed a success line for an unreconciled count" >&2
        false
    fi
}

@test "T-3219: the refusal names the likely cause and the remedy" {
    # A guard that refuses without saying why sends the reader back to the source.
    local mut; mut="$(without_stdin_fix)"
    mkproj "$SWALLOW_BLOCK"
    run run_gate "$mut"
    echo "$output" | grep -q "reads stdin"
    echo "$output" | grep -q "/dev/null"
}

@test "T-3219: --skip-verification does NOT bypass the reconciliation guard" {
    # That flag means "I accept these failures". An unreconciled count is not a
    # failure anyone can accept — it is the runner saying it does not know what
    # it ran. One flag must not cover both speech acts.
    local mut; mut="$(without_stdin_fix)"
    mkproj "$SWALLOW_BLOCK"
    run run_gate "$mut" --skip-verification
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "does not reconcile"
}

# ── the guard must not fire on ordinary blocks ───────────────────────────────

@test "T-3219: an all-pass block still passes and does not trip the guard" {
    mkproj 'echo one
echo two
echo three'
    run run_gate "$SHIPPED"
    echo "$output" | grep -q "3/3 passed"
    if echo "$output" | grep -q "does not reconcile"; then
        echo "guard fired on a fully reconciled all-pass block" >&2
        false
    fi
}

@test "T-3219: an ordinary FAILURE still blocks, by the failure path not the guard" {
    # The two refusals are different and must stay distinguishable: one says
    # "this failed", the other says "I do not know what ran".
    mkproj 'echo one
false
echo three'
    run run_gate "$SHIPPED"
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "verification(s) failed"
    if echo "$output" | grep -q "does not reconcile"; then
        echo "guard fired on a reconciled block that merely had a failure" >&2
        false
    fi
}

@test "T-3219: --skip-verification still bypasses a genuine failure" {
    # Unchanged behaviour. Without this, the guard could have been implemented
    # by making --skip-verification stop working at all.
    mkproj 'echo one
false'
    run run_gate "$SHIPPED" --skip-verification
    echo "$output" | grep -q "skip-verification bypass"
    if echo "$output" | grep -q "does not reconcile"; then
        echo "guard fired on a reconciled block under --skip-verification" >&2
        false
    fi
}

# ── the control leg ──────────────────────────────────────────────────────────

@test "T-3219: MUTATION — remove the guard and the unreconciled block goes green again" {
    # Both legs removed: this is precisely the shipped state the defect was found
    # in. If this does not reproduce the false green, leg 2's tests are asserting
    # something other than the guard.
    local mut; mut="$(without_stdin_fix)"
    local mut2="$(fake_root)/agents/task-create/no-guard.sh"
    sed '/-ne "\$verify_total" \]; then/,/^    fi$/d' "$mut" > "$mut2"
    if diff -q "$mut" "$mut2" >/dev/null 2>&1; then
        echo "guard mutation changed no bytes — the sed range no longer matches" >&2
        false
    fi
    bash -n "$mut2"

    mkproj "$SWALLOW_BLOCK"
    run run_gate "$mut2"
    echo "$output" | grep -q "2/4 passed"
    if echo "$output" | grep -q "does not reconcile"; then
        echo "guard still fired after being removed" >&2
        false
    fi
}
