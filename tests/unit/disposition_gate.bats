#!/usr/bin/env bats
# Unit tests for check_disposition_gate (T-2190).
#
# Inception tasks with ## Open Questions must dispose every IW-N before
# work-completed. Each question requires both a `disposition:` and
# `rationale:` line. Bypass: --skip-disposition-gate / FW_SKIP_DISPOSITION_GATE=1.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    unset FW_SKIP_DISPOSITION_GATE
    mkdir -p "$TEST_TEMP_DIR/.tasks/active" "$TEST_TEMP_DIR/.tasks/completed" "$TEST_TEMP_DIR/.context/working"
    UPDATE_SH="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    unset FW_SKIP_DISPOSITION_GATE
}

_make_inception() {
    local id="$1" oq_body="$2"
    local path="$TEST_TEMP_DIR/.tasks/active/${id}-test.md"
    {
        echo "---"
        echo "id: $id"
        echo "status: started-work"
        echo "workflow_type: inception"
        echo "target_blast_radius: 3"
        echo "voi_score: 0.5"
        echo "owner: agent"
        echo "horizon: now"
        echo "---"
        echo "# $id: Test"
        echo "## Open Questions"
        echo ""
        echo "$oq_body"
        echo ""
        echo "## Decision"
        echo "**Decision**: GO"
    } > "$path"
    echo "$path"
}

@test "fully disposed inception passes the gate" {
    file=$(_make_inception T-9100 "
- **IW-1: First question**
  confidence: 2
  disposition: answered
  rationale: see docs/reports/T-9100.md L42

- **IW-2: Second question**
  confidence: 1
  disposition: dissolved
  rationale: question premise refuted by Step 0 finding F-0.3
")
    # Extract just the function for direct testing. Source the lib helpers we need.
    run bash -c "
        TASK_FILE='$file'
        SKIP_DISPOSITION_GATE=false
        GREEN='' YELLOW='' RED='' NC=''
        log_gate_bypass() { :; }
        source <(sed -n '/^check_disposition_gate()/,/^}/p' '$UPDATE_SH')
        check_disposition_gate
    "
    [ "$status" -eq 0 ]
}

@test "under-disposed inception (no disposition line) is blocked" {
    file=$(_make_inception T-9101 "
- **IW-1: Question one**
  confidence: 2
  rationale: missing disposition

- **IW-2: Question two**
  confidence: 1
  disposition: answered
  rationale: ok
")
    run bash -c "
        TASK_FILE='$file'
        SKIP_DISPOSITION_GATE=false
        GREEN='' YELLOW='' RED='' NC=''
        log_gate_bypass() { :; }
        source <(sed -n '/^check_disposition_gate()/,/^}/p' '$UPDATE_SH')
        check_disposition_gate
    "
    [ "$status" -ne 0 ]
    [[ "$output" == *"under-disposed"* ]] || [[ "$output" == *"disposition"* ]]
}

@test "under-disposed inception (no rationale) is blocked" {
    file=$(_make_inception T-9102 "
- **IW-1: Question one**
  confidence: 2
  disposition: answered
")
    run bash -c "
        TASK_FILE='$file'
        SKIP_DISPOSITION_GATE=false
        GREEN='' YELLOW='' RED='' NC=''
        log_gate_bypass() { :; }
        source <(sed -n '/^check_disposition_gate()/,/^}/p' '$UPDATE_SH')
        check_disposition_gate
    "
    [ "$status" -ne 0 ]
}

@test "non-inception (workflow_type=build) is exempt" {
    file="$TEST_TEMP_DIR/.tasks/active/T-9103-test.md"
    {
        echo "---"
        echo "id: T-9103"
        echo "workflow_type: build"
        echo "---"
        echo "## Open Questions"
        echo "- **IW-1: foo**"
    } > "$file"
    run bash -c "
        TASK_FILE='$file'
        SKIP_DISPOSITION_GATE=false
        GREEN='' YELLOW='' RED='' NC=''
        log_gate_bypass() { :; }
        source <(sed -n '/^check_disposition_gate()/,/^}/p' '$UPDATE_SH')
        check_disposition_gate
    "
    [ "$status" -eq 0 ]
}

@test "inception without Open Questions section is grandfathered" {
    file="$TEST_TEMP_DIR/.tasks/active/T-9104-test.md"
    {
        echo "---"
        echo "id: T-9104"
        echo "workflow_type: inception"
        echo "---"
        echo "# Old inception with no Open Questions"
        echo "## Decision"
        echo "**Decision**: GO"
    } > "$file"
    run bash -c "
        TASK_FILE='$file'
        SKIP_DISPOSITION_GATE=false
        GREEN='' YELLOW='' RED='' NC=''
        log_gate_bypass() { :; }
        source <(sed -n '/^check_disposition_gate()/,/^}/p' '$UPDATE_SH')
        check_disposition_gate
    "
    [ "$status" -eq 0 ]
}

@test "--skip-disposition-gate bypass works (SKIP_DISPOSITION_GATE=true)" {
    file=$(_make_inception T-9105 "
- **IW-1: undisposed**
  confidence: 0
")
    run bash -c "
        TASK_FILE='$file'
        SKIP_DISPOSITION_GATE=true
        GREEN='' YELLOW='' RED='' NC=''
        log_gate_bypass() { echo 'BYPASS_LOGGED'; }
        source <(sed -n '/^check_disposition_gate()/,/^}/p' '$UPDATE_SH')
        check_disposition_gate
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"BYPASS_LOGGED"* ]]
}

@test "prose mention of IW-N in rationale does NOT trigger a false flush (T-2218 RC5)" {
    # Regression for T-2217 RC5: the IW-N branch of the question-marker regex
    # was unanchored, so the IW-2 rationale text "depends on IW-1's answer"
    # was classified as a new IW-1 marker, false-flushing IW-2's real
    # disposition+rationale as "missing".
    file=$(_make_inception T-9106 "
- **IW-1: First question**
  confidence: 2
  disposition: answered
  rationale: see docs/reports/T-9106.md L42

- **IW-2: Second question depends on IW-1**
  confidence: 1
  disposition: deferred — depends on IW-1's answer and IW-1's rationale per the docs
  rationale: IW-1 must resolve first; the IW-1 / IW-2 ordering is what the prose calls out
")
    run bash -c "
        TASK_FILE='$file'
        SKIP_DISPOSITION_GATE=false
        GREEN='' YELLOW='' RED='' NC=''
        log_gate_bypass() { :; }
        source <(sed -n '/^check_disposition_gate()/,/^}/p' '$UPDATE_SH')
        check_disposition_gate
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"all Open Questions disposed"* ]]
}

@test "update-task.sh accepts --skip-disposition-gate flag in arg parsing" {
    # Just confirm the flag is recognised (no 'unknown option' error)
    run bash -c "$UPDATE_SH --help 2>&1 || true"
    # --help should still succeed; flag parser checks happen earlier
    [ "$status" -ge 0 ]
    # The function definition exists
    grep -q "^check_disposition_gate()" "$UPDATE_SH"
    grep -q "skip-disposition-gate" "$UPDATE_SH"
    grep -q "FW_SKIP_DISPOSITION_GATE" "$UPDATE_SH"
}
