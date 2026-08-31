#!/usr/bin/env bats
# T-3235 — a task file in .tasks/completed/ carries `horizon: null`, whichever
# branch archived it.
#
# Two branches in update-task.sh move a task into completed/, and their entry
# conditions are EXACT COMPLEMENTS:
#
#   ordinary completion   OLD_STATUS != work-completed
#   partial-complete      OLD_STATUS == NEW_STATUS == work-completed,
#     recheck             file still in active/
#
# T-2163 wrote the horizon null-ing inside the first, and T-2300 widened it
# there after eight CTL-030 instances. No widening of a site can reach a branch
# whose entry condition is that site's complement, so the recheck branch
# archived files with the horizon untouched for as long as it existed. The fix
# is a post-condition on final LOCATION, asserted once — which is what the
# "either branch" leg below actually measures.
#
# The sharp end: `fw task archive-eligible` re-invokes --status work-completed
# on tasks already at work-completed in active/, so it drives EXCLUSIVELY
# through the branch that was unfixed.
#
# Reported upstream by peer 832-Workflow-designer (their T-654 BUG 1) and
# confirmed in-tree before anything changed. Zero instances in this corpus at
# the time — the fault was latent, not observed.
#
# METHOD (from 832's own note on their first prober, which went green against
# the wrong branch): ASSERT WHICH BRANCH RAN. The obvious fixture — tick the
# human AC, re-run — leaves `status: started-work` and is an ordinary
# transition that never enters the recheck branch at all. Every leg here pins
# the branch by the line only that branch prints.
#
# `! cmd` at statement position is INERT in bats (L-628) — explicit compares only.

load ../test_helper

UPDATE_TASK="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" \
             "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.tasks/templates" \
             "$PROJECT_ROOT/.context/working" \
             "$PROJECT_ROOT/.context/episodic"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    echo "# template" > "$PROJECT_ROOT/.tasks/templates/default.md"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# $1 id, $2 status, $3 horizon, $4 human-AC-state ("[ ]" or "[x]" or "none")
_mktask() {
    local id="$1" st="$2" hz="$3" human="$4"
    local f="$PROJECT_ROOT/.tasks/active/${id}-fixture.md"
    {
        echo "---"
        echo "id: $id"
        echo "name: \"fixture for the archived-horizon invariant\""
        echo "description: \"fixture\""
        echo "status: $st"
        echo "workflow_type: build"
        echo "owner: agent"
        echo "horizon: $hz"
        echo "tags: []"
        echo "created: 2026-08-31T00:00:00Z"
        echo "last_update: 2026-08-31T00:00:00Z"
        echo "date_finished: null"
        echo "---"
        echo ""
        echo "# $id: fixture"
        echo ""
        echo "## Acceptance Criteria"
        echo ""
        echo "### Agent"
        echo "- [x] the agent side is done"
        if [ "$human" != none ]; then
            echo ""
            echo "### Human"
            echo "- $human [REVIEW] the human side"
            echo "  **Steps:**"
            echo "  1. look"
            echo "  **Expected:** fine"
            echo "  **If not:** say so"
        fi
        echo ""
        echo "## Verification"
        echo ""
    } > "$f"
    printf '%s' "$f"
}

_horizon_of() {
    grep '^horizon:' "$1" | head -1 | sed 's/^horizon:[[:space:]]*//'
}

_completed() { printf '%s' "$PROJECT_ROOT/.tasks/completed/$1-fixture.md"; }

# ── the bug ──────────────────────────────────────────────────────────────────

@test "archived through the PARTIAL-COMPLETE RECHECK branch → horizon null" {
    _mktask T-9401 work-completed now "[x]" >/dev/null
    run "$UPDATE_TASK" T-9401 --status work-completed
    # branch assertion FIRST: without it a green here could be the ordinary path
    [[ "$output" == *"Re-checking partial-complete status"* ]]
    [ -f "$(_completed T-9401)" ]
    [ "$(_horizon_of "$(_completed T-9401)")" = "null" ]
}

# ── controls: the branch that already worked, and the case that must NOT ──────

@test "archived through the ORDINARY branch → horizon null (no regression)" {
    _mktask T-9402 started-work now none >/dev/null
    run "$UPDATE_TASK" T-9402 --status work-completed
    # the recheck line must NOT appear — this is the complementary branch
    if [[ "$output" == *"Re-checking partial-complete status"* ]]; then
        echo "fixture entered the WRONG branch" >&2; false
    fi
    [ -f "$(_completed T-9402)" ]
    [ "$(_horizon_of "$(_completed T-9402)")" = "null" ]
}

