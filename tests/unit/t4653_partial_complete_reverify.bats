#!/usr/bin/env bats
# T-4653 — finalizing a partial-complete task must re-run ## Verification (P-011).
#
# A partial-complete task is work-completed but still in active/ because Human ACs
# were open. When the last one is ticked and `--status work-completed` is re-run,
# update-task.sh takes the OLD_STATUS == NEW_STATUS branch, which used to `git mv`
# the file to completed/ on the AC count alone — a Verification line that had gone
# red since the first transition never ran.
#
# Observable: where the task file ends up, plus the gate's own output. The fixture
# is a bare directory, so the script may exit non-zero for unrelated downstream
# reasons after archiving; rc is only asserted on the refusal path.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
}

teardown() {
    if [ -n "${P:-}" ]; then rm -rf "$P"; fi
    return 0
}

# $1 = marker path the Verification line checks (exists or not decides red/green)
_make_project() {
    P="$(mktemp -d)"
    mkdir -p "$P/.tasks/active" "$P/.tasks/completed" "$P/.context/working"
    touch "$P/marker"
    { printf -- '---\nid: T-9999\nname: "fixture"\nstatus: work-completed\n'
      printf 'workflow_type: build\nowner: human\nhorizon: now\n'
      printf 'created: 2026-08-31T00:00:00Z\nlast_update: 2026-08-31T00:00:00Z\n---\n\n'
      printf '# T-9999: fixture\n\n## Context\n\nx\n\n## Acceptance Criteria\n\n'
      printf '### Agent\n- [x] done\n\n### Human\n- [x] [REVIEW] ticked by operator\n\n'
      printf '## Verification\n\ntest -f %s/marker\n\n## Decisions\n\n' "$P"; } \
        > "$P/.tasks/active/T-9999-fixture.md"
}

_finalize() {
    PROJECT_ROOT="$P" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        timeout 120 bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" \
        T-9999 --status work-completed "$@" 2>&1
}

@test "control: green Verification finalizes and archives" {
    _make_project
    run _finalize
    echo "$output" | grep -q "Verification: 1/1 passed"
    [ -f "$P/.tasks/completed/T-9999-fixture.md" ]
}

@test "red Verification at finalization refuses and keeps the task in active/" {
    _make_project
    rm "$P/marker"
    run _finalize
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "verification(s) failed"
    [ -f "$P/.tasks/active/T-9999-fixture.md" ]
    if [ -f "$P/.tasks/completed/T-9999-fixture.md" ]; then false; fi
}

@test "red Verification with operator --skip-verification archives and logs the bypass" {
    _make_project
    rm "$P/marker"
    run _finalize --skip-verification --reason "T-4653 test" --i-am-human
    echo "$output" | grep -q "skip-verification bypass"
    [ -f "$P/.tasks/completed/T-9999-fixture.md" ]
}

# T-4681: an empty ## Verification at finalization must not hit the T-4024
# authoring refusal — that gate applies at the first close, not when the operator
# ticks the last Human AC. 21 of 333 partial-completes were un-archivable.
@test "T-4681: empty Verification at finalization archives with a note, not the T-4024 refusal" {
    _make_project
    sed -i "s|^test -f $P/marker\$|# only a comment|" "$P/.tasks/active/T-9999-fixture.md"
    ! grep -q "^test -f" "$P/.tasks/active/T-9999-fixture.md" || false
    run _finalize
    ! echo "$output" | grep -q "BLOCKED: ## Verification yields 0 commands" || false
    echo "$output" | grep -q "Finalization: empty block not refused"
    [ -f "$P/.tasks/completed/T-9999-fixture.md" ]
}
