#!/usr/bin/env bats
# T-2878 — the capture verbs must be reachable in the state that completing work creates.
#
# Closing a task nulls focus. The very next things the framework PRESCRIBES — record the
# learning, capture the observation, generate the handover — were then refused by the same
# Bash gate, with no active task to satisfy it and no way to create one that would be honest.
# Third instance of the class: T-2052 (`fw task create`), T-2054 (`git commit`), this.
#
# WHY THE CONTROLS ARE IN THE SAME FILE:
# The cheap wrong fix is a blanket `context)` or `fw` allowance, which passes every ALLOWED
# leg below and cannot be told apart from the verb-scoped fix by reading them. `fw config set`
# (mutating, same `fw` prefix) and `rm -rf` (the outer safe-list boundary) must STILL be gated
# — those two legs are the only thing separating this fix from "turn the gate off".
#
# Class: L-399 / T-1890 — a remedy the framework names must work when followed.

load ../test_helper

HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
LIB="$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"

# The post-completion state exactly: focus nulled, nothing in active/.
_sandbox() {
    local root="$BATS_TEST_TMPDIR/proj$1"
    mkdir -p "$root/.tasks/active" "$root/.tasks/completed" "$root/.context/working"
    printf -- '---\nid: T-9002\nname: "just closed"\nstatus: work-completed\n---\n' \
        > "$root/.tasks/completed/T-9002-closed.md"
    printf 'current_task:\n' > "$root/.context/working/focus.yaml"
    echo "$root"
}

# Drive the real hook. CLAUDECODE=1 is required: without the agent-control signal the gate
# degrades to advisory and every ALLOWED leg below would pass vacuously.
_gate() {
    local root="$1" cmd="$2"
    printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd" \
    | CLAUDECODE=1 PROJECT_ROOT="$root" CONTEXT_DIR="$root/.context" TASKS_DIR="$root/.tasks" \
      bash "$HOOK" 2>&1
}

@test "T-2878: SMOKE — the sandbox really is the no-active-task state" {
    # If the gate does not fire here, every leg below is about a gate that was never armed.
    local root; root=$(_sandbox smoke)
    run _gate "$root" "cargo build"
    [ "$status" -eq 2 ]
}

@test "T-2878: fw note is reachable with no active task" {
    local root; root=$(_sandbox n)
    run _gate "$root" "bin/fw note add observation"
    [ "$status" -eq 0 ]
}

@test "T-2878: fw handover is reachable with no active task" {
    # Session End Protocol runs precisely when nothing is active.
    local root; root=$(_sandbox h)
    run _gate "$root" "bin/fw handover --commit"
    [ "$status" -eq 0 ]
}

@test "T-2878: the four context capture verbs are reachable with no active task" {
    local root; root=$(_sandbox c)
    local v
    for v in add-learning add-pattern add-decision generate-episodic; do
        run _gate "$root" "bin/fw context $v something"
        [ "$status" -eq 0 ] || { echo "GATED: fw context $v"; return 1; }
    done
}

@test "T-2878: WIDENING CONTROL — fw config set is still gated" {
    # A blanket `fw` or `context` allowance would let this through. It is a mutating verb
    # with no bootstrap justification; it must still require a task.
    local root; root=$(_sandbox w)
    run _gate "$root" "bin/fw config set FW_PORT 3001"
    [ "$status" -eq 2 ]
}

@test "T-2878: BOUNDARY CONTROL — rm -rf is still gated" {
    local root; root=$(_sandbox r)
    run _gate "$root" "rm -rf /tmp/anything"
    [ "$status" -eq 2 ]
}

@test "T-2878: ANTI-VACUITY — removing the new arms re-closes the deadlock" {
    # DURABLE MUTATION of live source, deliberately not `git show HEAD~N:`: a git-ref teeth
    # check goes permanently inert the moment another commit lands, skipping while reporting
    # `ok` (T-2874 hit exactly that). Mutating the checked-in file has no expiry.
    #
    # This leg is function-level, not hook-level, because the hook resolves its lib from its
    # own $SCRIPT_DIR — a mutant lib is only reachable by rebuilding the whole agents/context
    # tree, which would test the copy rather than the source. The ALLOWED legs above are
    # end-to-end through the real hook; this one proves those legs are load-bearing.
    local mutant="$BATS_TEST_TMPDIR/safe-commands-mutant.sh"
    sed -e 's/|add-learning|add-pattern|add-decision|generate-episodic)/)/' \
        -e '/^                note)$/,/^                    ;;$/d' \
        -e '/^                handover)$/,/^                    ;;$/d' \
        "$LIB" > "$mutant"
    local delta; delta=$(diff "$LIB" "$mutant" || true)   # diff exits 1 on "differs" (L-387)
    [ -n "$delta" ]        # the mutation actually applied — a no-op sed proves nothing
    bash -n "$mutant"      # a mutant that cannot parse is not evidence (OBS-193)

    # THE DEFECT: with the arms gone, the prescribed capture verbs are unreachable again.
    run bash -c "source '$mutant'; is_bash_safe_command 'bin/fw note add x'"
    [ "$status" -ne 0 ]
    run bash -c "source '$mutant'; is_bash_safe_command 'bin/fw handover'"
    [ "$status" -ne 0 ]
    run bash -c "source '$mutant'; is_bash_safe_command 'bin/fw context add-learning y'"
    [ "$status" -ne 0 ]

    # And the fixed source still allows them — pins the mutation as the cause, not the harness.
    run bash -c "source '$LIB'; is_bash_safe_command 'bin/fw note add x'"
    [ "$status" -eq 0 ]
}
