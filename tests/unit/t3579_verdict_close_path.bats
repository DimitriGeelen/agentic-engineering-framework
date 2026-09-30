#!/usr/bin/env bats
# T-3579 — closing on an independent reviewer's green verdict is the NORMAL path.
#
# Every step is the shipped code: `fw reviewer verdict record`, then update-task.sh
# --status work-completed. No --skip-* flag, no FW_ALLOW_* variable anywhere in this
# file — that absence is the assertion. A render-surface task with a human-owned taste
# [REVIEW] criterion is the exact shape that took --skip-render-review +
# FW_ALLOW_PARTIAL_COMPLETE_EDIT=1 seven times on 2026-09-29/30.

load ../test_helper

FW="$BATS_TEST_DIRNAME/../../bin/fw"
UPDATE_TASK="$BATS_TEST_DIRNAME/../../agents/task-create/update-task.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.tasks/templates" "$PROJECT_ROOT/.context/working" \
             "$PROJECT_ROOT/.context/episodic" "$PROJECT_ROOT/bin"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    ln -sf "$FRAMEWORK_ROOT/bin/fw" "$PROJECT_ROOT/bin/fw"
    echo "screenshot notes" > "$PROJECT_ROOT/evidence.md"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_make_render_task() {
    local f="$PROJECT_ROOT/.tasks/active/T-9200-render-fixture.md"
    cat > "$f" <<'TASK'
---
id: T-9200
name: "render fixture"
description: "render-surface task with one taste criterion"
status: started-work
workflow_type: build
owner: human
horizon: now
tags: []
components: [web/templates/fixture.html]
created: 2026-09-30T00:00:00Z
last_update: 2026-09-30T00:00:00Z
date_finished: null
---

# T-9200: render fixture

## Acceptance Criteria

### Agent
- [x] Fixture body is in place

### Human
- [ ] [REVIEW] The rendered page reads clearly
  **Steps:**
  1. Open the page
  **Expected:** it reads as a peer briefing
  **If not:** note the section that stalls

## Verification

## Recommendation

**Recommendation:** GO

**Rationale:** Fixture.

## Updates
TASK
    echo "$f"
}

_record() {
    "$FW" reviewer verdict record T-9200 --ac 1 --outcome "$1" --reviewer "openai/gpt-5" \
        --rung cross-vendor "${@:2}"
}

@test "without a verdict the render task is refused by the sovereignty gate" {
    _make_render_task >/dev/null
    run "$UPDATE_TASK" T-9200 --status work-completed
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "Sovereignty gate"
    [ "$(ls "$PROJECT_ROOT/.tasks/active" | grep -c '^T-9200-')" -eq 1 ]
}

@test "a green verdict closes the render task with no bypass flag, and the gate names the verdict" {
    local f; f="$(_make_render_task)"
    run _record green --evidence evidence.md
    [ "$status" -eq 0 ]

    run "$UPDATE_TASK" T-9200 --status work-completed
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Render-surface gate: satisfied by green verdict V-"
    echo "$output" | grep -q "openai/gpt-5"

    [ "$(ls "$PROJECT_ROOT/.tasks/completed" | grep -c '^T-9200-')" -eq 1 ]
    [ "$(ls "$PROJECT_ROOT/.tasks/active" | grep -c '^T-9200-')" -eq 0 ]
    grep -q "Reviewer verdict:\*\* green V-" "$PROJECT_ROOT/.tasks/completed/"T-9200-*.md
    grep -q '"kind":"verdict-apply"' "$PROJECT_ROOT/.context/reviews/applied.jsonl"

    # No bypass was used, so none was logged.
    ! grep -qs "skip-render-review\|skip-sovereignty\|skip-human-ownership" \
        "$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
}

@test "an amber verdict does not close it and lands on the refusal ledger" {
    _make_render_task >/dev/null
    run _record amber --guidance "tighten the second section"
    [ "$status" -eq 0 ]

    run "$UPDATE_TASK" T-9200 --status work-completed
    [ "$status" -ne 0 ]
    [ "$(ls "$PROJECT_ROOT/.tasks/active" | grep -c '^T-9200-')" -eq 1 ]
    grep -q '"class":"verdict-amber"' "$PROJECT_ROOT/.context/reviews/refusals-interim.jsonl"
}

@test "a verdict recorded before the criterion was edited no longer closes it" {
    local f; f="$(_make_render_task)"
    run _record green --evidence evidence.md
    [ "$status" -eq 0 ]
    sed -i 's/reads clearly/reads very clearly/' "$f"

    run "$UPDATE_TASK" T-9200 --status work-completed
    [ "$status" -ne 0 ]
    [ "$(ls "$PROJECT_ROOT/.tasks/active" | grep -c '^T-9200-')" -eq 1 ]
}

@test "the CLI refuses a green record from the producer" {
    _make_render_task >/dev/null
    git -C "$PROJECT_ROOT" init -q
    git -C "$PROJECT_ROOT" add -A
    # Env identity, not `-c user.name`: dispatch sessions export GIT_AUTHOR_* which wins.
    GIT_AUTHOR_NAME="Builder Bot" GIT_AUTHOR_EMAIL=b@x.y \
        GIT_COMMITTER_NAME="Builder Bot" GIT_COMMITTER_EMAIL=b@x.y \
        git -C "$PROJECT_ROOT" -c core.hooksPath=/dev/null commit -q -m "T-9200: build it"

    run "$FW" reviewer verdict record T-9200 --ac 1 --outcome green --reviewer "Builder Bot" \
        --rung same-agent --evidence evidence.md
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "never the producer"
    [ ! -f "$PROJECT_ROOT/.context/reviews/verdicts.jsonl" ]
}
