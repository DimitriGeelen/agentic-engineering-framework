#!/usr/bin/env bats
# T-2185 — `fw gaps close <id>` flips gauge-READY gaps to status:closed.
#
# Contract:
#   - Happy path: gap with status:watching + gauge=READY → status flips,
#     closed_date set, closure_notes inserted, JSONL audit appended.
#   - Refuse 404 when gap_id is absent.
#   - Refuse 409 when gap is not status:watching (already closed).
#   - Refuse 412 when gauge is NOT_READY or UNKNOWN (no command).
#   - Override path: 412 + --override --rationale "..." closes the gap and
#     writes the rationale into closure_notes + audit log.
#   - Atomic write does not corrupt sibling gap entries.
#
# Origin: T-2185 build (Watchtower /gaps Close action server-side).
# Cascade: closing G-064 satisfies T-2169 retire_when audit advisory's
# F-ORCH heuristic — but this test seeds a synthetic gap, not G-064.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$TEST_TEMP_DIR/.context/project"
    mkdir -p "$TEST_TEMP_DIR/.context/audits"
    # Seed a minimal concerns.yaml with two gaps — one with gauge, one without.
    cat > "$TEST_TEMP_DIR/.context/project/concerns.yaml" <<'EOF'
concerns:
- id: G-TEST-A
  type: gap
  title: "Synthetic gap with gauge — READY"
  description: >
    Test fixture.
  severity: low
  status: watching
  closure_check_command: "python3 -c 'import json; print(json.dumps({\"verdict\":\"READY\"}))'"
  created: "2026-01-01"
  last_reviewed: "2026-01-01"
- id: G-TEST-B
  type: gap
  title: "Synthetic gap without gauge"
  description: >
    Test fixture.
  severity: low
  status: watching
  created: "2026-01-01"
- id: G-TEST-C
  type: gap
  title: "Synthetic gap NOT_READY"
  description: >
    Test fixture.
  severity: low
  status: watching
  closure_check_command: "python3 -c 'import json; print(json.dumps({\"verdict\":\"NOT_READY\"}))'"
  created: "2026-01-01"
- id: G-TEST-D
  type: gap
  title: "Synthetic already-closed gap"
  description: >
    Test fixture.
  severity: low
  status: closed
  closed_date: "2026-01-02"
  created: "2026-01-01"
EOF
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "happy path: gauge READY → status flips + closed_date + audit entry" {
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT')
import os; os.environ['PROJECT_ROOT'] = '$TEST_TEMP_DIR'
from lib.gaps import close_gap
r = close_gap('G-TEST-A', actor='bats', project_root=__import__('pathlib').Path('$TEST_TEMP_DIR'))
print(r['new_status'], r['verdict'], r['closed_date'])
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"closed READY"* ]]
    # Verify the YAML now shows status: closed for G-TEST-A (block-scoped grep).
    out=$(awk '/^- id: G-TEST-A/,/^- id: G-TEST-B/' "$TEST_TEMP_DIR/.context/project/concerns.yaml")
    grep -q "status: closed" <<<"$out"
    grep -q "closed_date:" <<<"$out"
    # Verify audit log has one entry.
    [ -f "$TEST_TEMP_DIR/.context/audits/gap-closures.jsonl" ]
    n=$(wc -l < "$TEST_TEMP_DIR/.context/audits/gap-closures.jsonl")
    [ "$n" -eq 1 ]
}

@test "atomic write: sibling gaps preserved verbatim" {
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT')
from lib.gaps import close_gap
close_gap('G-TEST-A', actor='bats', project_root=__import__('pathlib').Path('$TEST_TEMP_DIR'))
"
    [ "$status" -eq 0 ]
    # G-TEST-B and G-TEST-C still status:watching, G-TEST-D still status:closed.
    out=$(cat "$TEST_TEMP_DIR/.context/project/concerns.yaml")
    n_watching=$(grep -c "status: watching" <<<"$out")
    [ "$n_watching" -eq 2 ]
    n_closed=$(grep -c "status: closed" <<<"$out")
    [ "$n_closed" -eq 2 ]
    # Sibling titles preserved.
    grep -q "Synthetic gap without gauge" <<<"$out"
    grep -q "Synthetic gap NOT_READY" <<<"$out"
}

