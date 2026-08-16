#!/usr/bin/env bats
# T-3030 / G-083: the autonomous dispatch loop and an interactive session share
# one working tree. These tests pin the guard that separates them, and the
# provenance record that makes a worker's writes attributable afterwards.
#
# The case being regressed is not hypothetical. On 2026-08-16 a worker was
# dispatched onto T-3028 four seconds after a tick that read `current_task:
# null` — nulled by the close path itself (update-task.sh:2044-2055) on a
# completion that was itself wrong — while the interactive session was
# mid-reconciliation on that task. Both wrote agents/task-create/update-task.sh.
#
# So the tests below deliberately assert against a NULL focus. Anything that
# passes only because focus happens to name the task is re-testing the guard
# that already failed.
#
# Every fixture here is a real git repo, because the guard's oracle is git. The
# sibling suites (t2489, t2491) use bare mktemp dirs, where `git status` errors
# and the guard fails open — which is correct behaviour but tests nothing.

load ../test_helper

setup() {
    GROOT="$(mktemp -d)"
    mkdir -p "$GROOT/.tasks/active" "$GROOT/.context/working" \
             "$GROOT/.context/project/workflows" "$GROOT/lib"
    cat > "$GROOT/.context/project/workflows/default.yaml" <<'YAML'
task_type: default
worker_kind: TermLink
model: sonnet
prompt_template: prompts/default.md
strict_mcp_config: true
YAML
    # NULL focus — the origin condition, not a convenience.
    echo "current_task: null" > "$GROOT/.context/working/focus.yaml"
    _task T-1001 "- [ ] do the real thing"
    echo "print('source')" > "$GROOT/lib/thing.py"

    git -C "$GROOT" init -q
    git -C "$GROOT" config user.email t3030@test
    git -C "$GROOT" config user.name t3030
    git -C "$GROOT" add -A
    git -C "$GROOT" commit -qm "fixture baseline"
}

teardown() { rm -rf "$GROOT"; }

_task() {
    local id="$1" ac="$2"
    cat > "$GROOT/.tasks/active/${id}-x.md" <<EOF
---
id: ${id}
name: "fixture ${id}"
workflow_type: build
owner: agent
horizon: now
status: started-work
---

## Acceptance Criteria

### Agent
${ac}
EOF
}

_pick() {
    PROJECT_ROOT="$GROOT" python3 "$FRAMEWORK_ROOT/lib/resolver.py" pick --json
}

# Emit "ELIGIBLE" or the exclusion reason for T-1001, so each assertion below
# reads as the thing it means rather than as a json incantation.
_verdict() {
    _pick | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('ELIGIBLE' if 'T-1001' in d.get('eligible', []) else d['excluded'].get('T-1001', 'MISSING'))
"
}

@test "t3030: baseline — a clean tree lets the task through (guard is not always-on)" {
    # Without this the whole suite could pass on a guard that excludes
    # everything unconditionally, which is the failure mode that reads in the
    # journal as an empty backlog.
    run _verdict
    [ "$status" -eq 0 ]
    [ "$output" = "ELIGIBLE" ]
}

@test "t3030: THE REGRESSION — an uncommitted task file is excluded even with focus null" {
    echo "" >> "$GROOT/.tasks/active/T-1001-x.md"
    run _verdict
    [[ "$output" == *"task file uncommitted"* ]]
}

@test "t3030: the per-task clause has no off switch" {
    # The tree-wide clause is a judgement call an operator may reasonably
    # decline. Dispatching a worker onto a task file someone is editing is not.
    echo "" >> "$GROOT/.tasks/active/T-1001-x.md"
    FW_DISPATCH_REQUIRE_CLEAN_TREE=0 run _verdict
    [[ "$output" == *"task file uncommitted"* ]]
}

@test "t3030: uncommitted source anywhere excludes everything, and names the file" {
    echo "print('edited by a live session')" >> "$GROOT/lib/thing.py"
    run _verdict
    [[ "$output" == *"working tree has uncommitted changes"* ]]
    [[ "$output" == *"lib/thing.py"* ]]
    # The reason must carry its own escape hatch — an agent that trips this
    # reads the journal line, not this file.
    [[ "$output" == *"FW_DISPATCH_REQUIRE_CLEAN_TREE=0"* ]]
}

