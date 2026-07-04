#!/usr/bin/env bats
# D5 task-lifecycle anomaly check (agents/audit/audit.sh embedded python).
# Origin: T-100122 — 22 of 29 "anomalies" were partial-complete tasks (T-193):
# human-owned, all Agent ACs ticked, Human ACs pending — i.e. the review
# backlog, already surfaced on /approvals. D5 now excludes that state from
# the stale-active leg.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
AUDIT_SH="$FRAMEWORK_ROOT/agents/audit/audit.sh"

setup() {
    TEST_DIR="$BATS_TMPDIR/fw_d5_test_$$"
    mkdir -p "$TEST_DIR/.tasks/active" "$TEST_DIR/.tasks/completed"
    export PROJECT_ROOT="$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}

make_task() {  # $1=id $2=owner $3=agent_ac_block $4=human_ac_block
    cat > "$TEST_DIR/.tasks/active/${1}-fixture.md" <<TASKEOF
---
id: ${1}
name: "fixture ${1}"
status: started-work
workflow_type: build
owner: ${2}
created: 2026-01-01T00:00:00Z
---

## Acceptance Criteria

### Agent
${3}

### Human
${4}
TASKEOF
}

run_d5() {
    python3 - "$AUDIT_SH" <<'PYEOF'
import re, sys
src = open(sys.argv[1]).read()
m = re.search(r"d5_result=\$\(python3 << 'D5EOF'\n(.*?)\nD5EOF", src, re.S)
if not m:
    print("SKIP d5_block_not_found"); sys.exit(1)
exec(compile(m.group(1), "d5", "exec"))
PYEOF
}

@test "T-100122: stale partial-complete (human, agent ACs ticked, human AC pending) is NOT an anomaly" {
    make_task T-9001 human "- [x] built it
- [x] tested it" "- [ ] [REVIEW] looks right"
    run run_d5
    [ "$status" -eq 0 ]
    [[ "$output" != *"T-9001"* ]]
}

@test "stale agent-owned started-work task IS an anomaly" {
    make_task T-9002 agent "- [x] built it" "- [ ] [REVIEW] looks right"
    run run_d5
    [ "$status" -eq 0 ]
    [[ "$output" == WARN* ]]
    [[ "$output" == *"T-9002"* ]]
}

@test "stale human-owned task with UNTICKED agent ACs IS an anomaly (not partial-complete)" {
    make_task T-9003 human "- [x] built it
- [ ] tested it" "- [ ] [REVIEW] looks right"
    run run_d5
    [ "$status" -eq 0 ]
    [[ "$output" == WARN* ]]
    [[ "$output" == *"T-9003"* ]]
}

@test "captured tasks age silently (no anomaly regardless of age)" {
    make_task T-9004 agent "- [ ] someday" "- [ ] [REVIEW] someday"
    sed -i 's/^status: started-work/status: captured/' "$TEST_DIR/.tasks/active/T-9004-fixture.md"
    run run_d5
    [ "$status" -eq 0 ]
    [[ "$output" != *"T-9004"* ]]
}
