#!/usr/bin/env bats
# T-5118 (055 T-645, msg a56f7da3) — the closure commit of a task that sat partial-complete.
#
# A partial-complete task gets date_finished at its FIRST transition to work-completed and is
# finalised later (the same-status re-run that moves it to completed/). The T-4182 closure-commit
# window measured only date_finished, so a task finalised a day after it went partial-complete
# had its closure commit refused while focus sat on another task. Finalisation now records
# date_finalised, and the window measures from the later of the two.

load ../test_helper
export FW_TEST_SKIP_TASK_CONTEXT_GATE=1  # T-4907: fixture tasks carry no ## Context

HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"

# $1 suffix, $2 date_finished, $3 date_finalised (empty = field absent)
_sandbox() {
    local root="$BATS_TEST_TMPDIR/proj$1"
    mkdir -p "$root/.tasks/active" "$root/.tasks/completed" "$root/.context/working"
    printf -- '---\nid: T-9001\nname: "focused"\nstatus: started-work\n---\n' \
        > "$root/.tasks/active/T-9001-focused.md"
    {
        printf -- '---\nid: T-9002\nname: "closed"\nstatus: work-completed\n'
        printf 'date_finished: %s\n' "$2"
        [ -n "$3" ] && printf 'date_finalised: %s\n' "$3"
        printf -- '---\n'
    } > "$root/.tasks/completed/T-9002-closed.md"
    printf 'current_task: T-9001\n' > "$root/.context/working/focus.yaml"
    echo "$root"
}

_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
_old() { date -u -d '-1 day' +%Y-%m-%dT%H:%M:%SZ; }

_run_hook() {
    python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','cwd':sys.argv[2],'tool_input':{'command':sys.argv[1]}}))" "$2" "$1" \
    | CLAUDECODE=1 PROJECT_ROOT="$1" CONTEXT_DIR="$1/.context" TASKS_DIR="$1/.tasks" bash "$HOOK" 2>&1
}

@test "finished a day ago, finalised just now: closure commit passes" {
    local root; root=$(_sandbox a "$(_old)" "$(_now)")
    run _run_hook "$root" 'git commit -m "T-9002: close"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-4182"* ]]
}

@test "control: finished AND finalised a day ago is still blocked" {
    local root; root=$(_sandbox b "$(_old)" "$(_old)")
    run _run_hook "$root" 'git commit -m "T-9002: close"'
    [ "$status" -eq 2 ]
}

@test "control: finished a day ago, never finalised, is still blocked" {
    local root; root=$(_sandbox c "$(_old)" "")
    run _run_hook "$root" 'git commit -m "T-9002: close"'
    [ "$status" -eq 2 ]
}

@test "control: recently finalised, but not a commit, is still blocked" {
    local root; root=$(_sandbox d "$(_old)" "$(_now)")
    run _run_hook "$root" 'bin/fw task update T-9002 --add-tag x'
    [ "$status" -eq 2 ]
}

# Finalisation itself (the T-4653 fixture shape: partial-complete, last Human box ticked).
_partial() {
    P="$BATS_TEST_TMPDIR/fin$1"
    mkdir -p "$P/.tasks/active" "$P/.tasks/completed" "$P/.context/working"
    { printf -- '---\nid: T-9999\nname: "fixture"\nstatus: work-completed\n'
      printf 'workflow_type: build\nowner: human\nhorizon: now\n'
      printf 'created: 2026-08-31T00:00:00Z\nlast_update: 2026-08-31T00:00:00Z\n'
      [ -n "$2" ] && printf '%s\n' "$2"
      printf -- '---\n\n# T-9999: fixture\n\n## Context\n\nx\n\n## Acceptance Criteria\n\n'
      printf '### Agent\n- [x] done\n\n### Human\n- [x] [REVIEW] ticked by operator\n\n'
      printf '## Verification\n\ntrue\n\n## Decisions\n\n---\nnot frontmatter\n'; } \
        > "$P/.tasks/active/T-9999-fixture.md"
}

_finalize() {
    PROJECT_ROOT="$P" timeout 120 bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" \
        T-9999 --status work-completed 2>&1
}

@test "finalisation writes date_finalised inside the frontmatter and keeps date_finished" {
    _partial a "date_finished: 2026-08-31T01:00:00Z"
    run _finalize
    f="$P/.tasks/completed/T-9999-fixture.md"
    [ -f "$f" ]
    fm=$(awk '/^---/{n++; next} n==1' "$f")
    grep -q '^date_finished: 2026-08-31T01:00:00Z$' <<<"$fm"
    grep -qE '^date_finalised: 20[0-9]{2}-' <<<"$fm"
    [ "$(grep -c '^date_finalised:' "$f")" -eq 1 ]
    grep -q '^not frontmatter$' "$f"
}

@test "finalisation replaces an existing date_finalised line rather than adding a second" {
    _partial b "date_finalised: 2020-01-01T00:00:00Z"
    run _finalize
    f="$P/.tasks/completed/T-9999-fixture.md"
    [ -f "$f" ]
    [ "$(grep -c '^date_finalised:' "$f")" -eq 1 ]
    ! grep -q '^date_finalised: 2020-01-01' "$f"
}
