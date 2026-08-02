#!/usr/bin/env bats
# T-2738 — the P-011 close gate refuses a pass-marker verdict on an unjudged
# test run.
#
# Origin, measured 2026-08-02 on this host: 61 verification lines across 50 tasks
# capture a pytest/bats run into a variable and then assert a pass marker on the
# capture. The capture discards the runner's exit code, and `set -e` is
# suppressed inside the `if` condition the gate evaluates each line in — so the
# only verdict is the grep. A suite printing "1 failed, 2 passed" satisfies
# `grep -q "2 passed"`, and the task closes GREEN with a red suite.
#
# Same false-green shape as T-2732's port literals, and the same reason it
# accumulated: a red line gets noticed at the next close, a green line that
# asserts less than it appears to looks exactly like one that asserts everything.
#
# The predicate under test is the real one from lib/verification-verdict.sh —
# the same expression the gate runs. Re-typing it here would reproduce L-533.

load ../test_helper

source "$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/lib/verification-verdict.sh"

U="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"

# ── helpers ───────────────────────────────────────────────────────────────────

make_task() {
    local project_dir="$1" verification="$2" task_id="${3:-T-994}"
    local file="$project_dir/.tasks/active/${task_id}-unjudged.md"
    cat > "$file" <<EOF
---
id: ${task_id}
name: "Unjudged test run"
description: "test"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
date_finished: null
---

# ${task_id}: Unjudged test run

## Context

Test.

## Acceptance Criteria

- [x] Test criterion

## Verification

${verification}

## Updates
EOF
    echo "$file"
}

# A pytest suite that genuinely fails: 2 pass, 1 fail. The whole point of this
# file is that the gate is driven by a REALLY failing suite rather than by a
# string that looks like failing output.
make_failing_suite() {
    local project_dir="$1"
    cat > "$project_dir/test_partial.py" <<'EOF'
def test_a(): assert True
def test_b(): assert True
def test_c(): assert False
EOF
}

# ── fixture controls ──────────────────────────────────────────────────────────
#
# T-2732's suite shipped two tests that passed against an EMPTY Verification
# block — vacuous greens inside the suite written to catch vacuous greens.
# Asserted directly so it cannot silently return here.

@test "T-2738 fixture control: the fixture's Verification block is non-empty" {
    PROJECT="$(create_test_project)"
    local f; f="$(make_task "$PROJECT" 'out=$(python3 -m pytest x.py -q 2>&1); echo "$out" | grep -q "2 passed"')"
    run bash -c "source '$FRAMEWORK_ROOT/lib/verification-port.sh'; extract_verification_block '$f'"
    [ -n "$output" ]
    [[ "$output" == *"pytest"* ]]
}

@test "T-2738 fixture control: the fixture suite really fails" {
    # If this suite ever passed, the reachability proof below would be asserting
    # nothing — a green gate on a green suite is correct behaviour.
    PROJECT="$(create_test_project)"
    make_failing_suite "$PROJECT"
    run bash -c "cd '$PROJECT' && python3 -m pytest test_partial.py -q 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"passed"* ]]
    [[ "$output" == *"fail"* ]]
}

# ── the defect is reachable, not hypothetical ─────────────────────────────────

@test "T-2738 REACHABILITY: with the gate bypassed, P-011 passes a RED suite" {
    # This is the pre-fix world, driven through the real gate rather than a
    # local harness: real update-task.sh, real P-011, real pytest, real failure.
    # The bypass env var is what makes the old behaviour still observable — so
    # this test also proves the bypass genuinely disables the new check.
    PROJECT="$(create_test_project)"
    make_failing_suite "$PROJECT"
    make_task "$PROJECT" \
        'out=$(python3 -m pytest test_partial.py -q 2>&1); echo "$out" | grep -q "2 passed"' >/dev/null
    FW_ALLOW_UNJUDGED_TEST_RUN=1 PROJECT_ROOT="$PROJECT" run "$U" T-994 --status work-completed
    # P-011 reports the line as PASS even though one test failed.
    [[ "$output" == *"Verification: 1/1 passed"* ]]
}

