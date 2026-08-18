#!/usr/bin/env bats
# T-3061 (OBS-316/OBS-317): unclosed-but-satisfied detector, active-task-scan.py.
#
# A task in .tasks/active/ qualifies when status is started-work/issues, has
# at least one Agent AC, every Agent AC is ticked, and no Human AC is left
# unticked. HTML comment blocks (including the template's own example ACs)
# must not count. Pins both directions (A6): a qualifying fixture is
# reported; disqualifying fixtures (unticked Agent AC, unticked Human AC,
# zero ACs, template-only comment examples) are each NOT reported.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
ACTIVE_SCAN="$FRAMEWORK_ROOT/agents/audit/active-task-scan.py"

setup() {
    export TEST_DIR="$(mktemp -d)"
    mkdir -p "$TEST_DIR/active" "$TEST_DIR/completed" "$TEST_DIR/reports"
}

teardown() {
    rm -rf "$TEST_DIR"
}

_ids_json() {
    python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps([t['id'] for t in d['unclosed_satisfied']['tasks']]))"
}

@test "T-3061: qualifying task (all Agent ticked, no Human unticked) IS reported" {
    cat > "$TEST_DIR/active/T-9001-qualifies.md" << 'EOF'
---
id: T-9001
name: "Qualifies"
status: started-work
workflow_type: build
---
# T-9001

## Acceptance Criteria

### Agent
- [x] First done
- [x] Second done

### Human
- [x] Reviewed already

## Verification

echo test

## Updates
EOF
    run python3 "$ACTIVE_SCAN" "$TEST_DIR" "$TEST_DIR/reports"
    [ "$status" -eq 0 ]
    ids=$(echo "$output" | _ids_json)
    [[ "$ids" == *"T-9001"* ]]
}

@test "T-3061: one unticked Agent AC → NOT reported" {
    cat > "$TEST_DIR/active/T-9002-unticked-agent.md" << 'EOF'
---
id: T-9002
name: "Unticked agent AC"
status: started-work
workflow_type: build
---
# T-9002

## Acceptance Criteria

### Agent
- [x] Done one
- [ ] Not done yet

### Human
- [x] Reviewed

## Verification

echo test

## Updates
EOF
    run python3 "$ACTIVE_SCAN" "$TEST_DIR" "$TEST_DIR/reports"
    [ "$status" -eq 0 ]
    ids=$(echo "$output" | _ids_json)
    [[ "$ids" != *"T-9002"* ]]
}

@test "T-3061: one unticked Human AC → NOT reported" {
    cat > "$TEST_DIR/active/T-9003-unticked-human.md" << 'EOF'
---
id: T-9003
name: "Unticked human AC"
status: started-work
workflow_type: build
---
# T-9003

## Acceptance Criteria

### Agent
- [x] Done one

### Human
- [ ] [REVIEW] Not confirmed yet

## Verification

echo test

## Updates
EOF
    run python3 "$ACTIVE_SCAN" "$TEST_DIR" "$TEST_DIR/reports"
    [ "$status" -eq 0 ]
    ids=$(echo "$output" | _ids_json)
    [[ "$ids" != *"T-9003"* ]]
}

@test "T-3061: zero ACs → NOT reported" {
    cat > "$TEST_DIR/active/T-9004-zero-acs.md" << 'EOF'
---
id: T-9004
name: "Zero ACs"
status: started-work
workflow_type: build
---
# T-9004

## Acceptance Criteria

### Agent

### Human

## Verification

echo test

## Updates
EOF
    run python3 "$ACTIVE_SCAN" "$TEST_DIR" "$TEST_DIR/reports"
    [ "$status" -eq 0 ]
    ids=$(echo "$output" | _ids_json)
    [[ "$ids" != *"T-9004"* ]]
}

@test "T-3061: only unticked boxes are template comment examples → NOT reported (A4)" {
    cat > "$TEST_DIR/active/T-9005-template-only.md" << 'EOF'
---
id: T-9005
name: "Template-only Human section"
status: started-work
workflow_type: build
---
# T-9005

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify. -->
- [x] Real agent criterion done

### Human
<!-- Remove this section if all criteria are agent-verifiable.
     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         **Expected:** All panels visible, no console errors

     [REVIEWER] example (static-scan-verifiable):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Expected:** Verdict: PASS
-->

## Verification

echo test

## Updates
EOF
    run python3 "$ACTIVE_SCAN" "$TEST_DIR" "$TEST_DIR/reports"
    [ "$status" -eq 0 ]
    ids=$(echo "$output" | _ids_json)
    [[ "$ids" == *"T-9005"* ]]
}

@test "T-3061: captured status never qualifies regardless of ticks" {
    cat > "$TEST_DIR/active/T-9006-captured.md" << 'EOF'
---
id: T-9006
name: "Captured status"
status: captured
workflow_type: build
---
# T-9006

## Acceptance Criteria

### Agent
- [x] Done

## Verification

echo test

## Updates
EOF
    run python3 "$ACTIVE_SCAN" "$TEST_DIR" "$TEST_DIR/reports"
    [ "$status" -eq 0 ]
    ids=$(echo "$output" | _ids_json)
    [[ "$ids" != *"T-9006"* ]]
}

@test "T-3061: no_verification_count flags empty Verification block" {
    cat > "$TEST_DIR/active/T-9007-no-verif.md" << 'EOF'
---
id: T-9007
name: "No verification block"
status: issues
workflow_type: build
---
# T-9007

## Acceptance Criteria

### Agent
- [x] Done

## Verification

# just a comment, no real command

## Updates
EOF
    run python3 "$ACTIVE_SCAN" "$TEST_DIR" "$TEST_DIR/reports"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
u = d['unclosed_satisfied']
assert u['count'] == 1, u
assert u['no_verification_count'] == 1, u
assert u['tasks'][0]['id'] == 'T-9007'
assert u['tasks'][0]['has_verification'] is False
"
}

@test "T-3061: sanity — active-task-scan.py parses cleanly" {
    run python3 -c "import ast; ast.parse(open('$ACTIVE_SCAN').read())"
    [ "$status" -eq 0 ]
}
