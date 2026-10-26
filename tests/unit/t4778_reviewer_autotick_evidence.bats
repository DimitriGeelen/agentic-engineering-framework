#!/usr/bin/env bats
# T-4778 (010-termlink msg 85aed887, their T-3592): the reviewer auto-tick
# fired on an empty static-scan PASS — `findings: []` means no anti-pattern
# matched, not that the criterion holds. It ticked acts in the world it cannot
# observe and a destructive criterion whose own scan said needs_human: true.
#
# Contract pinned here: a [REVIEWER] Agent criterion is auto-ticked only when
# the verdict does not need a human AND the criterion names a check this scan
# actually ran (a catalogue pattern id) with no finding for it. Every decision
# is written to the ## Reviewer Verdict block.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    TEST_ROOT="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.tasks/completed" "$TEST_ROOT/.context/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_ROOT/.framework.yaml"
    export PROJECT_ROOT="$TEST_ROOT"
}

_task() {
    # $1 id, $2 Agent AC block
    cat > "$TEST_ROOT/.tasks/active/$1-fixture.md" <<EOF
---
id: $1
name: fixture
status: started-work
workflow_type: build
---

# $1

## Acceptance Criteria

### Agent
$2

## Verification

python3 -c 'pass'
EOF
}

_scan() {
    cd "$FRAMEWORK_ROOT"
    "$FRAMEWORK_ROOT/bin/fw" reviewer "$1" > "$BATS_TEST_TMPDIR/out" 2>&1 || true
    cat "$TEST_ROOT/.tasks/active/$1-fixture.md"
}

@test "T-4778 (a): needs_human escalation blocks auto-tick even with a named, clean check" {
    _task T-9781 "- [ ] [REVIEWER] Verification has no findings on tautology
- [ ] Force-push the rewritten history over the stray repo"
    run _scan T-9781
    echo "$output" | grep -q -- "- \*\*Needs Human:\*\* yes"
    echo "$output" | grep -q -- "- \[ \] \[REVIEWER\] Verification has no findings on tautology"
    ! echo "$output" | grep -q -- "- \[x\] \[REVIEWER\]" || false
    echo "$output" | grep -q "AC #1: not ticked — needs_human"
}

@test "T-4778 (b): criterion naming no check the scan ran is not ticked on empty PASS" {
    _task T-9782 "- [ ] [REVIEWER] Hub restarted on the remote host and responds to ping"
    run _scan T-9782
    echo "$output" | grep -q -- "- \*\*Overall:\*\* PASS"
    echo "$output" | grep -q -- "- \[ \] \[REVIEWER\] Hub restarted"
    echo "$output" | grep -q "AC #1: not ticked — no check this scan ran; route to fw reviewer judge"
}

@test "T-4778 (c): a named catalogue pattern the scan did not run is not evidence" {
    _task T-9783 "- [ ] [REVIEWER] No findings on block-message-completeness"
    run _scan T-9783
    echo "$output" | grep -q -- "- \[ \] \[REVIEWER\] No findings on block-message-completeness"
    echo "$output" | grep -q "route to fw reviewer judge"
}

@test "T-4778 (d): named check the scan ran with no finding is ticked, and the decision is recorded" {
    _task T-9784 "- [ ] [REVIEWER] Verification has no findings on tautology or swallowed-errors"
    run _scan T-9784
    echo "$output" | grep -q -- "- \[x\] \[REVIEWER\] Verification has no findings on tautology"
    echo "$output" | grep -q "AC #1: ticked — ran swallowed-errors, tautology: no findings"
}

@test "T-4778 (e): a finding on the named pattern (any location) blocks the tick" {
    _task T-9785 "- [ ] [REVIEWER] Verification has no findings on swallowed-errors"
    sed -i "s/^python3 -c 'pass'$/make test || true/" "$TEST_ROOT/.tasks/active/T-9785-fixture.md"
    run _scan T-9785
    echo "$output" | grep -q -- "- \[ \] \[REVIEWER\] Verification has no findings on swallowed-errors"
}

@test "T-4778 (f): SCANNED_PATTERN_IDS matches the pattern ids the detectors emit" {
    cd "$FRAMEWORK_ROOT"
    run python3 -c '
import re, sys
sys.path.insert(0, ".")
from lib.reviewer import static_scan as ss
src = open("lib/reviewer/static_scan.py").read()
emitted = set(re.findall(r"pattern_id=\"([A-Za-z0-9-]+)\"", src))
diff = emitted ^ ss.SCANNED_PATTERN_IDS
print("drift:", sorted(diff)) if diff else print("in step")
sys.exit(1 if diff else 0)
'
    [ "$status" -eq 0 ]
    [ "$output" = "in step" ]
}
