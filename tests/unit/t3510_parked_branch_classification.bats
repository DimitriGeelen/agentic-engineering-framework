#!/usr/bin/env bats
# T-3510 (OBS-547): a branch is unlanded for two very different reasons, and the
# scan could not tell them apart.
#
# Parking lives in the TASK — `status: captured`, `horizon: later` — and nowhere
# in the branch. On 2026-09-26 this scan reported a parked branch as landable,
# the audit's mitigation line recommended `fw integrate run`, and a batch-merge
# worker did exactly that, taking the `fw arc close` sovereignty gate off by
# default. No rule was broken: the rail could not express the distinction.
#
# The trap this suite is built against: a "parked" check that suppresses findings
# rather than substituting them would make the scan quieter and look like a pass.
# So every firing assertion below is paired with a CONTROL over the same fixture
# where the only change is the task's state — and the last test pins the total
# finding count, because the failure mode of this feature is silence.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    REPO="$TEST_TEMP_DIR/repo"
    mkdir -p "$REPO/.tasks/active" "$REPO/.tasks/completed"
    git -C "$REPO" init -q -b master
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    echo base > "$REPO/f"
    git -C "$REPO" add f
    git -C "$REPO" commit -qm base

    # master runs far ahead so any feature branch is past the behind-threshold.
    local i
    for i in $(seq 1 60); do
        echo "c$i" >> "$REPO/f"
        git -C "$REPO" commit -qam "c$i"
    done

    LIB="$FRAMEWORK_ROOT/lib/branch-hygiene.sh"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_hygiene() {
    bash -c "source '$LIB'; fw_branch_hygiene '$REPO'" 2>/dev/null
}

# Write a task file. $1=id $2=status $3=horizon [$4=extra body prose]
_task() {
    cat > "$REPO/.tasks/active/$1-fixture.md" <<EOF
---
id: $1
name: "fixture"
status: $2
workflow_type: build
owner: agent
horizon: $3
---

# $1

${4:-}
EOF
}

# An unlanded branch, old enough to pass the staleness gate, 1 commit ahead.
_unlanded_branch() {
    git -C "$REPO" checkout -q -b "$1" master~55
    echo x > "$REPO/$1"
    git -C "$REPO" add "$1"
    GIT_COMMITTER_DATE="2026-01-01T00:00:00Z" GIT_AUTHOR_DATE="2026-01-01T00:00:00Z" \
        git -C "$REPO" commit -qm "work on $1"
    git -C "$REPO" checkout -q master
}

# ── unlanded + parked ────────────────────────────────────────────────────────

@test "parked governing task: unlanded branch reports unlanded-by-design" {
    _task T-3487 captured later
    _unlanded_branch t3487-remove-gate
    run _hygiene
    [[ "$output" =~ "unlanded-by-design t3487-remove-gate task=T-3487" ]]
    [[ ! "$output" =~ "behind-threshold t3487-remove-gate" ]]
}

@test "CONTROL: same branch, LIVE task, still reports behind-threshold" {
    # Only the task's state differs from the test above. If this also came back
    # unlanded-by-design, that test would be proving nothing about parking.
    _task T-3487 work-completed now
    _unlanded_branch t3487-remove-gate
    run _hygiene
    [[ "$output" =~ "behind-threshold t3487-remove-gate" ]]
    [[ ! "$output" =~ "unlanded-by-design" ]]
}

@test "horizon later alone is parked, even when status is started-work" {
    _task T-2353 started-work later
    _unlanded_branch t2353-audit-emit
    run _hygiene
    [[ "$output" =~ "unlanded-by-design t2353-audit-emit task=T-2353" ]]
}

@test "the finding says NO merge is owed, not merely that the branch is old" {
    # L-642: reporting staleness is not reporting consequence.
    _task T-3487 captured later
    _unlanded_branch t3487-remove-gate
    run _hygiene
    [[ "$output" =~ "NO merge is owed" ]]
}

# ── merged + parked: the incident's own signature ────────────────────────────

@test "parked task whose branch is ALREADY merged reports parked-but-landed" {
    _task T-3487 captured later
    _unlanded_branch t3487-remove-gate
    git -C "$REPO" merge -q --no-ff -m "merge" t3487-remove-gate
    run _hygiene
    [[ "$output" =~ "parked-but-landed t3487-remove-gate task=T-3487" ]]
    [[ ! "$output" =~ "merged-undeleted t3487-remove-gate" ]]
}

@test "CONTROL: merged branch of a LIVE task stays merged-undeleted" {
    _task T-3487 work-completed now
    _unlanded_branch t3487-remove-gate
    git -C "$REPO" merge -q --no-ff -m "merge" t3487-remove-gate
    run _hygiene
    [[ "$output" =~ "merged-undeleted t3487-remove-gate" ]]
    [[ ! "$output" =~ "parked-but-landed" ]]
}

