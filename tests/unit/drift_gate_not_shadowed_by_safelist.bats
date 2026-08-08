#!/usr/bin/env bats
# T-2880 — the safe-list early return must not shadow the focus-drift gate.
#
# check-active-task.sh answered two independent questions with one `exit 0`:
#
#     "does this need an active task?"   — about the SESSION state
#     "is it attributed to the right task?" — about the COMMAND
#
# Safe-listing a verb answered the first and silently answered the second with
# "don't care". T-2878 safe-listed `fw context add-*`, which IS drift pattern 2,
# so that pattern became unreachable the moment the deadlock fix shipped — with
# every existing test still green, because none of them asserted the gate was
# still being CONSULTED (L-555: a check that stops being consulted looks exactly
# like a check that found nothing).
#
# The two properties below must hold SIMULTANEOUSLY, which is why they are in
# one file: fixing either one alone regresses the other.
#
#   1. `fw context add-learning --task T-OTHER` blocks as drift when focus is set
#   2. the same command is ALLOWED when focus is null (T-2878 — completion nulls
#      focus, and capture is exactly what the framework prescribes at that moment)
#
# HARNESS: the hook re-anchors PROJECT_ROOT from the stdin `cwd`
# (lib/paths.sh:fw_reanchor_from_cwd, T-2465), so a fixture tree redirects every
# focus/task read. The live repo's focus.yaml is never touched. An anti-vacuity
# control asserts the re-anchor actually took effect — without it the suite would
# silently measure the live session's focus and agree with whatever it happened
# to be.

load ../test_helper

HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"

# _fixture <task|null> <status> <in_active yes|no> <focus_session>
_fixture() {
    FIX="$BATS_TEST_TMPDIR/proj"
    rm -rf "$FIX"; mkdir -p "$FIX/.tasks/active" "$FIX/.tasks/completed" "$FIX/.context/working"
    printf 'version: 1\n' > "$FIX/.framework.yaml"
    printf 'current_task: %s\nfocus_session: %s\n' "$1" "${4:-S-PROBE}" > "$FIX/.context/working/focus.yaml"
    printf 'session_id: S-PROBE\n' > "$FIX/.context/working/session.yaml"
    if [ "$1" != "null" ]; then
        local d=completed; [ "$3" = "yes" ] && d=active
        printf -- '---\nid: %s\nstatus: %s\n---\n' "$1" "$2" > "$FIX/.tasks/$d/$1-p.md"
    fi
}

# _gate [hook_path] <command>  — echoes exit code, stderr on fd 3 discarded
_gate() {
    local hook="$HOOK"
    if [ "$#" -eq 2 ]; then hook="$1"; shift; fi
    local rc=0
    python3 -c "
import json,sys
print(json.dumps({'tool_name':'Bash','cwd':sys.argv[1],'tool_input':{'command':sys.argv[2]}}))" \
        "$FIX" "$1" | CLAUDECODE=1 bash "$hook" >/dev/null 2>&1 || rc=$?
    echo "$rc"
}

# NOTE the `|| true`: bats runs under `set -e` and the hook exits 2 BY DESIGN on
# every blocking leg, so the bare command substitution aborts the test before the
# assertion it was fetching evidence for. Same class as the P-011 rehearsal trap
# (T-2743) — a gate that exits non-zero on purpose needs its exit code neutralised
# at the capture site, not asserted there.
_stderr() {
    python3 -c "
import json,sys
print(json.dumps({'tool_name':'Bash','cwd':sys.argv[1],'tool_input':{'command':sys.argv[2]}}))" \
        "$FIX" "$1" | CLAUDECODE=1 bash "$HOOK" 2>&1 >/dev/null || true
}

@test "T-2880: ANTI-VACUITY CONTROL — the fixture re-anchor actually reaches the hook" {
    # If this fails, every other leg is measuring the LIVE focus.yaml and its
    # agreement means nothing. Uses a task id that exists only in the fixture.
    _fixture T-9001 started-work yes
    local err; err=$(_stderr 'bin/fw task update T-9002 --status issues')
    echo "$err" | grep -q 'T-9001'
}

@test "T-2880: PROPERTY 1 — pattern 2 reaches the drift gate again and BLOCKS" {
    _fixture T-9001 started-work yes
    [ "$(_gate 'bin/fw context add-learning "x" --task T-9002')" -eq 2 ]
    local err; err=$(_stderr 'bin/fw context add-learning "x" --task T-9002')
    echo "$err" | grep -q 'FOCUS-DRIFT'
    echo "$err" | grep -q 'T-9002'
}

@test "T-2880: PROPERTY 2 — the SAME command is still allowed with no active task" {
    # T-2878 must not regress. This is the state `--status work-completed` leaves
    # behind: focus nulled, task moved to completed/, capture still prescribed.
    _fixture null - no
    [ "$(_gate 'bin/fw context add-learning "x" --task T-9002')" -eq 0 ]
    [ "$(_gate 'bin/fw context add-pattern "x" --task T-9002')" -eq 0 ]
    [ "$(_gate 'bin/fw context add-decision "x" --task T-9002')" -eq 0 ]
}

@test "T-2880: pattern 2 does NOT block when it names the focused task" {
    _fixture T-9001 started-work yes
    [ "$(_gate 'bin/fw context add-learning "x" --task T-9001')" -eq 0 ]
}

@test "T-2880: the other two drift patterns still fire" {
    _fixture T-9001 started-work yes
    [ "$(_gate 'bin/fw task update T-9002 --status issues')" -eq 2 ]   # pattern 1
    [ "$(_gate 'git commit -m "T-9002: x"')" -eq 2 ]                   # pattern 3
    # ...and still do not fire on the focused task
    [ "$(_gate 'bin/fw task update T-9001 --status issues')" -eq 0 ]
    [ "$(_gate 'git commit -m "T-9001: x"')" -eq 0 ]
}

