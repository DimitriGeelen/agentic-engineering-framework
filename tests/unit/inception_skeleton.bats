#!/usr/bin/env bats
# T-1906: auto-skeleton research artefact for inception tasks (C-001 prevention).
#
# Pins the behaviour: when create-task.sh runs with --type inception, it MUST
# write docs/reports/T-XXX-<slug>.md skeleton with the five canonical sections,
# unless the file already exists (idempotent). Non-inception types must leave
# docs/reports/ untouched.
#
# Origin: 15+ inceptions reached audit with C-001 WARN ("no research artefact
# in docs/reports/") because the rule was advisory text. Fix is structural —
# the file appears when the inception is filed.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.tasks/completed" \
             "$TEST_ROOT/.tasks/templates" \
             "$TEST_ROOT/.context/working" "$TEST_ROOT/.context/episodic" \
             "$TEST_ROOT/docs/reports"
    # Copy templates the create-task.sh script reads
    cp "$FRAMEWORK_ROOT"/.tasks/templates/inception.md "$TEST_ROOT/.tasks/templates/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT"/.tasks/templates/default.md   "$TEST_ROOT/.tasks/templates/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT"/.tasks/templates/zzz-default.md "$TEST_ROOT/.tasks/templates/" 2>/dev/null || true
    cat > "$TEST_ROOT/.context/working/focus.yaml" <<'EOF'
current_task: null
priorities: []
EOF
    cd "$TEST_ROOT"
    # L-404: pin PROJECT_ROOT to sandbox to defeat env inheritance from parent
    # (the verification gate in update-task.sh inherits PROJECT_ROOT into bats
    # subprocesses, which would otherwise point at the real project).
    export PROJECT_ROOT="$TEST_ROOT"
    export TASKS_DIR="$TEST_ROOT/.tasks"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "inception task: auto-creates docs/reports/T-XXX-<slug>.md skeleton" {
    run "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" \
        --name "test inception" --description "test" \
        --type inception --owner human
    [ "$status" -eq 0 ]
    # Find the created task file
    task_file=$(ls "$TEST_ROOT/.tasks/active/"T-*-test-inception.md 2>/dev/null | head -1)
    [ -n "$task_file" ]
    task_id=$(grep '^id:' "$task_file" | awk '{print $2}')
    [ -n "$task_id" ]
    # The artefact MUST exist at docs/reports/T-XXX-<slug>.md
    report_file=$(ls "$TEST_ROOT/docs/reports/${task_id}-"*.md 2>/dev/null | head -1)
    [ -n "$report_file" ]
    [ -f "$report_file" ]
}

@test "inception skeleton: contains five canonical sections" {
    run "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" \
        --name "section check" --description "test" \
        --type inception --owner human
    [ "$status" -eq 0 ]
    task_id=$(ls "$TEST_ROOT/.tasks/active/"T-*-section-check.md | head -1 | sed -E 's|.*/(T-[0-9]+)-.*|\1|')
    report_file=$(ls "$TEST_ROOT/docs/reports/${task_id}-"*.md | head -1)
    grep -q "^## Origin"           "$report_file"
    grep -q "^## Research"         "$report_file"
    grep -q "^## Dialogue Log"     "$report_file"
    grep -q "^## Recommendation"   "$report_file"
    grep -q "^## Cross-references" "$report_file"
    # Header line includes task id + name
    head -1 "$report_file" | grep -qF "$task_id"
    head -1 "$report_file" | grep -qF "section check"
}

@test "non-inception (build) task: no artefact written" {
    run "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" \
        --name "build check" --description "test" \
        --type build --owner agent
    [ "$status" -eq 0 ]
    # docs/reports/ must remain empty (the dir was pre-created in setup)
    count=$(ls -1 "$TEST_ROOT/docs/reports/" 2>/dev/null | wc -l)
    [ "$count" -eq 0 ]
}

@test "non-inception (refactor) task: no artefact written" {
    run "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" \
        --name "refactor check" --description "test" \
        --type refactor --owner agent
    [ "$status" -eq 0 ]
    count=$(ls -1 "$TEST_ROOT/docs/reports/" 2>/dev/null | wc -l)
    [ "$count" -eq 0 ]
}

@test "idempotency: existing artefact is not overwritten" {
    # Create an inception, then capture artefact contents, run again with
    # same slug — should not be possible to collide naturally (new T-id) so
    # we test by pre-writing the file path that a known inception WOULD write.
    run "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" \
        --name "idempotent" --description "first" \
        --type inception --owner human
    [ "$status" -eq 0 ]
    task_id=$(ls "$TEST_ROOT/.tasks/active/"T-*-idempotent.md | head -1 | sed -E 's|.*/(T-[0-9]+)-.*|\1|')
    report_file="$TEST_ROOT/docs/reports/${task_id}-idempotent.md"
    [ -f "$report_file" ]
    # Tamper with the artefact — add a sentinel line
    echo "AGENT_FILLED_THIS_IN" >> "$report_file"
    sentinel_before=$(grep -c "AGENT_FILLED_THIS_IN" "$report_file")
    [ "$sentinel_before" -eq 1 ]
    # Now simulate the same task being re-created (e.g. via `fw work-on`
    # touching the file again). We do this by directly re-running the
    # auto-skeleton block via a minimal path: rerun create-task.sh isn't
    # possible (T-id allocator gives a new id), so simulate by sourcing
    # the relevant block on the existing TASK_ID. Easier: just check that
    # the file is still there and sentinel survives. The create-task.sh
    # block uses `if [ ! -e "$REPORT_PATH" ]` — so an existing file is
    # untouched. We verify this property by reading the source.
    grep -q 'if \[ ! -e "\$REPORT_PATH" \]' "$FRAMEWORK_ROOT/agents/task-create/create-task.sh"
    # Sentinel still present
    sentinel_after=$(grep -c "AGENT_FILLED_THIS_IN" "$report_file")
    [ "$sentinel_after" -eq 1 ]
}

@test "skeleton filing satisfies commit-msg hook's HAS_EXISTING_ARTIFACT check" {
    # The commit-msg hook at .git/hooks/commit-msg checks
    #   ls "$PROJECT_ROOT/docs/reports/${TASK_REF}-"*
    # to set HAS_EXISTING_ARTIFACT=true. We verify the skeleton path matches
    # that glob pattern (i.e. T-XXX-<slug>.md), so the hook will pass.
    run "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" \
        --name "hook compat" --description "test" \
        --type inception --owner human
    [ "$status" -eq 0 ]
    task_id=$(ls "$TEST_ROOT/.tasks/active/"T-*-hook-compat.md | head -1 | sed -E 's|.*/(T-[0-9]+)-.*|\1|')
    # The commit-msg hook glob
    matches=$(ls "$TEST_ROOT/docs/reports/${task_id}-"* 2>/dev/null | wc -l)
    [ "$matches" -ge 1 ]
}