@test "T-2738: generalising the count does not help — [0-9]+ passed is green too" {
    # OBS-132 proposed grep -qE "[0-9]+ passed" as the fix for the literal count.
    # It matches "1 failed, 2 passed" just as well. The count was never the
    # defect; the missing failure guard was.
    PROJECT="$(create_test_project)"
    make_failing_suite "$PROJECT"
    make_task "$PROJECT" \
        'out=$(python3 -m pytest test_partial.py -q 2>&1); echo "$out" | grep -qE "[0-9]+ passed"' >/dev/null
    FW_ALLOW_UNJUDGED_TEST_RUN=1 PROJECT_ROOT="$PROJECT" run "$U" T-994 --status work-completed
    [[ "$output" == *"Verification: 1/1 passed"* ]]
}

@test "T-2738 control: the guarded form correctly goes RED on the same suite" {
    # The recommended rewrite must actually catch what the flagged form missed —
    # otherwise the gate would be pushing authors from one green-on-red shape to
    # another. Not bypassed: the guarded form is not an offender, so the gate
    # lets it through to P-011, which then fails it on the failing suite.
    PROJECT="$(create_test_project)"
    make_failing_suite "$PROJECT"
    make_task "$PROJECT" \
        'out=$(python3 -m pytest test_partial.py -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed' >/dev/null
    PROJECT_ROOT="$PROJECT" run "$U" T-994 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" != *"unjudged test run"* ]]   # refused by P-011, not by this gate
    [[ "$output" == *"Verification"* ]]
}

# ── the gate ──────────────────────────────────────────────────────────────────

@test "T-2738: a captured pytest run with a pass-marker verdict blocks completion" {
    # Non-zero alone does NOT establish this. Caught by the negative control:
    # with the predicate neutered this test still passed, because P-011 then
    # runs the line, the fixture path does not exist, pytest errors, the grep
    # finds nothing and the close fails anyway — non-zero for an unrelated
    # reason. The refusal header is what makes the assertion reachable only by
    # the gate actually firing.
    PROJECT="$(create_test_project)"
    make_task "$PROJECT" \
        'out=$(python3 -m pytest tests/unit/foo.py -q 2>&1); echo "$out" | grep -q "9 passed"' >/dev/null
    PROJECT_ROOT="$PROJECT" run "$U" T-994 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"unjudged test run"* ]]
}

@test "T-2738: the refusal is red FOR THE STATED REASON, not merely non-zero" {
    # 832 rail-394: a leg asserting only rc!=0 banks a failure that happened for
    # an unrelated reason. Require the message to name its own condition — and
    # note the fixture path does not exist, so P-011 would fail this line anyway
    # if the gate never fired. The header is what discriminates.
    PROJECT="$(create_test_project)"
    make_task "$PROJECT" \
        'out=$(python3 -m pytest tests/unit/foo.py -q 2>&1); echo "$out" | grep -q "9 passed"' >/dev/null
    PROJECT_ROOT="$PROJECT" run "$U" T-994 --status work-completed
    [[ "$output" == *"unjudged test run"* ]]
    [[ "$output" == *"FW_ALLOW_UNJUDGED_TEST_RUN"* ]]
    [[ "$output" == *"grep -q failed"* ]]
}

@test "T-2738: the offending line itself is quoted back IN THE REFUSAL" {
    PROJECT="$(create_test_project)"
    make_task "$PROJECT" \
        'out=$(python3 -m pytest tests/unit/uniquename.py -q 2>&1); echo "$out" | grep -q "9 passed"' >/dev/null
    PROJECT_ROOT="$PROJECT" run "$U" T-994 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"unjudged test run"* ]]
    [[ "$output" == *"uniquename.py"* ]]
}

@test "T-2738: a captured bats run with an ok-marker verdict blocks completion" {
    PROJECT="$(create_test_project)"
    make_task "$PROJECT" \
        'out=$(bats tests/unit/foo.bats 2>&1); echo "$out" | grep -q "ok 1 "' >/dev/null
    PROJECT_ROOT="$PROJECT" run "$U" T-994 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"unjudged test run"* ]]
}

@test "T-2738: FW_ALLOW_UNJUDGED_TEST_RUN=1 bypasses and logs Tier-2" {
    PROJECT="$(create_test_project)"
    make_task "$PROJECT" \
        'out=$(python3 -m pytest tests/unit/foo.py -q 2>&1 || true); echo "$out" | grep -q "9 passed"' >/dev/null
    FW_ALLOW_UNJUDGED_TEST_RUN=1 PROJECT_ROOT="$PROJECT" run "$U" T-994 --status work-completed
    [[ "$output" != *"unjudged test run"* ]]
    grep -q "FW_ALLOW_UNJUDGED_TEST_RUN" "$PROJECT/.context/working/.gate-bypass-log.yaml"
}

