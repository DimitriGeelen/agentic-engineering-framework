#!/usr/bin/env bats
# T-2732 — the P-011 close gate refuses a hard-coded Watchtower port.
#
# Origin, measured 2026-08-02 on this host: 371 verification lines across 277
# tasks fetch a literal port-3000 URL. Port 3000 belonged to ANOTHER PROJECT's
# Watchtower (832's, /opt/832-Workflow-designer/.agentic-framework); AEF resolved
# to :3001. Both projects run the same Flask app, so 224 of those lines — the
# ones asserting only reachability — returned 200 from the wrong server. Task IDs
# collide at low numbers, so even `/tasks/T-152` answered 200 there.
#
# The failure mode is a FALSE GREEN. A red line gets noticed the next time anyone
# closes the task; a green line that asserts nothing looks exactly like a green
# line that asserts everything. That is why it reached 371 rather than 3.
#
# The predicate under test is the real one from lib/verification-port.sh — the
# same expression the gate runs. Re-typing it here would reproduce L-533.

load ../test_helper

source "$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/lib/verification-port.sh"

U="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"

# ── helpers ───────────────────────────────────────────────────────────────────

make_task() {
    local project_dir="$1" verification="$2" task_id="${3:-T-995}"
    local file="$project_dir/.tasks/active/${task_id}-port.md"
    cat > "$file" <<EOF
---
id: ${task_id}
name: "Port literal test"
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

# ${task_id}: Port literal test

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

# A trailing section after ## Verification is NOT cosmetic. The extractor is
# `sed -n '/^## Verification/,/^## /p' | sed '\$d'`, which without a following
# heading runs to EOF and then deletes the last line — i.e. the only command.
# The first draft of this file omitted it, and the two "not refused" tests passed
# against an EMPTY block: vacuous greens inside the suite written to catch
# vacuous greens. Asserted directly below so it cannot silently return.
@test "T-2732 fixture control: the fixture's Verification block is non-empty" {
    PROJECT="$(create_test_project)"
    local f; f="$(make_task "$PROJECT" 'curl -sf http://localhost:3000/costs -o /dev/null')"
    run bash -c "source '$FRAMEWORK_ROOT/lib/verification-port.sh'; extract_verification_block '$f'"
    [ -n "$output" ]
    [[ "$output" == *"curl"* ]]
}

# ── the gate ──────────────────────────────────────────────────────────────────

@test "T-2732: a bare port-3000 URL blocks work-completed" {
    PROJECT="$(create_test_project)"
    make_task "$PROJECT" 'curl -sf http://localhost:3000/costs -o /dev/null' >/dev/null
    PROJECT_ROOT="$PROJECT" run "$U" T-995 --status work-completed
    [ "$status" -ne 0 ]
}

@test "T-2732: the refusal is red FOR THE STATED REASON, not merely non-zero" {
    # 832 rail-394: a leg asserting only rc!=0 banks a failure that happened for
    # an unrelated reason (their teeth leg died at module load on a syntax error
    # and looked like a pass). Require the message to name its own condition.
    PROJECT="$(create_test_project)"
    make_task "$PROJECT" 'curl -sf http://localhost:3000/costs -o /dev/null' >/dev/null
    PROJECT_ROOT="$PROJECT" run "$U" T-995 --status work-completed
    [[ "$output" == *"hard-coded Watchtower port"* ]]
    [[ "$output" == *"fw watchtower url"* ]]
    [[ "$output" == *"FW_ALLOW_HARDCODED_PORT"* ]]
}

@test "T-2732: the offending line itself is quoted back IN THE REFUSAL" {
    # The path alone is not evidence: with the gate disabled P-011 proceeds to
    # run the command and echoes it as `PASS: <cmd>`, so the path appears in
    # output either way. Caught by the negative control — this test passed with
    # the predicate neutered. Require the refusal header and a non-zero exit
    # alongside it, so the assertion can only be satisfied by the gate firing.
    PROJECT="$(create_test_project)"
    make_task "$PROJECT" 'curl -sf http://localhost:3000/some/unique/path -o /dev/null' >/dev/null
    PROJECT_ROOT="$PROJECT" run "$U" T-995 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"hard-coded Watchtower port"* ]]
    [[ "$output" == *"/some/unique/path"* ]]
}

