#!/usr/bin/env bats
# T-2868 — `fw note` must exit 0 when it has written the note.
#
# Origin: do_capture ended
#
#     [ -n "$task" ] && echo -e "  context: $task"
#
# as its FINAL statement. With no focus task the test returns 1, `&&`
# short-circuits, and 1 becomes the function's return value and the script's exit
# status — after the note has been written and a success line printed.
#
# A fresh project has no .context/working/focus.yaml until `fw context focus` runs,
# so the FIRST `fw note` in every new project reported failure while succeeding.
# It is a false red on a write: a caller that retries on non-zero duplicates the
# observation, and anything under `set -e` aborts.
#
# Mirror image of T-2867 on the same function — that one returned 0 while losing
# data, this one returns 1 while succeeding. Both survived because nobody reads the
# exit code of a command that prints a cheerful confirmation.
#
# ANTI-VACUITY: the last test runs the PRE-FIX script and observes rc != 0 with the
# note nonetheless present — the exact contradiction. A smoke check runs first,
# because observe.sh:17 recomputes FRAMEWORK_ROOT from its own location, so an
# extracted copy in the wrong shape dies at `source` time and yields a non-zero exit
# that is indistinguishable from the defect (OBS-193).

load ../test_helper

OBSERVE="$FRAMEWORK_ROOT/agents/observe/observe.sh"

# A project root with NO focus.yaml — the fresh-project shape.
_bare_root() {
    local root="$BATS_TEST_TMPDIR/bare$1"
    mkdir -p "$root/.context/working"
    echo "$root"
}

# A project root WITH a focus task set.
_focused_root() {
    local root="$BATS_TEST_TMPDIR/foc$1"
    mkdir -p "$root/.context/working"
    printf 'current_task: T-9999\n' > "$root/.context/working/focus.yaml"
    echo "$root"
}

_note() {
    local script="$1" root="$2"; shift 2
    PROJECT_ROOT="$root" bash "$script" "$@"
}

# Lay out an extracted script in a framework-shaped dir so its self-derived
# FRAMEWORK_ROOT resolves and lib/paths.sh is reachable.
_extract_pre_fix() {
    local fwroot="$BATS_TEST_TMPDIR/fwroot$1"
    mkdir -p "$fwroot/agents/observe"
    ln -sfn "$FRAMEWORK_ROOT/lib" "$fwroot/lib"
    git -C "$FRAMEWORK_ROOT" show "HEAD:agents/observe/observe.sh" \
        > "$fwroot/agents/observe/observe.sh" 2>/dev/null || return 1
    echo "$fwroot/agents/observe/observe.sh"
}

@test "T-2868: capture with NO focus.yaml exits 0" {
    local root; root=$(_bare_root a)
    run _note "$OBSERVE" "$root" "an observation from a fresh project"
    [ "$status" -eq 0 ]
}

@test "T-2868: ...and the note really was written (rc 0 is not achieved by skipping the work)" {
    local root; root=$(_bare_root b)
    run _note "$OBSERVE" "$root" "an observation from a fresh project"
    [ "$status" -eq 0 ]
    grep -q "an observation from a fresh project" "$root/.context/inbox.yaml"
}

@test "T-2868: with a focus task set, rc is 0 AND the context line still prints" {
    local root; root=$(_focused_root c)
    run _note "$OBSERVE" "$root" "an observation with focus set"
    [ "$status" -eq 0 ]
    # The fix must change the exit status only — not silence the output.
    [[ "$output" == *"context: T-9999"* ]]
    grep -q "an observation with focus set" "$root/.context/inbox.yaml"
}

@test "T-2868: ANTI-VACUITY — the pre-fix script exits non-zero after a successful write" {
    local pre
    pre=$(_extract_pre_fix d) || skip "cannot extract pre-fix observe.sh from HEAD"
    if grep -q 'T-2868' "$pre"; then
        skip "HEAD already carries the fix; teeth check belongs on the pre-fix parent"
    fi

    # Smoke: the extracted script must RUN, or a source-time death would masquerade
    # as the defect below.
    run _note "$pre" "$(_focused_root d)" "smoke: the extracted script runs at all"
    [ "$status" -eq 0 ]

    local root; root=$(_bare_root d)
    run _note "$pre" "$root" "this note is written but reported as failed"

    # THE DEFECT: non-zero exit...
    [ "$status" -ne 0 ]
    # ...while the note is on disk and the success line was printed. Both halves
    # matter: a non-zero exit alone could mean the write failed.
    grep -q "this note is written but reported as failed" "$root/.context/inbox.yaml"
    [[ "$output" == *"captured"* ]]
}