# ── what must NOT be refused ──────────────────────────────────────────────────
#
# 821 corpus lines use the capture idiom soundly. A gate that fires on those is
# an obstacle, and an obstacle gets bypassed reflexively — which would cost more
# than the 61 lines it was built to catch.

@test "T-2738: the sanctioned fw doctor capture-grep idiom is NOT refused" {
    # CLAUDE.md prescribes exactly this shape. fw doctor exits non-zero for
    # unrelated warnings, so the grep IS the assertion here.
    PROJECT="$(create_test_project)"
    make_task "$PROJECT" \
        'out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "Cron registry in sync"' >/dev/null
    PROJECT_ROOT="$PROJECT" run "$U" T-994 --status work-completed
    [[ "$output" != *"unjudged test run"* ]]
}

@test "T-2738: a captured test run WITH a failure guard is NOT refused" {
    PROJECT="$(create_test_project)"
    make_task "$PROJECT" \
        'out=$(bats tests/unit/foo.bats 2>&1); echo "$out" | grep -q "^ok 1 " && ! echo "$out" | grep -q "^not ok"' >/dev/null
    PROJECT_ROOT="$PROJECT" run "$U" T-994 --status work-completed
    [[ "$output" != *"unjudged test run"* ]]
}

@test "T-2738: a pipeline is NOT refused — pipefail already judges it" {
    # Measured: `pytest | grep -qE "[0-9]+ passed"` goes red on a failing suite,
    # because pipefail survives into the if-condition even though set -e does
    # not. Flagging pipelines would be a false positive.
    PROJECT="$(create_test_project)"
    make_task "$PROJECT" \
        'python3 -m pytest tests/unit/foo.py -q 2>&1 | grep -qE "[0-9]+ passed"' >/dev/null
    PROJECT_ROOT="$PROJECT" run "$U" T-994 --status work-completed
    [[ "$output" != *"unjudged test run"* ]]
}

@test "T-2738: an exit-code-preserving && chain is NOT refused" {
    PROJECT="$(create_test_project)"
    make_task "$PROJECT" \
        'python3 -m pytest tests/unit/foo.py -q > /tmp/.t2738.out 2>&1 && grep -q "9 passed" /tmp/.t2738.out' >/dev/null
    PROJECT_ROOT="$PROJECT" run "$U" T-994 --status work-completed
    [[ "$output" != *"unjudged test run"* ]]
}

@test "T-2738: a .bats FILENAME in a non-runner command is not mistaken for the runner" {
    # A bare \bbats\b word boundary matches `tests/unit/foo.bats`. The predicate
    # requires bats in COMMAND position; this pins that, and it is the case that
    # exposed the bug when the pattern was first written.
    PROJECT="$(create_test_project)"
    make_task "$PROJECT" \
        'out=$(cat tests/unit/foo.bats); echo "$out" | grep -q "passed"' >/dev/null
    PROJECT_ROOT="$PROJECT" run "$U" T-994 --status work-completed
    [[ "$output" != *"unjudged test run"* ]]
}

# ── single definition (L-533) ─────────────────────────────────────────────────

@test "T-2738: the gate sources the predicate rather than re-typing it" {
    # T-1842 centralised a fabric predicate and left two audit copies behind for
    # months (T-2735). The guard is that the gate's call site references the
    # shared unit — asserted on the call site, not on a mention anywhere in the
    # file, since an explanatory comment naming the file would satisfy that.
    run grep -A4 'check_verification_unjudged_test_runs() {' "$U"
    [ "$status" -eq 0 ]
    run bash -c "grep -n 'source .*lib/verification-verdict.sh' '$U'"
    [ "$status" -eq 0 ]
    # and no second copy of the expression anywhere outside the lib
    run bash -c "grep -rln 'A-Za-z0-9_\]\*=\\\$(' '$FRAMEWORK_ROOT/agents' '$FRAMEWORK_ROOT/lib' 2>/dev/null | grep -v 'verification-verdict.sh' | wc -l"
    [ "$output" = "0" ]
}
