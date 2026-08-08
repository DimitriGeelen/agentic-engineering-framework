#!/usr/bin/env bats
# T-2874 — `fw context focus` must refuse a completed task id.
#
# Origin: 832 rail 461, verified against both call sites here before adopting.
# do_focus validated with `find_task_file "$task_id"` — UNSCOPED, which resolves
# active/ then falls back to completed/. The gate that reads the value back requires
# `find_task_file "$CURRENT_TASK" active` (check-active-task.sh:401).
#
# The writer's accepted set was a strict SUPERSET of the reader's usable set. Every id
# in the difference produced a state that was writable but unusable: focus succeeded,
# exit 0, and then every gated Write/Edit/Bash died on "Task X is not active". Hit
# repeatedly in live sessions after each task close, worked around every time without
# anyone asking why the state was reachable.
#
# WHY THE ASSERTIONS CHECK MESSAGE CONTENT AND NOT rc:
# "does not exist anywhere" and "exists but is completed" BOTH exit non-zero. A leg
# asserting only `status -ne 0` passes for the wrong reason — it would certify this fix
# from a tree where the fixture was never created at all. 832's own probe was bitten by
# exactly this: its entry leg passed while the fixtures were invisible, and only the
# message-content legs went red. rc is asserted too, but never alone.
#
# FIXTURE VISIBILITY: focus.sh resolves paths from PROJECT_ROOT/TASKS_DIR/CONTEXT_DIR.
# Callers up the chain EXPORT those for the live repo, and an export beats a `cd` — a
# sandbox that only changes directory is invisible and the probe answers about the wrong
# tree. So every run below sets them explicitly, and a smoke leg proves the sandbox is
# the tree actually being read before any refusal is believed.

load ../test_helper

FOCUS_SH="$FRAMEWORK_ROOT/agents/context/lib/focus.sh"
CONTEXT_SH="$FRAMEWORK_ROOT/agents/context/context.sh"

# A throwaway project with one active and one completed task.
_sandbox() {
    local root="$BATS_TEST_TMPDIR/proj$1"
    mkdir -p "$root/.tasks/active" "$root/.tasks/completed" "$root/.context/working"
    printf -- '---\nid: T-9001\nname: "an active task"\nstatus: started-work\n---\n' \
        > "$root/.tasks/active/T-9001-active.md"
    printf -- '---\nid: T-9002\nname: "a completed task"\nstatus: work-completed\n---\n' \
        > "$root/.tasks/completed/T-9002-done.md"
    printf 'current_task:\n' > "$root/.context/working/focus.yaml"
    echo "$root"
}

_focus() {
    local root="$1"; shift
    PROJECT_ROOT="$root" TASKS_DIR="$root/.tasks" CONTEXT_DIR="$root/.context" \
        bash "$CONTEXT_SH" focus "$@" 2>&1
}

@test "T-2874: SMOKE — the sandbox is the tree actually being read" {
    # If this fails, every refusal below is about the live repo and proves nothing.
    local root; root=$(_sandbox smoke)
    run _focus "$root" T-9001
    [ "$status" -eq 0 ]
    grep -q "T-9001" "$root/.context/working/focus.yaml"
}

@test "T-2874: focusing a COMPLETED id is refused" {
    local root; root=$(_sandbox a)
    run _focus "$root" T-9002
    [ "$status" -ne 0 ]
    # Content, not rc: this is what distinguishes the fix from an absent fixture.
    [[ "$output" == *"completed, not active"* ]]
}

@test "T-2874: the refusal names the recovery command" {
    local root; root=$(_sandbox b)
    run _focus "$root" T-9002
    [[ "$output" == *"work-on T-9002"* ]]
}

@test "T-2874: a refused focus does not WRITE the unusable state" {
    # The defect's whole cost was the write succeeding. Refusing loudly while still
    # persisting the value would leave the deadlock intact.
    local root; root=$(_sandbox c)
    run _focus "$root" T-9002
    [ "$status" -ne 0 ]
    ! grep -q "T-9002" "$root/.context/working/focus.yaml"
}

@test "T-2874: a genuinely unknown id says NOT FOUND, not 'completed'" {
    # The two causes need different recoveries. Collapsing them sends the operator
    # hunting for a typo in an id that exists — or the reverse.
    local root; root=$(_sandbox d)
    run _focus "$root" T-9999
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* || "$output" == *"Task not found"* ]]
    [[ "$output" != *"completed, not active"* ]]
}

@test "T-2874: CONTROL — focusing an ACTIVE id still works" {
    local root; root=$(_sandbox e)
    run _focus "$root" T-9001
    [ "$status" -eq 0 ]
    grep -q "T-9001" "$root/.context/working/focus.yaml"
}

@test "T-2874: ANTI-VACUITY — the pre-fix focus.sh accepts the completed id" {
    # Proves the suite can fail. Without it, green says only that the current code
    # happens to pass — not that the defect it targets was ever reachable.
    local pre="$BATS_TEST_TMPDIR/focus-pre.sh"
    if ! git -C "$FRAMEWORK_ROOT" show "HEAD~1:agents/context/lib/focus.sh" > "$pre" 2>/dev/null; then
        skip "cannot extract pre-fix focus.sh"
    fi
    if grep -qF 'find_task_file "$task_id" active' "$pre"; then
        skip "HEAD~1 already carries the fix; teeth check belongs on its parent"
    fi
    # NB grep -F above: unescaped, the `$` is a BRE metacharacter and the match fails
    # against CORRECT code — a red that sends the next reader to debug working software.
    bash -n "$pre"          # a mutant that cannot parse is not evidence (OBS-193)

    local root; root=$(_sandbox z)
    cp "$pre" "$FRAMEWORK_ROOT/agents/context/lib/.focus-pre-t2874.sh" 2>/dev/null || skip "cannot stage pre-fix copy"
    # Drive the old do_focus directly: source it with the sandbox env and call it.
    run env PROJECT_ROOT="$root" TASKS_DIR="$root/.tasks" CONTEXT_DIR="$root/.context" \
        bash -c "source '$FRAMEWORK_ROOT/lib/paths.sh' 2>/dev/null; source '$pre'; do_focus T-9002"
    rm -f "$FRAMEWORK_ROOT/agents/context/lib/.focus-pre-t2874.sh"

    # THE DEFECT: the completed id is accepted (exit 0) — the writable-but-unusable state.
    [ "$status" -eq 0 ]
}