@test "t3030: the tree-wide clause is switchable, the way its own message says" {
    echo "print('edited by a live session')" >> "$GROOT/lib/thing.py"
    FW_DISPATCH_REQUIRE_CLEAN_TREE=0 run _verdict
    [ "$output" = "ELIGIBLE" ]
}

@test "t3030: machine churn does not block dispatch" {
    # Counters, metrics and generated docs are dirty on essentially every tick.
    # If they counted, the guard would read the tree as permanently busy and
    # silently disable autonomy — indistinguishable in the journal from having
    # nothing to do, i.e. exactly the failure of the guard this replaces.
    echo "tick" >> "$GROOT/.context/working/focus.yaml"
    run _verdict
    [ "$output" = "ELIGIBLE" ]
}

@test "t3030: untracked files do not block dispatch" {
    # --untracked-files=no is deliberate: scratch output, editor droppings and
    # a half-written new file are not evidence of a second writer mid-edit.
    echo "scratch" > "$GROOT/notes.txt"
    run _verdict
    [ "$output" = "ELIGIBLE" ]
}

@test "t3030: a non-git tree fails open rather than latching the loop off" {
    rm -rf "$GROOT/.git"
    run _verdict
    [ "$output" = "ELIGIBLE" ]
}

# ── Provenance (spawn.py) ────────────────────────────────────────────────────

@test "t3030: worker writes are attributed from git state, including shell-created files" {
    # The property that matters. In the origin incident the worker CREATED
    # tests/unit/ac_structure_close_gate.bats using 40 Bash calls, 8 Edit and
    # ZERO Write — so scanning tool_use blocks for file_path would have reported
    # that file as touched by nobody. git sees it; tool names do not.
    run env PROJECT_ROOT="$GROOT" python3 -c "
import sys
sys.path.insert(0, '$FRAMEWORK_ROOT/lib')
import spawn, subprocess
before = spawn._git_state()
# Stand in for the worker: a redirection and an in-place edit, no Write tool.
subprocess.run(['bash', '-c', 'echo new > \"\$1/lib/created.py\" && '
                'sed -i \"s/source/mutated/\" \"\$1/lib/thing.py\"',
                '_', '$GROOT'], check=True)
subprocess.run(['git', '-C', '$GROOT', 'add', '-A'], check=True,
               capture_output=True)
w = spawn._writes_between(before, spawn._git_state())
print('PATHS', sorted(w['paths']))
print('GUARD', w['clean_tree_guard'])
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"lib/created.py"* ]]
    [[ "$output" == *"lib/thing.py"* ]]
    [[ "$output" == *"GUARD True"* ]]
}

@test "t3030: an unreadable tree yields no provenance record, not an empty one" {
    # "The worker wrote nothing" and "I could not look" must not render the
    # same. cmd_explain prints a distinct line for each; this pins the source.
    run env PROJECT_ROOT="$GROOT" python3 -c "
import sys
sys.path.insert(0, '$FRAMEWORK_ROOT/lib')
import spawn
print('NONE' if spawn._writes_between(None, {'a': ' M'}) is None else 'RECORD')
print('NONE' if spawn._writes_between({'a': ' M'}, None) is None else 'RECORD')
print('EMPTY' if spawn._writes_between({}, {})['paths'] == [] else 'NONEMPTY')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"NONE"* ]]
    [[ "$output" != *"RECORD"* ]]
    [[ "$output" == *"EMPTY"* ]]
}

@test "t3030: provenance records the guard state, so a degraded run is readable as degraded" {
    # With the clean-tree guard off, another writer may have been active, and
    # the paths are correlation rather than attribution. The record has to say
    # so or a reader will over-trust it.
    run env PROJECT_ROOT="$GROOT" FW_DISPATCH_REQUIRE_CLEAN_TREE=0 python3 -c "
import sys
sys.path.insert(0, '$FRAMEWORK_ROOT/lib')
import spawn
print('GUARD', spawn._writes_between({}, {})['clean_tree_guard'])
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GUARD False"* ]]
}
