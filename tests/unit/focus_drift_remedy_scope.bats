#!/usr/bin/env bats
# T-2875 — the focus-drift block message must not name a remedy the framework refuses.
#
# The message offered "1. Switch focus first: fw context focus <TARGET>" unconditionally.
# T-2874 made `fw context focus` refuse a COMPLETED task id, so for a completed target the
# first remedy is a command the framework itself refuses: the agent follows it, gets a second
# refusal, and has to find options 2/3 unaided. The completed target is the common case —
# the usual trigger is a follow-up commit attributed to a task that just closed.
#
# WHY THE ASSERTIONS READ THE MESSAGE AND NOT rc:
# Both branches exit 2. rc cannot distinguish "offered the dead remedy" from "offered the
# working one", so an rc-only leg would pass against the unfixed hook. The defect lives
# entirely in the message text, so the message text is what is asserted.
#
# Class: L-399 / T-1890 — a bypass mechanism named in a block message must work when followed.

load ../test_helper

HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"

# Project with two active tasks and one completed one.
_sandbox() {
    local root="$BATS_TEST_TMPDIR/proj$1"
    mkdir -p "$root/.tasks/active" "$root/.tasks/completed" "$root/.context/working"
    printf -- '---\nid: T-9001\nname: "focused"\nstatus: started-work\n---\n' \
        > "$root/.tasks/active/T-9001-focused.md"
    printf -- '---\nid: T-9003\nname: "other active"\nstatus: started-work\n---\n' \
        > "$root/.tasks/active/T-9003-other.md"
    printf -- '---\nid: T-9002\nname: "closed"\nstatus: work-completed\n---\n' \
        > "$root/.tasks/completed/T-9002-closed.md"
    printf 'current_task: T-9001\n' > "$root/.context/working/focus.yaml"
    echo "$root"
}

# Drive the real hook. CLAUDECODE=1 is required: without an agent-control signal the drift
# path degrades to an advisory NOTE and prints no remedies at all, so every leg below would
# pass vacuously against any implementation.
_drift() {
    local root="$1" target="$2" hook="${3:-$HOOK}"
    python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','tool_input':{'command':sys.argv[1]}}))" \
        "git commit -m \"$target: something\"" \
    | CLAUDECODE=1 PROJECT_ROOT="$root" CONTEXT_DIR="$root/.context" TASKS_DIR="$root/.tasks" \
      bash "$hook" 2>&1
}

@test "T-2875: SMOKE — the harness actually reaches the drift block" {
    # If this fails, every message assertion below is about output that was never produced.
    local root; root=$(_sandbox smoke)
    run _drift "$root" T-9003
    [ "$status" -eq 2 ]
    [[ "$output" == *"FOCUS-DRIFT"* ]]
}

@test "T-2875: ACTIVE target — 'switch focus' is still offered" {
    local root; root=$(_sandbox a)
    run _drift "$root" T-9003
    [[ "$output" == *"context focus T-9003"* ]]
}

@test "T-2875: COMPLETED target — 'switch focus' is NOT offered" {
    # The defect. Unfixed, this prints `context focus T-9002`, which focus.sh refuses.
    local root; root=$(_sandbox b)
    run _drift "$root" T-9002
    [[ "$output" != *"context focus T-9002"* ]]
}

@test "T-2875: COMPLETED target — says why, and still names a working remedy" {
    local root; root=$(_sandbox c)
    run _drift "$root" T-9002
    [[ "$output" == *"not active"* ]]
    [[ "$output" == *"FW_SWITCH_FOCUS=1"* ]]
}

@test "T-2875: COMPLETED target — no reopen command is suggested" {
    # `fw task update <id> --status started-work` does NOT move a file from completed/ back
    # to active/ (no such move exists in update-task.sh), so focus would refuse it again.
    # Substituting it for the dead remedy would just relocate the defect.
    local root; root=$(_sandbox d)
    run _drift "$root" T-9002
    [[ "$output" != *"--status started-work"* ]]
}

@test "T-2875: ANTI-VACUITY — forcing the branch true re-opens the defect" {
    # DURABLE MUTATION of live source, deliberately not `git show HEAD~N:`: a git-ref teeth
    # check goes permanently inert the moment another commit lands, skipping while reporting
    # `ok` (T-2874 hit exactly that). Mutating the checked-in file has no expiry.
    local mutant="$BATS_TEST_TMPDIR/hook-mutant.sh"
    sed 's|if \[ -n "\$(find_task_file "\$TARGET_TASK" active)" \]; then|if true; then|' \
        "$HOOK" > "$mutant"
    local delta; delta=$(diff "$HOOK" "$mutant" || true)   # diff exits 1 on "differs" (L-387)
    [ -n "$delta" ]        # the mutation actually applied — a no-op sed proves nothing
    bash -n "$mutant"      # a mutant that cannot parse is not evidence (OBS-193)

    local root; root=$(_sandbox z)
    run _drift "$root" T-9002 "$mutant"
    # THE DEFECT: the completed target is offered a remedy the framework refuses.
    [[ "$output" == *"context focus T-9002"* ]]
}
