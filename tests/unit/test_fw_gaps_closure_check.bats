#!/usr/bin/env bats
# T-1752 — `fw gaps` honours optional closure_check_command field.
#
# Contract:
#   - Gap without the field renders unchanged (backward compatible).
#   - Gap with a passing check (verdict=READY) renders Closure: READY (green).
#   - Gap with a failing/timing-out/non-JSON check renders Closure: ERROR.
#   - Verdict counters from JSON are surfaced when present (cron_firing_dates,
#     closure_threshold_dates → "have/need" tag).
#
# Origin: T-1750 shipped tools/g064-readiness.py — a closure-readiness gauge.
# T-1752 generalises so any future watching gap can declare its own check.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TMPDIR="$(mktemp -d)"
    mkdir -p "$TMPDIR/.context/project"
    # Copy bin/fw so PROJECT_ROOT-routed lookups work from $TMPDIR.
    # The script reads concerns.yaml relative to PROJECT_ROOT, but bin/fw
    # itself can run from anywhere.
    cd "$TMPDIR"
}

teardown() {
    cd "$BATS_TEST_DIRNAME"
    rm -rf "$TMPDIR"
}

_seed_concerns() {
    cat > "$TMPDIR/.context/project/concerns.yaml" <<EOF
concerns:
$1
EOF
}

@test "gap without closure_check_command renders unchanged" {
    _seed_concerns "
- id: G-TEST
  type: gap
  title: 'Test gap without check'
  status: watching
  severity: medium
  description: 'no check'"

    PROJECT_ROOT="$TMPDIR" run bash "$REPO_ROOT/bin/fw" gaps
    [ "$status" -eq 0 ]
    [[ "$output" == *"G-TEST"* ]]
    [[ "$output" != *"Closure:"* ]]
}

@test "gap with READY check renders verdict in green" {
    _seed_concerns "
- id: G-TEST
  type: gap
  title: 'Test gap with passing check'
  status: watching
  severity: medium
  description: 'check passes'
  closure_check_command: \"echo '{\\\"verdict\\\": \\\"READY\\\"}'\""

    PROJECT_ROOT="$TMPDIR" run bash "$REPO_ROOT/bin/fw" gaps
    [ "$status" -eq 0 ]
    [[ "$output" == *"Closure:"* ]]
    [[ "$output" == *"READY"* ]]
}

@test "gap with NOT_READY check + counters renders verdict with X/Y tag" {
    _seed_concerns "
- id: G-TEST
  type: gap
  title: 'Test gap with not-ready check'
  status: watching
  severity: medium
  description: 'not yet'
  closure_check_command: \"echo '{\\\"verdict\\\": \\\"NOT_READY\\\", \\\"cron_firing_dates\\\": [], \\\"closure_threshold_dates\\\": 3}'\""

    PROJECT_ROOT="$TMPDIR" run bash "$REPO_ROOT/bin/fw" gaps
    [ "$status" -eq 0 ]
    [[ "$output" == *"NOT_READY"* ]]
    [[ "$output" == *"0/3"* ]]
}

@test "non-JSON output renders Closure: ERROR (non-JSON output)" {
    _seed_concerns "
- id: G-TEST
  type: gap
  title: 'Test gap with broken check'
  status: watching
  severity: medium
  description: 'broken'
  closure_check_command: 'echo not-json'"

    PROJECT_ROOT="$TMPDIR" run bash "$REPO_ROOT/bin/fw" gaps
    [ "$status" -eq 0 ]
    [[ "$output" == *"ERROR"* ]]
    [[ "$output" == *"non-JSON"* ]]
}

@test "empty stdout renders Closure: ERROR (empty output)" {
    _seed_concerns "
- id: G-TEST
  type: gap
  title: 'Test gap with silent check'
  status: watching
  severity: medium
  description: 'silent'
  closure_check_command: 'true'"

    PROJECT_ROOT="$TMPDIR" run bash "$REPO_ROOT/bin/fw" gaps
    [ "$status" -eq 0 ]
    [[ "$output" == *"ERROR"* ]]
    [[ "$output" == *"empty"* ]]
}

@test "fw gaps exits 0 even when closure check fails" {
    _seed_concerns "
- id: G-TEST
  type: gap
  title: 'Test gap with failing check'
  status: watching
  severity: medium
  description: 'fails'
  closure_check_command: 'false'"

    PROJECT_ROOT="$TMPDIR" run bash "$REPO_ROOT/bin/fw" gaps
    [ "$status" -eq 0 ]
}
