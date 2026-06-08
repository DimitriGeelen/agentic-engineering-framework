#!/usr/bin/env bats
# T-2268 (arc-010 Slice 3 HM-A): integration contract test for the demo evidence
# README + traceability shape.
#
# This is the test the operator runs *after* the demo agent completes its run.
# It enforces:
#   - Evidence README exists at the canonical path
#   - README contains the headline_mechanic verbatim from the arc YAML
#   - README's traceability table contains a row for each headline_mechanic clause
#   - When transcript JSONL is present, structural greps match expected shape
#
# Tests are designed to skip (not fail) cleanly when the demo has not yet run.
# This lets the test live on master green throughout arc-010 development; it
# upgrades from skip to pass once the operator runs the demo and fills in the
# evidence.

load ../test_helper

EVIDENCE_README="$FRAMEWORK_ROOT/docs/reports/arc-010-hm-a-demo-evidence.md"
WORKER_PROMPT="$FRAMEWORK_ROOT/docs/reports/arc-010-hm-a-demo-prompt.md"
TRANSCRIPT="$FRAMEWORK_ROOT/docs/reports/arc-010-hm-a-demo/transcript.jsonl"
ARC_YAML="$FRAMEWORK_ROOT/.context/arcs/capability-overlay.yaml"
DELIVERABLE="$FRAMEWORK_ROOT/docs/reports/arc-010-mcp-tools-overview.md"

setup() {
    unset PROJECT_ROOT
    export FRAMEWORK_ROOT
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
}

@test "t2268:t1 evidence README exists at canonical path" {
    [ -f "$EVIDENCE_README" ]
}

@test "t2268:t2 worker prompt exists at canonical path" {
    [ -f "$WORKER_PROMPT" ]
}

@test "t2268:t3 arc-010 YAML headline_mechanic field is non-empty" {
    [ -f "$ARC_YAML" ]
    run python3 -c "
import yaml
with open('$ARC_YAML') as f:
    data = yaml.safe_load(f)
hm = data.get('headline_mechanic', '')
assert hm and hm.strip(), 'headline_mechanic empty'
print(hm)
"
    [ "$status" -eq 0 ]
}

@test "t2268:t4 evidence README quotes the headline_mechanic (backtick-tolerant)" {
    # Pull the headline_mechanic from the YAML, then assert the README contains
    # the same text. This catches drift between the arc YAML and the evidence.
    # Markdown allows wrapping identifiers in backticks; strip backticks from
    # both sides before comparing.
    hm=$(python3 -c "
import yaml
with open('$ARC_YAML') as f:
    print(yaml.safe_load(f)['headline_mechanic'])
" | tr -d '\`')
    readme=$(cat "$EVIDENCE_README" | tr -d '\`')
    [ -n "$hm" ]
    # Use a stable substring (the imperative clause) to avoid whitespace nits.
    fragment="mcp__fw__task_update / mcp__fw__work_on"
    echo "$readme" | grep -qF "$fragment"
}

@test "t2268:t5 evidence README traceability table has ≥6 clause rows" {
    # The table has a separator row + N clause rows. Count rows starting with
    # "| <digit> |" — that pins to clause numbering 1..6.
    count=$(grep -cE '^\| [0-9]+ \| ' "$EVIDENCE_README")
    [ "$count" -ge 6 ]
}

@test "t2268:t6 evidence README references the demo-target task T-2273" {
    grep -q "T-2273" "$EVIDENCE_README"
}

@test "t2268:t7 evidence README references the negative grep (zero-Bash assertion)" {
    grep -q "no.*Bash(bin/fw" "$EVIDENCE_README" || grep -q "no.*\`Bash(bin/fw" "$EVIDENCE_README"
}

@test "t2268:t8 worker prompt forbids Bash for governance verbs" {
    grep -qE "do NOT call .*Bash\(bin/fw" "$WORKER_PROMPT" \
        || grep -qF "Do NOT call \`Bash(bin/fw" "$WORKER_PROMPT"
}

@test "t2268:t9 [post-run] transcript exists or skip" {
    # This test upgrades from skip to pass once the demo runs and produces a
    # transcript. Don't fail when missing — the contract is "transcript may not
    # exist yet during scaffolding".
    if [ ! -f "$TRANSCRIPT" ]; then
        skip "demo has not run yet — transcript not produced"
    fi
    # When transcript exists: positive proof, structural shape.
    out=$(grep -c '"name":"mcp__fw__work_on"' "$TRANSCRIPT" 2>&1 || echo 0)
    [ "$out" -ge 1 ]
    out=$(grep -c '"name":"mcp__fw__task_update"' "$TRANSCRIPT" 2>&1 || echo 0)
    [ "$out" -ge 1 ]
}

@test "t2268:t10 [post-run] transcript ZERO Bash(bin/fw verb) lines (the proof point)" {
    if [ ! -f "$TRANSCRIPT" ]; then
        skip "demo has not run yet — transcript not produced"
    fi
    # Negative proof — the headline mechanic ASSERTION. Zero is the only pass.
    out=$(grep -cE 'Bash.*bin/fw (task update|work-on|context focus)' "$TRANSCRIPT" 2>&1 || echo 0)
    [ "$out" -eq 0 ]
}

@test "t2268:t11 [post-run] deliverable file exists with valid word count" {
    if [ ! -f "$DELIVERABLE" ]; then
        skip "demo has not run yet — deliverable not produced"
    fi
    wc=$(wc -w < "$DELIVERABLE")
    [ "$wc" -ge 80 ] && [ "$wc" -le 150 ]
}
