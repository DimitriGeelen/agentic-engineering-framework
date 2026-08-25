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

@test "T-2874: ANTI-VACUITY — removing the scope argument re-opens the defect" {
    # DURABLE MUTATION, deliberately not `git show HEAD~1:`. A git-ref teeth check goes
    # permanently inert the moment another commit lands: this suite was committed one
    # commit after the fix, so HEAD~1 already carried `active` and the leg SKIPPED —
    # reporting `ok` while asserting nothing. Caught only because the task's Verification
    # greps for `# skip` on this leg. Mutating the LIVE source has no such expiry.
    local mutant="$BATS_TEST_TMPDIR/focus-mutant.sh"
    # grep -F / sed with the `$` escaped: unescaped it is a BRE metacharacter and would
    # fail against CORRECT code — a red that sends the next reader to debug working software.
    sed 's|find_task_file "\$task_id" active|find_task_file "$task_id"|' \
        "$FOCUS_SH" > "$mutant"
    if diff -q "$FOCUS_SH" "$mutant" >/dev/null; then false; fi   # the mutation actually applied
    bash -n "$mutant"                            # a mutant that cannot parse is not evidence (OBS-193)

    local root; root=$(_sandbox z)
    run env PROJECT_ROOT="$root" TASKS_DIR="$root/.tasks" CONTEXT_DIR="$root/.context" \
        bash -c "source '$FRAMEWORK_ROOT/lib/paths.sh' 2>/dev/null; source '$mutant'; do_focus T-9002"

    # THE DEFECT: the completed id is accepted — the writable-but-unusable state.
    [ "$status" -eq 0 ]
    [[ "$output" != *"completed, not active"* ]]
}
