#!/usr/bin/env bats
# T-2867 — `fw note` must refuse arguments it cannot use, never discard them.
#
# Origin: observe.sh's dispatch ends `*) do_capture "$@"`, so any word that is not
# a known sub-verb becomes the note text; and do_capture's option loop ended
# `*) shift`, dropping every remaining positional on the floor. Composed:
#
#     fw note add "a real observation"
#
# captured the word `add`, discarded the observation, exited 0, and printed the
# wrong text back as confirmation. Measured cost before the fix: 26 of 191
# observations were bare sub-verbs (add x16, resolve x6, show x3, status x1) —
# 26 notes someone meant to record and lost. 25 had already been triaged, so the
# corpus had been read by a human twenty-five times without the shape registering.
#
# WHAT IS PINNED: the guard fires on ANY unused positional, not on a blocklist of
# sub-verb names — the next lost note will use a word nobody thought to list.
#
# ISOLATION: every test runs against a throwaway PROJECT_ROOT so the project's real
# .context/inbox.yaml is never written. observe.sh derives INBOX_FILE from
# PROJECT_ROOT at line 19, so exporting it is sufficient.
#
# ANTI-VACUITY: the last test extracts the PRE-FIX observe.sh with `git show HEAD:`
# and asserts it exhibits the defect — silently capturing `add` with exit 0 — while
# the normal-capture control still passes against it. Without that, green here
# proves the guard exists, not that it catches anything.

load ../test_helper

OBSERVE="$FRAMEWORK_ROOT/agents/observe/observe.sh"

# A throwaway project root. focus.yaml is seeded deliberately: without it,
# do_capture's trailing `[ -n "$task" ] && echo …` short-circuits and the script
# exits 1 despite having written the note perfectly — a separate, pre-existing
# defect (T-2868), reproduced against the pre-fix script too, so not caused by
# T-2867's guard. Seeding focus here keeps this suite measuring ITS OWN property
# instead of failing for someone else's reason. T-2868 pins that one directly.
_fresh_root() {
    local root="$BATS_TEST_TMPDIR/proj$1"
    mkdir -p "$root/.context/working"
    printf 'current_task: T-9999\n' > "$root/.context/working/focus.yaml"
    echo "$root"
}

# Run a given observe.sh against an isolated root.
_note() {
    local script="$1" root="$2"; shift 2
    PROJECT_ROOT="$root" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" bash "$script" "$@"
}

@test "T-2867: the defect shape fails instead of capturing the sub-verb" {
    local root; root=$(_fresh_root a)
    run _note "$OBSERVE" "$root" add "a real observation that used to vanish"
    [ "$status" -ne 0 ]
    # The error must name what would have been lost — not just say "bad usage".
    [[ "$output" == *"a real observation that used to vanish"* ]]
    # ...and hand back the corrected command.
    [[ "$output" == *'fw note "a real observation that used to vanish"'* ]]
}

@test "T-2867: nothing is written to the inbox when the guard fires" {
    local root; root=$(_fresh_root b)
    run _note "$OBSERVE" "$root" add "should not be stored"
    [ "$status" -ne 0 ]
    # Refusing must not half-capture: no `add` entry, no partial entry.
    if [ -f "$root/.context/inbox.yaml" ]; then
        run grep -c "text: \"add\"" "$root/.context/inbox.yaml"
        [ "$output" = "0" ]
    fi
}

@test "T-2867: the guard is general — any unused positional errors, not a word list" {
    local root; root=$(_fresh_root c)
    # `frobnicate` is not a sub-verb anyone would blocklist. It must still error,
    # because the second argument would otherwise be discarded.
    run _note "$OBSERVE" "$root" frobnicate "text that would be dropped"
    [ "$status" -ne 0 ]
    [[ "$output" == *"text that would be dropped"* ]]
}

@test "T-2867: CONTROL — an ordinary single-argument capture still works" {
    local root; root=$(_fresh_root d)
    run _note "$OBSERVE" "$root" "a perfectly ordinary observation"
    [ "$status" -eq 0 ]
    [[ "$output" == *"a perfectly ordinary observation"* ]]
    grep -q "a perfectly ordinary observation" "$root/.context/inbox.yaml"
}

@test "T-2867: CONTROL — flags after the text are consumed, not treated as strays" {
    local root; root=$(_fresh_root e)
    run _note "$OBSERVE" "$root" "observation with options" --task T-2867 --urgent
    [ "$status" -eq 0 ]
    grep -q "observation with options" "$root/.context/inbox.yaml"
}

@test "T-2867: CONTROL — real sub-verbs still dispatch" {
    local root; root=$(_fresh_root f)
    run _note "$OBSERVE" "$root" count
    [ "$status" -eq 0 ]
    # `count` must be interpreted as the verb, NOT captured as a note.
    if [ -f "$root/.context/inbox.yaml" ]; then
        run grep -c "text: \"count\"" "$root/.context/inbox.yaml"
        [ "$output" = "0" ]
    fi
}

@test "T-2867: ANTI-VACUITY — the pre-fix observe.sh exhibits the defect" {
    # observe.sh:17 recomputes FRAMEWORK_ROOT from its OWN location and sources
    # lib/paths.sh relative to that, overwriting any inherited value — so the
    # extracted copy cannot simply be dropped in a temp file and run. Give it a
    # framework-shaped directory with lib/ symlinked, or it dies at source time and
    # the resulting non-zero exit looks exactly like "the defect leg went red"
    # while proving nothing (OBS-193, same trap as a mutant that fails to parse).
    local fwroot="$BATS_TEST_TMPDIR/fwroot"
    mkdir -p "$fwroot/agents/observe"
    ln -sfn "$FRAMEWORK_ROOT/lib" "$fwroot/lib"
    local pre="$fwroot/agents/observe/observe.sh"
    if ! git -C "$FRAMEWORK_ROOT" show "HEAD:agents/observe/observe.sh" > "$pre" 2>/dev/null; then
        skip "cannot extract pre-fix observe.sh from HEAD"
    fi
    if grep -q 'strays' "$pre"; then
        skip "HEAD already carries the fix; teeth check belongs on the pre-fix parent"
    fi
    # Prove the extracted script is RUNNABLE before trusting any red from it.
    run _note "$pre" "$(_fresh_root z)" "smoke: the extracted script runs at all"
    [ "$status" -eq 0 ]

    local root; root=$(_fresh_root g)
    run _note "$pre" "$root" add "this text is about to be discarded"

    # THE DEFECT: silent success, wrong text captured, real observation gone.
    [ "$status" -eq 0 ]
    grep -q "text: \"add\"" "$root/.context/inbox.yaml"
    ! grep -q "this text is about to be discarded" "$root/.context/inbox.yaml"

    # CONTROL against the same old script — an ordinary capture worked fine, so the
    # red above is the defect and not a script that simply cannot run here.
    local root2; root2=$(_fresh_root h)
    run _note "$pre" "$root2" "an ordinary observation"
    [ "$status" -eq 0 ]
    grep -q "an ordinary observation" "$root2/.context/inbox.yaml"
}
