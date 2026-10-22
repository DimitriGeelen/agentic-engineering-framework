#!/usr/bin/env bats
# T-4588: unit tests that wrote into the checkout they ran in.
#
# The fast tier, run in a clean clone, left five tracked files changed
# (feedback-stream.yaml, .gate-bypass-log.yaml, .hook-counter,
# .bpmn-promote-audit.jsonl, go-scope-unpropagated/LATEST.md). T-4523's tree
# guard names the paths but not the writer. Each file below was attributed by
# running it alone in a reset clone; each wrote into FRAMEWORK_ROOT because it
# set no temp PROJECT_ROOT for the code under test.
#
# This test re-runs each of those files alone, the way the runner does
# (FRAMEWORK_ROOT and PROJECT_ROOT unset, cwd = the checkout), inside a
# throwaway clone, and asserts the clone's `git status` is unchanged.
# Not covered here: t3062_prepush_runtime.bats, which audits the live repo on
# purpose (live-audit-ok, T-4401) — see T-4588 ## Decisions.

setup_file() {
    SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    CLONE="$BATS_FILE_TMPDIR/clone"
    git clone -q --shared --no-checkout "$SRC" "$CLONE"
    git -C "$CLONE" checkout -q HEAD -- .
    # T4588_TESTS_FROM: where the files under test are copied from (default: this
    # checkout's tests/unit). Point it at the pre-fix copies to watch this go red.
    TESTS_FROM="${T4588_TESTS_FROM:-$SRC/tests/unit}"
    export SRC CLONE TESTS_FROM
}

# The clone's state by content, not by status line: a file an earlier test
# already dirtied stays " M" however much more is appended to it.
_tree_state() {
    git -C "$CLONE" status --porcelain --untracked-files=all
    git -C "$CLONE" diff HEAD --binary | sha256sum
    git -C "$CLONE" ls-files -o --exclude-standard -z \
        | (cd "$CLONE" && xargs -0 -r sha256sum)
}

# Run one test file alone in the clone; fail if it changed the clone's tree.
_runs_clean() {
    local f="$1"
    # The file under test is the working-tree copy, not the committed one.
    cp "$TESTS_FROM/$f" "$CLONE/tests/unit/$f"
    local before after rc=0
    before="$(_tree_state)"
    ( cd "$CLONE" && env -u FRAMEWORK_ROOT -u PROJECT_ROOT -u CLAUDECODE \
        -u TERMLINK_SESSION_ID FW_VERB_TELEMETRY=0 FW_DOCTOR_HOOK_EXERCISE=0 \
        FW_WATCHTOWER_ENSURE=0 bash -c '
            case "$1" in
                *.bats) timeout 280 bats --tap "tests/unit/$1" ;;
                *)      timeout 280 python3 -m pytest -q -p no:cacheprovider "tests/unit/$1" ;;
            esac' _ "$f" ) </dev/null > "$BATS_TEST_TMPDIR/run.out" 2>&1 || rc=$?
    after="$(_tree_state)"
    if [ "$rc" -ne 0 ]; then
        echo "$f itself failed (rc=$rc):"; tail -20 "$BATS_TEST_TMPDIR/run.out"; return 1
    fi
    if [ "$before" != "$after" ]; then
        echo "$f changed the checkout it ran in:"
        diff <(echo "$before") <(echo "$after") || true
        return 1
    fi
}

@test "T-4588: reviewer review-link-homework fixtures stay out of the checkout" {
    _runs_clean test_reviewer_review_link_homework.bats
}

@test "T-4588: reviewer audience-mismatch fixtures stay out of the checkout" {
    _runs_clean test_reviewer_audience_mismatch.bats
}

@test "T-4588: reviewer prose-mismatch fixtures stay out of the checkout" {
    _runs_clean test_reviewer_prose_mismatch.bats
}

@test "T-4588: reviewer human-ac-mechanical-signal fixtures stay out of the checkout" {
    _runs_clean reviewer_human_ac_mechanical_signal.bats
}

@test "T-4588: reviewer defer-as-hedge fixtures stay out of the checkout" {
    _runs_clean test_reviewer_defer_as_hedge.bats
}

@test "T-4588: rail-mcp-label bypass logs to the fixture, not the checkout" {
    _runs_clean rail_mcp_label_guard.bats
}

@test "T-4588: audit-task-tools via fw hook counts in the fixture, not the checkout" {
    _runs_clean audit_task_tools.bats
}

@test "T-4588: bpmn promote write path audits into the fixture, not the checkout" {
    _runs_clean test_bpmn_promote.py
}

@test "T-4588: review-link bypass logs to the fixture, not the checkout" {
    _runs_clean test_review_link_validator.py
}
