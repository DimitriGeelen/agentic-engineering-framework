#!/usr/bin/env bats
# T-2734 — closing an inception task must work when the project root is not the
# framework root.
#
# check_inception_scope_trace (T-1984) runs its reachability check through
# `python3 - <<'PYEOF'`. The heredoc derived sys.path from __file__, but a script
# read from STDIN has __file__ == '<stdin>'; abspath() resolved that against the
# CWD and three dirname()s produced '/' — always, measured from everywhere. The
# import survived only because Python prepends the CWD to sys.path for a stdin
# script and the framework root happens to contain lib/.
#
# Every consumer runs `.agentic-framework/bin/fw task update …` from its own
# root, so every consumer got ModuleNotFoundError and RC=1 on inception close.
#
# These tests deliberately run with CWD *outside* the framework. A test that ran
# from the framework root would pass against the broken code — that accident is
# the whole defect.

load ../test_helper

_make_inception() {
    local project_dir="$1" task_id="${2:-T-9007}"
    cat > "$project_dir/.tasks/active/${task_id}-test.md" <<EOF
---
id: ${task_id}
name: "Inception close from a consumer root"
description: test
status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-27T00:00:00Z
last_update: 2026-04-27T00:00:00Z
date_finished: null
---

# ${task_id}

## Acceptance Criteria

### Agent
- [x] done

## Verification

echo ok

## Updates
EOF
}

@test "T-2734: inception close succeeds when CWD and project root are not the framework" {
    PROJECT="$(create_test_project)"
    _make_inception "$PROJECT"
    cd "$PROJECT"
    PROJECT_ROOT="$PROJECT" run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" \
        T-9007 --status work-completed --skip-acceptance-criteria --skip-inception-decision
    [ "$status" -eq 0 ]
}

@test "T-2734: no ModuleNotFoundError traceback reaches the operator" {
    # Red-for-the-stated-reason: exit status alone would not distinguish this
    # failure from any other close-gate refusal.
    PROJECT="$(create_test_project)"
    _make_inception "$PROJECT" T-9008
    cd "$PROJECT"
    PROJECT_ROOT="$PROJECT" run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" \
        T-9008 --status work-completed --skip-acceptance-criteria --skip-inception-decision
    [[ "$output" != *"ModuleNotFoundError"* ]]
    [[ "$output" != *"Traceback"* ]]
}

@test "T-2734: the framework root itself still closes inceptions (no regression)" {
    # This is the path that worked by accident. It must keep working for the
    # right reason now.
    PROJECT="$(create_test_project)"
    _make_inception "$PROJECT" T-9009
    cd "$FRAMEWORK_ROOT"
    PROJECT_ROOT="$PROJECT" run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" \
        T-9009 --status work-completed --skip-acceptance-criteria --skip-inception-decision
    [ "$status" -eq 0 ]
    [[ "$output" != *"ModuleNotFoundError"* ]]
}

@test "T-2734 shape guard: no stdin-piped python block derives a path from __file__" {
    # Source-derived, no allowlist (L-533). __file__ is '<stdin>' for a piped
    # script, so any path computed from it is silently wrong. One instance
    # remains by design in agents/audit/audit.sh: there it is the eagerly
    # evaluated DEFAULT of an os.environ.get("PROJECT_ROOT", …) whose key is
    # always set, so the bad value is computed and discarded. It is excluded by
    # SHAPE (guarded by environ.get on the same line), not by filename.
    local hits
    hits="$(grep -rn 'abspath(__file__)' "$FRAMEWORK_ROOT"/agents/*.sh "$FRAMEWORK_ROOT"/agents/*/*.sh "$FRAMEWORK_ROOT"/bin/fw 2>/dev/null \
        | grep -v 'environ\.get(' || true)"
    [ -z "$hits" ] || {
        echo "stdin-piped python deriving a path from __file__:" >&2
        echo "$hits" >&2
        false
    }
}

@test "T-2734 guard control: the shape guard catches a reintroduced instance" {
    local copy="$TEST_TEMP_DIR/regressed.sh"
    printf 'python3 - <<PY\nimport os\np = os.path.dirname(os.path.abspath(__file__))\nPY\n' > "$copy"
    run bash -c "grep -rn 'abspath(__file__)' '$copy' | grep -v 'environ\.get(' || true"
    [ -n "$output" ]
}
