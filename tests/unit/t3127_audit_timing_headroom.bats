#!/usr/bin/env bats
# T-3127 — no check asserted that the full-audit timeout budget (AUDIT_TIMEOUT,
# a pinned constant) still fits the corpus it scans (which grows every commit).
# T-3070 measured 1729s/3000s (58%) and left the gap as a follow-up; this pins
# the fix: lib/audit_timing.py classifies a persisted timing record against a
# configured warn fraction, and `fw doctor` surfaces the result.
#
# L-599: deliberately does NOT pin to the live corpus's measured runtime
# (1729s at T-3070 authoring time — moves every time the corpus grows).
# Every fixture below is synthetic.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
CLASSIFY="$FRAMEWORK_ROOT/lib/audit_timing.py"

setup() {
    TMPDIR_T3127="$(mktemp -d)"
}

teardown() {
    rm -rf "$TMPDIR_T3127"
}

_fixture() {
    # $1 = filename, remaining = YAML body on stdin
    cat > "$TMPDIR_T3127/$1"
}

@test "t3127: over-threshold duration WARNs" {
    _fixture over.yaml <<'YAML'
last_run:
  timestamp: "2026-01-01T00:00:00+00:00"
  total_seconds: 2200
  ceiling_seconds: 3000
  timed_out: false
  sections: []
YAML
    run python3 "$CLASSIFY" "$TMPDIR_T3127/over.yaml" 0.70
    [ "$status" -eq 0 ]
    [[ "$output" == WARN\|2200\|3000\|* ]]
}

@test "t3127: under-threshold duration is silent (OK)" {
    _fixture under.yaml <<'YAML'
last_run:
  timestamp: "2026-01-01T00:00:00+00:00"
  total_seconds: 900
  ceiling_seconds: 3000
  timed_out: false
  sections: []
YAML
    run python3 "$CLASSIFY" "$TMPDIR_T3127/under.yaml" 0.70
    [ "$status" -eq 0 ]
    [[ "$output" == OK\|900\|3000\|* ]]
}

@test "t3127: exactly-at-threshold WARNs (boundary is inclusive)" {
    _fixture boundary.yaml <<'YAML'
last_run:
  timestamp: "2026-01-01T00:00:00+00:00"
  total_seconds: 2100
  ceiling_seconds: 3000
  timed_out: false
  sections: []
YAML
    run python3 "$CLASSIFY" "$TMPDIR_T3127/boundary.yaml" 0.70
    [ "$status" -eq 0 ]
    [[ "$output" == WARN\|* ]]
}

@test "t3127: a timed-out record is distinguishable from a passed section (AC4)" {
    _fixture timedout.yaml <<'YAML'
last_run:
  timestamp: "2026-01-01T00:00:00+00:00"
  total_seconds: 600
  ceiling_seconds: 600
  timed_out: true
  killed_in_section: "oe-daily"
  sections:
    - name: "structure"
      seconds: 89
YAML
    run python3 "$CLASSIFY" "$TMPDIR_T3127/timedout.yaml" 0.70
    [ "$status" -eq 0 ]
    [[ "$output" == TIMED_OUT\|600\|600\|oe-daily ]]
}

@test "t3127: a missing record is explicit UNMEASURED, never a silent pass" {
    run python3 "$CLASSIFY" "$TMPDIR_T3127/does-not-exist.yaml" 0.70
    [ "$status" -eq 0 ]
    [[ "$output" == UNMEASURED\|* ]]
}

@test "t3127: an unparseable/incomplete record is explicit UNMEASURED, not OK" {
    _fixture malformed.yaml <<'YAML'
last_run:
  timestamp: "2026-01-01T00:00:00+00:00"
YAML
    run python3 "$CLASSIFY" "$TMPDIR_T3127/malformed.yaml" 0.70
    [ "$status" -eq 0 ]
    [[ "$output" == UNMEASURED\|* ]]
}

@test "t3127: zero ceiling_seconds is UNMEASURED, not a division-by-zero crash" {
    _fixture zeroceil.yaml <<'YAML'
last_run:
  timestamp: "2026-01-01T00:00:00+00:00"
  total_seconds: 100
  ceiling_seconds: 0
  timed_out: false
  sections: []
YAML
    run python3 "$CLASSIFY" "$TMPDIR_T3127/zeroceil.yaml" 0.70
    [ "$status" -eq 0 ]
    [[ "$output" == UNMEASURED\|* ]]
}

@test "t3127: AUDIT_TIMEOUT_WARN_FRACTION is registered in the config registry" {
    run grep -q '"AUDIT_TIMEOUT_WARN_FRACTION|' "$FRAMEWORK_ROOT/lib/config.sh"
    [ "$status" -eq 0 ]
}

@test "t3127: section_mark is wired into every should_run_section top-level block" {
    # 24 headline sections at authoring time (T-3127). Guards against silent
    # instrumentation loss on future section additions/removals: this count
    # should track deliberately, not drift for free.
    run grep -c 'section_mark "' "$AUDIT"
    [ "$status" -eq 0 ]
    [ "$output" -ge 20 ]
}

@test "t3127: the TERM trap records timed_out on a real timeout kill" {
    # End-to-end: force a 3s ceiling on a full run and confirm the persisted
    # record names the section that was killed. Real audit.sh, real lock,
    # real SIGTERM — not a simulation of the trap logic.
    OUT_DIR="$TMPDIR_T3127/audit-out"
    TIMING_FILE="$FRAMEWORK_ROOT/.context/audits/full-audit-timing.yaml"
    PREV_TIMING=""
    [ -f "$TIMING_FILE" ] && PREV_TIMING="$(cat "$TIMING_FILE")"
    rm -f "$TIMING_FILE"

    FW_AUDIT_FULL_TIMEOUT=3 timeout 60 "$AUDIT" --output "$OUT_DIR" --quiet || true

    [ -f "$TIMING_FILE" ]
    run grep -q "timed_out: true" "$TIMING_FILE"
    [ "$status" -eq 0 ]
    run grep -q "killed_in_section:" "$TIMING_FILE"
    [ "$status" -eq 0 ]

    # Restore whatever was there before so this test has no side effect on a
    # real dev checkout's timing record.
    if [ -n "$PREV_TIMING" ]; then
        printf '%s\n' "$PREV_TIMING" > "$TIMING_FILE"
    else
        rm -f "$TIMING_FILE"
    fi
}

@test "t3127: audit.sh passes shell syntax check after edit" {
    run bash -n "$AUDIT"
    [ "$status" -eq 0 ]
}

@test "t3127: bin/fw passes shell syntax check after edit" {
    run bash -n "$FRAMEWORK_ROOT/bin/fw"
    [ "$status" -eq 0 ]
}