@test "partial-complete that STAYS in active/ keeps its horizon" {
    # Deliberate behaviour, not an oversight: the file renders from its stored
    # horizon while the human still owns it. A status-keyed check would break
    # exactly this case, which is why the invariant keys on LOCATION.
    local f; f="$(_mktask T-9403 started-work now "[ ]")"
    run "$UPDATE_TASK" T-9403 --status work-completed
    [ -f "$f" ]
    [ "$(_horizon_of "$f")" = "now" ]
    [ ! -f "$(_completed T-9403)" ]
}

# ── MUTATION CONTROL ─────────────────────────────────────────────────────────

@test "removing the post-condition re-opens the bug on the recheck branch" {
    # Derived from live source: reverting the fix must redden this, otherwise
    # the legs above are measuring the fixture rather than the fix.
    #
    # update-task.sh derives FRAMEWORK_ROOT from its own location and dies on
    # the first `source` if it is copied into a bare temp dir (832's note), so
    # the mutant gets a symlink farm that makes its parent look like the real
    # framework root.
    local farm="$TEST_TEMP_DIR/farm"
    mkdir -p "$farm/agents/task-create"
    local e
    for e in agents lib bin .tasks .fabric policy tools FRAMEWORK.md; do
        [ -e "$FRAMEWORK_ROOT/$e" ] || continue
        [ "$e" = agents ] && continue
        ln -s "$FRAMEWORK_ROOT/$e" "$farm/$e"
    done
    for e in "$FRAMEWORK_ROOT/agents"/*; do
        [ "$(basename "$e")" = task-create ] && continue
        ln -s "$e" "$farm/agents/$(basename "$e")"
    done
    for e in "$FRAMEWORK_ROOT/agents/task-create"/*; do
        [ "$(basename "$e")" = update-task.sh ] && continue
        ln -s "$e" "$farm/agents/task-create/$(basename "$e")"
    done
    local mutant="$farm/agents/task-create/update-task.sh"
    cp "$UPDATE_TASK" "$mutant"

    # the post-condition is exactly one line; remove it and nothing else
    local n
    n="$(grep -c 'ARCHIVED-HORIZON INVARIANT' "$mutant")"
    [ "$n" -eq 1 ]
    python3 - "$mutant" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p).read()
blk = '''if [ -n "${TASK_FILE:-}" ] && [ -f "$TASK_FILE" ] \\
   && [ "$(dirname "$TASK_FILE")" = "$TASKS_DIR/completed" ]; then
    _sed_i "s/^horizon:.*/horizon: null/" "$TASK_FILE"
fi
'''
assert blk in s, "mutation target not found — the fix moved, update this test"
open(p, 'w').write(s.replace(blk, '', 1))
PY
    bash -n "$mutant"

    _mktask T-9404 work-completed now "[x]" >/dev/null
    run "$mutant" T-9404 --status work-completed
    [[ "$output" == *"Re-checking partial-complete status"* ]]
    [ -f "$(_completed T-9404)" ]
    # the whole point: the mutant archives it with the horizon untouched
    [ "$(_horizon_of "$(_completed T-9404)")" = "now" ]

    # control — the mutant is otherwise functional, so the leg above is
    # measuring the removed line and not a broken subject
    _mktask T-9405 started-work now none >/dev/null
    run "$mutant" T-9405 --status work-completed
    [ -f "$(_completed T-9405)" ]
}

# ── the corpus, and the sweep that would have populated it ───────────────────

@test "no task in the real corpus carries horizon: now under completed/" {
    local n
    n="$(grep -l '^horizon: now$' "$FRAMEWORK_ROOT/.tasks/completed"/*.md 2>/dev/null | wc -l)"
    [ "$n" -eq 0 ]
}

@test "fw task archive-eligible drives through the recheck branch" {
    # Why this fault had a sharp end rather than staying theoretical: the sweep
    # the audit recommends re-invokes the same status on tasks already at
    # work-completed, which is the recheck branch's exact entry condition.
    grep -q "'--status', 'work-completed'" "$FRAMEWORK_ROOT/bin/fw"
}