@test "T-2880: no new block for ordinary safe commands in the null-task state" {
    # The regression this fix could plausibly cause: routing safe commands
    # through the full check so they start tripping the no-active-task block.
    # Only DRIFT-NAMING commands fall through; these must be untouched.
    _fixture null - no
    for c in 'bin/fw doctor' 'git status' 'ls -la' 'bin/fw context status' \
             'bin/fw note "x"' 'bin/fw handover' 'bin/fw context add-learning "x"'; do
        [ "$(_gate "$c")" -eq 0 ] || { echo "REGRESSION: '$c' blocked at null focus"; return 1; }
    done
}

@test "T-2880: ordinary safe commands stay allowed under a STALE focus too" {
    # The fast path still short-circuits for non-drift-naming commands, so the
    # T-560 stale gate is not newly reachable for them.
    _fixture T-9001 started-work yes S-OLD
    [ "$(_gate 'bin/fw doctor')" -eq 0 ]
    [ "$(_gate 'bin/fw note "x"')" -eq 0 ]
}

@test "T-2880: a drift-naming command under stale focus blocks with an UNBLOCKABLE remedy" {
    # It now routes through the full check, so the stale gate can reach it. That
    # is correct — but the remedy it prints must itself be allowed, or this fix
    # would trade one deadlock for another. `fw work-on` is safe-listed.
    _fixture T-9001 started-work yes S-OLD
    [ "$(_gate 'bin/fw context add-learning "x" --task T-9001')" -eq 2 ]
    local err; err=$(_stderr 'bin/fw context add-learning "x" --task T-9001')
    echo "$err" | grep -q 'STALE FOCUS'
    echo "$err" | grep -q 'work-on T-9001'
    [ "$(_gate 'bin/fw work-on T-9001')" -eq 0 ]   # the printed remedy is not itself gated
}

@test "T-2880: T-2879's pattern-2 anchor is now verifiable END-TO-END" {
    # T-2879 anchored pattern 2 so the extracted id must belong to the add-*
    # invocation. That fix was correct but INERT while this shadowing stood —
    # the command never reached the gate, so the anchor could not be observed
    # to matter. Now it can: the un-anchored form would extract T-9002 across
    # the `;` and block; the anchored form must not.
    _fixture T-9001 started-work yes
    [ "$(_gate 'bin/fw context add-learning "x"; bin/fw task list --task T-9002')" -eq 0 ]
}

@test "T-2880: the two questions are separated in the code, with the reason stated" {
    # AC: a future reader must find WHY the early return is conditional, not just
    # that it is. Pinning the explanation, not the mechanism.
    grep -q '_fw_extract_drift_target' "$HOOK"
    grep -q 'needs a task?' "$HOOK"
    grep -q 'attributed correctly?' "$HOOK"
    # single definition of the patterns — the gate consumes, does not re-derive
    [ "$(grep -c 'fw\[\[:space:\]\]+task\[\[:space:\]\]+update' "$HOOK")" -eq 1 ]
}

@test "T-2880: TEETH — restoring the unconditional early return re-opens the shadowing" {
    # DURABLE MUTATION of live source, not `git show HEAD~N:` — a ref-based teeth
    # check goes inert on the next commit and skips while reporting ok (T-2874).
    #
    # THE MUTANT LIVES BESIDE THE REAL HOOK, not in $BATS_TEST_TMPDIR. The hook
    # derives FRAMEWORK_ROOT as "$SCRIPT_DIR/../.." and sources lib/paths.sh from
    # it; from a tmpdir that resolves to `//lib/paths.sh` and the mutant dies at
    # line 31, long before the gate. The "defect reproduced" assertion would then
    # pass for the wrong reason — the mechanism was never driven — while `bash -n`
    # stayed green throughout, because parsing is not running. Reported to us by
    # 832 (rail 477) as the shape that made their probe test nothing on two
    # consecutive runs; the exit-code assertions below are what distinguish a
    # working mutant from one that never reached the gate.
    local mutant="$FRAMEWORK_ROOT/agents/context/.t2880-mutant.sh"
    sed 's|if \[ -z "\$DRIFT_TARGET" \]; then|if true; then|' "$HOOK" > "$mutant"
    local delta; delta=$(diff "$HOOK" "$mutant" || true)   # diff exits 1 on "differs" (L-387)
    [ -n "$delta" ]        # a no-op sed proves nothing
    bash -n "$mutant"      # necessary, NOT sufficient — see above (OBS-193)

    _fixture T-9001 started-work yes
    # Positive control: the mutant must still reach the gate at all. If it died
    # early this returns a non-zero that is not 2 (or 2 for the wrong reason), and
    # the shadowing assertion below would be vacuous.
    [ "$(_gate "$mutant" 'bin/fw task update T-9002 --status issues')" -eq 2 ]
    # THE DEFECT: with the return unconditional, pattern 2 never reaches the gate.
    [ "$(_gate "$mutant" 'bin/fw context add-learning "x" --task T-9002')" -eq 0 ]
    # And the fixed source blocks it — pins the mutation as the cause, not the harness.
    [ "$(_gate "$HOOK" 'bin/fw context add-learning "x" --task T-9002')" -eq 2 ]
    rm -f "$mutant"
}

teardown() {
    # Belt and braces: the mutant is a live copy of the governance hook sitting in
    # the hooks directory. It must never survive a failed run.
    rm -f "$FRAMEWORK_ROOT/agents/context/.t2880-mutant.sh"
}