@test "refuse 404 on absent gap_id" {
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT')
from lib.gaps import close_gap, GapCloseError
try:
    close_gap('G-NOSUCH', project_root=__import__('pathlib').Path('$TEST_TEMP_DIR'))
except GapCloseError as e:
    print(e.code, e.message); raise SystemExit(0)
raise SystemExit(2)
"
    [ "$status" -eq 0 ]
    [[ "$output" == 404* ]]
}

@test "refuse 409 on already-closed gap" {
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT')
from lib.gaps import close_gap, GapCloseError
try:
    close_gap('G-TEST-D', project_root=__import__('pathlib').Path('$TEST_TEMP_DIR'))
except GapCloseError as e:
    print(e.code, e.message); raise SystemExit(0)
raise SystemExit(2)
"
    [ "$status" -eq 0 ]
    [[ "$output" == 409* ]]
}

@test "refuse 412 on gauge NOT_READY" {
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT')
from lib.gaps import close_gap, GapCloseError
try:
    close_gap('G-TEST-C', project_root=__import__('pathlib').Path('$TEST_TEMP_DIR'))
except GapCloseError as e:
    print(e.code, e.message); raise SystemExit(0)
raise SystemExit(2)
"
    [ "$status" -eq 0 ]
    [[ "$output" == 412* ]]
}

@test "refuse 412 on no-gauge gap (UNKNOWN verdict)" {
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT')
from lib.gaps import close_gap, GapCloseError
try:
    close_gap('G-TEST-B', project_root=__import__('pathlib').Path('$TEST_TEMP_DIR'))
except GapCloseError as e:
    print(e.code, e.message); raise SystemExit(0)
raise SystemExit(2)
"
    [ "$status" -eq 0 ]
    [[ "$output" == 412* ]]
}

@test "override path: NOT_READY + rationale closes and logs override flag" {
    run python3 -c "
import json, sys; sys.path.insert(0, '$FRAMEWORK_ROOT')
from lib.gaps import close_gap
r = close_gap('G-TEST-C', rationale='operator override — manual review confirms', override=True, actor='bats', project_root=__import__('pathlib').Path('$TEST_TEMP_DIR'))
print(r['new_status'], r['verdict'])
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"closed NOT_READY"* ]]
    # Audit entry has override=true.
    audit=$(cat "$TEST_TEMP_DIR/.context/audits/gap-closures.jsonl")
    grep -q '"override": true' <<<"$audit"
    grep -q 'operator override' <<<"$audit"
}

@test "override requires rationale (400 without)" {
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT')
from lib.gaps import close_gap, GapCloseError
try:
    close_gap('G-TEST-C', override=True, project_root=__import__('pathlib').Path('$TEST_TEMP_DIR'))
except GapCloseError as e:
    print(e.code, e.message); raise SystemExit(0)
raise SystemExit(2)
"
    [ "$status" -eq 0 ]
    [[ "$output" == 400* ]]
}

@test "fw gaps close CLI happy path" {
    run env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" gaps close G-TEST-A
    [ "$status" -eq 0 ]
    # ANSI escapes wrap "Closed" — match the gap_id and verdict separately.
    [[ "$output" == *"Closed"* ]]
    [[ "$output" == *"G-TEST-A"* ]]
    [[ "$output" == *"verdict=READY"* ]]
}

@test "fw gaps close CLI refuse path (404)" {
    run env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" gaps close G-NOSUCH
    [ "$status" -eq 1 ]
    [[ "$output" == *"Refused"* ]]
    [[ "$output" == *"404"* ]]
}

@test "fw gaps close with no args lists closure-eligible gaps" {
    run env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" gaps close
    [ "$status" -eq 2 ]
    [[ "$output" == *"G-TEST-A"* ]]
}

@test "stale_ready_gaps returns synthetic gauge=READY entries" {
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT')
from lib.gaps import stale_ready_gaps
out = stale_ready_gaps(project_root=__import__('pathlib').Path('$TEST_TEMP_DIR'), threshold_days=0)
ids = [g['gap_id'] for g in out]
print(' '.join(ids))
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"G-TEST-A"* ]]
}