@test "T-2732: the sanctioned defensive fallback is NOT refused" {
    # CLAUDE.md explicitly allows falling back to 3000 after asking where the
    # port is. If this test goes red the gate has become an obstacle rather
    # than a guard.
    PROJECT="$(create_test_project)"
    make_task "$PROJECT" \
        'WT_URL=$(bin/fw watchtower url 2>/dev/null || echo "http://localhost:3000"); echo "$WT_URL" >/dev/null' >/dev/null
    PROJECT_ROOT="$PROJECT" run "$U" T-995 --status work-completed
    [[ "$output" != *"hard-coded Watchtower port"* ]]
}

@test "T-2732: a non-Watchtower local port is not flagged" {
    # litellm on :4000, termlink hub on :9100 — the gate is scoped to the
    # documented Watchtower default, not to local URLs in general.
    PROJECT="$(create_test_project)"
    make_task "$PROJECT" 'echo http://localhost:4000/health >/dev/null' >/dev/null
    PROJECT_ROOT="$PROJECT" run "$U" T-995 --status work-completed
    [[ "$output" != *"hard-coded Watchtower port"* ]]
}

@test "T-2732: FW_ALLOW_HARDCODED_PORT=1 bypasses and logs Tier-2" {
    PROJECT="$(create_test_project)"
    make_task "$PROJECT" 'curl -sf http://localhost:3000/costs -o /dev/null || true' >/dev/null
    FW_ALLOW_HARDCODED_PORT=1 PROJECT_ROOT="$PROJECT" run "$U" T-995 --status work-completed
    [[ "$output" != *"hard-coded Watchtower port"* ]]
    grep -q "FW_ALLOW_HARDCODED_PORT" "$PROJECT/.context/working/.gate-bypass-log.yaml"
}

# ── the predicate, over the real corpus ───────────────────────────────────────

@test "T-2732: no active task carries a bare port literal, no exclusions" {
    local offenders=""
    for f in "$FRAMEWORK_ROOT"/.tasks/active/T-*.md; do
        [ -e "$f" ] || continue
        local block hits
        block="$(extract_verification_block "$f")"
        [ -z "$block" ] && continue
        hits="$(find_port_literals "$block")"
        [ -n "$hits" ] && offenders+="$(basename "$f"): $hits"$'\n'
    done
    [ -z "$offenders" ] || {
        echo "active tasks with hard-coded Watchtower port:" >&2
        echo "$offenders" >&2
        false
    }
}

@test "T-2732 guard control: the corpus scan catches a violation appended to a COPY" {
    # The scan above can only be trusted if it can fail. Take a real active task,
    # append the defect to a copy, and require the same predicate to catch it.
    local src copy
    src="$(ls "$FRAMEWORK_ROOT"/.tasks/active/T-*.md | head -1)"
    copy="$TEST_TEMP_DIR/regressed.md"
    # Insert INTO the existing block. Appending a second `## Verification` at EOF
    # does nothing: the extractor takes the first match, so the copy would scan
    # clean and the control would pass without ever exercising the predicate.
    awk '{print} /^## Verification/ && !done {print ""; print "curl -sf http://localhost:3000/costs -o /dev/null"; done=1}' \
        "$src" > "$copy"
    run bash -c "
        source '$FRAMEWORK_ROOT/lib/verification-port.sh'
        find_port_literals \"\$(extract_verification_block '$copy')\"
    "
    [ -n "$output" ]
}

@test "T-2732 guard control: the sanctioned form survives the same scan" {
    # Pairs with the control above — proves the scan discriminates rather than
    # flagging everything that contains the digits 3000.
    local copy="$TEST_TEMP_DIR/sanctioned.md"
    printf -- '---\nid: T-994\n---\n\n## Verification\n\nWT_URL=$(bin/fw watchtower url 2>/dev/null || echo "http://localhost:3000"); echo "$WT_URL"\n\n## Updates\n' > "$copy"
    run bash -c "
        source '$FRAMEWORK_ROOT/lib/verification-port.sh'
        find_port_literals \"\$(extract_verification_block '$copy')\"
    "
    [ -z "$output" ]
}
