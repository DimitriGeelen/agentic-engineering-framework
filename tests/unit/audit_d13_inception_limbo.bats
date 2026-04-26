#!/usr/bin/env bats
# T-1490 / OBS-025: D13 detects two inception-limbo classes:
#   A) status=work-completed + Decision recorded + Human AC unchecked
#   B) status=started-work  + Decision recorded + all Human ACs ticked
# D5 (lifecycle anomaly) catches stuck tasks by AGE only — D13 catches
# them by combination signature regardless of age.
#
# Strategy: extract the D13 python block from audit.sh and run it
# standalone with PROJECT_ROOT pointing to a temp fixture. Running the
# full audit.sh 6 times is too slow (>3 min total).

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"

setup() {
    TMPREPO=$(mktemp -d)
    cd "$TMPREPO"
    mkdir -p .tasks/active .tasks/completed
    # Extract the D13 python block as a standalone script
    awk '/^d13_result=\$\(python3 << .D13EOF/,/^D13EOF$/' "$AUDIT" \
        | sed -n '2,/^D13EOF$/p' \
        | sed '/^D13EOF$/d' > "$TMPREPO/d13.py"
    [ -s "$TMPREPO/d13.py" ] || { echo "FAILED to extract D13 python block"; exit 1; }
}

teardown() {
    cd /
    rm -rf "$TMPREPO"
}

# Synthesize an inception task. Args: task_id, status, has_decision (1/0),
#   human_unchecked_count (0 or 1), filename
_make_inception() {
    local tid="$1" status="$2" has_dec="$3" hu_unchecked="$4" fname="$5"
    local hu_marker="[x]"
    [ "$hu_unchecked" = "1" ] && hu_marker="[ ]"
    local dec_block=""
    if [ "$has_dec" = "1" ]; then
        dec_block=$'\n## Decision\n\n**Decision**: GO\n\n**Rationale**: synthesized\n'
    fi
    cat > ".tasks/active/${fname}" << EOF
---
id: ${tid}
name: "synthesized ${tid}"
description: synthesized
status: ${status}
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-20T00:00:00Z
last_update: 2026-04-20T00:00:00Z
date_finished: null
---

# ${tid}: synthesized

## Acceptance Criteria

### Agent
- [x] Synthesized agent AC

### Human
- ${hu_marker} [REVIEW] Synthesized human AC
${dec_block}
EOF
}

_run_d13() {
    PROJECT_ROOT="$TMPREPO" python3 "$TMPREPO/d13.py"
}

@test "D13 reports PASS 0 when no limbo inceptions exist" {
    _make_inception T-9001 work-completed 0 0 T-9001-clean.md
    run _run_d13
    [ "$status" -eq 0 ]
    [ "$output" = "PASS 0" ]
}

@test "D13 detects Class A (work-completed + Human AC unchecked)" {
    _make_inception T-9101 work-completed 1 1 T-9101-classA.md
    run _run_d13
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN 1 A=1/B=0 T-9101(A:1hu)"* ]]
}

@test "D13 detects Class B (started-work + decision + all ACs ticked)" {
    _make_inception T-9201 started-work 1 0 T-9201-classB.md
    run _run_d13
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN 1 A=0/B=1 T-9201(B)"* ]]
}

@test "D13 mixed A+B reports both with combined count" {
    _make_inception T-9301 work-completed 1 1 T-9301-classA.md
    _make_inception T-9302 started-work 1 0 T-9302-classB.md
    run _run_d13
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN 2 A=1/B=1"* ]]
    [[ "$output" == *"T-9301(A:1hu)"* ]]
    [[ "$output" == *"T-9302(B)"* ]]
}

@test "D13 ignores started-work inception with no decision recorded" {
    _make_inception T-9401 started-work 0 0 T-9401-no-decision.md
    run _run_d13
    [ "$output" = "PASS 0" ]
}

@test "D13 ignores work-completed inception with all ACs ticked (genuinely complete)" {
    _make_inception T-9501 work-completed 1 0 T-9501-clean-completed.md
    run _run_d13
    [ "$output" = "PASS 0" ]
}

@test "D13 caps display at 8 items with overflow suffix" {
    for i in 1 2 3 4 5 6 7 8 9 10; do
        _make_inception "T-95${i}0" work-completed 1 1 "T-95${i}0-classA.md"
    done
    run _run_d13
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN 10 A=10/B=0"* ]]
    [[ "$output" == *"(+2 more)"* ]]
}