@test "parked-but-landed says the task record and the tree DISAGREE" {
    _task T-3487 captured later
    _unlanded_branch t3487-remove-gate
    git -C "$REPO" merge -q --no-ff -m "merge" t3487-remove-gate
    run _hygiene
    [[ "$output" =~ "disagree" ]]
}

# ── the branches this must NOT touch ────────────────────────────────────────

@test "a branch name carrying NO task id is classified exactly as before" {
    # dispatch-f25 and dispatch-f21-f24 were in the same batch merge and carry no
    # task id. A helper defaulting to "not parked" would read as coverage it does
    # not have; one defaulting to "parked" would silence real strands.
    _unlanded_branch dispatch-f25
    run _hygiene
    [[ "$output" =~ "behind-threshold dispatch-f25" ]]
    [[ ! "$output" =~ "unlanded-by-design" ]]
}

@test "a task id with no task FILE is classified exactly as before" {
    _unlanded_branch t9999-no-such-task
    run _hygiene
    [[ "$output" =~ "behind-threshold t9999-no-such-task" ]]
    [[ ! "$output" =~ "unlanded-by-design" ]]
}

@test "a branch starting with t but no digits is not mistaken for a task" {
    _unlanded_branch test-harness-work
    run _hygiene
    [[ "$output" =~ "behind-threshold test-harness-work" ]]
    [[ ! "$output" =~ "task=" ]]
}

@test "body prose saying 'status: captured' does NOT park a live task" {
    # Mention-vs-instance (L-583). The helper reads frontmatter only; a task that
    # DISCUSSES parking is not parked.
    _task T-3487 work-completed now "This task explains why status: captured and horizon: later mean parked."
    _unlanded_branch t3487-remove-gate
    run _hygiene
    [[ "$output" =~ "behind-threshold t3487-remove-gate" ]]
    [[ ! "$output" =~ "unlanded-by-design" ]]
}

# ── the audit's MITIGATION line: the sentence that was acted on ─────────────
#
# The finding wording is only half the defect. What the 2026-09-26 batch worker
# actually followed was the audit's mitigation line — "fw integrate run
# bleeding-edge (overdue merge-back)" — so asserting the finding without
# asserting the instruction would leave the acted-on half unpinned.
#
# Uses the T-3095 extraction harness, which evaluates the real block out of
# agents/audit/audit.sh against stub pass/warn/info/fail. A copy of the logic
# here would pass forever after audit.sh changed.

_audit_block() {
    run "$FRAMEWORK_ROOT/tests/helpers/audit-branch-hygiene-block.sh" "$FRAMEWORK_ROOT" "$1"
}

@test "every finding parked: mitigation does NOT recommend fw integrate run" {
    _task T-3487 captured later
    _unlanded_branch t3487-remove-gate
    _audit_block "$REPO"
    [[ "$output" =~ "MITIGATION|No landing is owed" ]]
    # The exact instruction the incident followed must be absent.
    [[ ! "$output" =~ "fw integrate run" ]]
}

@test "CONTROL: an unparked finding still gets the fw integrate recommendation" {
    # Without this leg, the test above could be passing because the mitigation
    # line went missing entirely rather than because it changed correctly.
    _task T-3487 work-completed now
    _unlanded_branch t3487-remove-gate
    _audit_block "$REPO"
    [[ "$output" =~ "fw integrate run" ]]
    [[ ! "$output" =~ "No landing is owed" ]]
}

@test "mixed batch: recommendation stays, with the parked branches excluded" {
    _task T-3487 captured later
    _unlanded_branch t3487-remove-gate
    _task T-2416 work-completed now
    _unlanded_branch t2416-safe-mode
    _audit_block "$REPO"
    [[ "$output" =~ "fw integrate run" ]]
    [[ "$output" =~ "EXCLUDE those branches" ]]
}

@test "mitigation never raises the audit's exit code" {
    # This rail is WARN-only. A parked branch must not start failing the audit.
    _task T-3487 captured later
    _unlanded_branch t3487-remove-gate
    _audit_block "$REPO"
    [[ "$output" =~ "fail=0" ]]
}

# ── the property that guards the whole feature ──────────────────────────────

@test "reclassification never SILENCES: finding count is identical either way" {
    # The failure mode of a "don't recommend this" feature is a quieter scan that
    # reads as a tidier repo. Parked and live must produce the same NUMBER of
    # findings over the same topology — only the wording may differ.
    _task T-3487 captured later
    _unlanded_branch t3487-remove-gate
    run _hygiene
    local parked_n
    parked_n=$(printf '%s\n' "$output" | grep -c .)

    _task T-3487 work-completed now
    run _hygiene
    local live_n
    live_n=$(printf '%s\n' "$output" | grep -c .)

    [ "$parked_n" -eq "$live_n" ]
    [ "$parked_n" -gt 0 ]
}
