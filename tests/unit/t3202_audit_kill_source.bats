#!/usr/bin/env bats
# T-3202 — the full-audit timing record could not distinguish a run that
# exhausted its OWN ceiling from a run killed by something outside it.
#
# Observed: total_seconds: 900 / ceiling_seconds: 3000 / timed_out: true. Those
# three cannot describe one internal timeout. `fw doctor` rendered it as
# "TIMED OUT ... / 3000s ceiling" and told the reader to raise
# FW_AUDIT_FULL_TIMEOUT — a limit the run never reached.
#
# REPRODUCED before any fix (AC1), both arms, real audit.sh, real SIGTERM:
#   external `timeout 45`, ceiling 3000 -> total 45,  ceiling 3000, timed_out true
#   internal watchdog,     ceiling 45   -> total 50,  ceiling 45,   timed_out true
# Both exited 124. The discriminator is exact, not a threshold: the watchdog
# sleeps AUDIT_TIMEOUT before sending TERM and the trap runs after the in-flight
# command returns, so an internal kill records total >= ceiling ALWAYS (it
# overshot to 50 above). total < ceiling therefore PROVES an external killer.
#
# L-599: every classifier fixture below is synthetic. The one end-to-end test
# runs the real script and asserts the shape, never a measured duration.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
CLASSIFY="$FRAMEWORK_ROOT/lib/audit_timing.py"

setup() { TMP_T3202="$(mktemp -d)"; }
teardown() { rm -rf "$TMP_T3202"; }

_fixture() { cat > "$TMP_T3202/$1"; }

# Extract the shipped writer function and invoke it, rather than restating its
# logic here. A guard that reimplements the code it guards cannot detect that
# code being fixed (peer 832, chat-arc 689) — and a test that fakes its data
# source cannot detect the source behaving differently (T-3209, learned the
# hard way when a faked `pgrep` hid a live false positive).
_run_writer() {
    # $1 = total_seconds, $2 = AUDIT_TIMEOUT ; writes YAML to $TMP_T3202/out.yaml
    local total="$1" ceiling="$2"
    sed -n '/^_audit_write_timing_yaml() {$/,/^}$/p' "$AUDIT" > "$TMP_T3202/writer.sh"
    [ -s "$TMP_T3202/writer.sh" ] || return 91
    bash -c "
        AUDIT_TIMING_FILE='$TMP_T3202/out.yaml'
        AUDIT_RUN_START_ISO='2026-01-01T00:00:00+00:00'
        AUDIT_TIMEOUT=$ceiling
        declare -a SECTION_NAMES=('structure')
        declare -a SECTION_DURATIONS=(12)
        source '$TMP_T3202/writer.sh'
        _audit_write_timing_yaml 1 'structure' $total
    "
}

# Extract the shipped doctor case-arm the same way.
_run_doctor_arm() {
    # $1 = the classifier output line to feed the case statement
    sed -n '/^        TIMED_OUT\\|\*)$/,/^        \*)$/p' "$FRAMEWORK_ROOT/bin/fw" > "$TMP_T3202/arm.sh"
    [ -s "$TMP_T3202/arm.sh" ] || return 91
    bash -c "
        RED=''; NC=''; YELLOW=''; GREEN=''; CYAN=''
        issues=0; warnings=0
        _at_out='$1'
        case \"\$_at_out\" in
$(cat "$TMP_T3202/arm.sh" 2>/dev/null)
        esac
    " 2>/dev/null
}

# ── The classifier: three records that must not collapse into one (AC4) ──

@test "t3202: external kill is its own status, not 'timed out'" {
    _fixture external.yaml <<'YAML'
last_run:
  total_seconds: 900
  ceiling_seconds: 3000
  timed_out: true
  kill_source: external
  killed_in_section: "oe-daily"
YAML
    run python3 "$CLASSIFY" "$TMP_T3202/external.yaml" 0.70
    [ "$status" -eq 0 ]
    [[ "$output" == KILLED_EXTERNAL\|900\|3000\|oe-daily\|recorded ]]
}

@test "t3202: a run that exhausted its own ceiling stays TIMED_OUT" {
    _fixture internal.yaml <<'YAML'
last_run:
  total_seconds: 3000
  ceiling_seconds: 3000
  timed_out: true
  kill_source: internal
  killed_in_section: "oe-daily"
YAML
    run python3 "$CLASSIFY" "$TMP_T3202/internal.yaml" 0.70
    [ "$status" -eq 0 ]
    [[ "$output" == TIMED_OUT\|3000\|3000\|oe-daily ]]
}

@test "t3202: an internal kill that OVERSHOT the ceiling is still internal" {
    # Measured: ceiling 45 -> total 50. The trap runs after the in-flight
    # command returns, so total > ceiling is the normal internal shape. A
    # `total == ceiling` test would have been wrong.
    _fixture overshoot.yaml <<'YAML'
last_run:
  total_seconds: 3060
  ceiling_seconds: 3000
  timed_out: true
  kill_source: internal
  killed_in_section: "oe-daily"
YAML
    run python3 "$CLASSIFY" "$TMP_T3202/overshoot.yaml" 0.70
    [ "$status" -eq 0 ]
    [[ "$output" == TIMED_OUT\|3060\|3000\|oe-daily ]]
}

@test "t3202: a clean completion is unaffected by the split" {
    _fixture clean.yaml <<'YAML'
last_run:
  total_seconds: 1895
  ceiling_seconds: 3000
  timed_out: false
  sections: []
YAML
    run python3 "$CLASSIFY" "$TMP_T3202/clean.yaml" 0.70
    [ "$status" -eq 0 ]
    [[ "$output" == OK\|1895\|3000\|* ]]
}

# ── Legacy records: the originating one had no kill_source at all ──

@test "t3202: the ORIGINATING record (900/3000, no kill_source) classifies as external" {
    _fixture legacy.yaml <<'YAML'
last_run:
  total_seconds: 900
  ceiling_seconds: 3000
  timed_out: true
  killed_in_section: "oe-daily"
YAML
    run python3 "$CLASSIFY" "$TMP_T3202/legacy.yaml" 0.70
    [ "$status" -eq 0 ]
    [[ "$output" == KILLED_EXTERNAL\|900\|3000\|oe-daily\|derived ]]
}

@test "t3202: a derived verdict is flagged as derived, never as recorded" {
    # Provenance is load-bearing: the operator must be able to tell a fact the
    # writer stated from one this classifier inferred.
    _fixture legacy2.yaml <<'YAML'
last_run:
  total_seconds: 100
  ceiling_seconds: 3000
  timed_out: true
  killed_in_section: "structure"
YAML
    run python3 "$CLASSIFY" "$TMP_T3202/legacy2.yaml" 0.70
    [[ "$output" == *\|derived ]]
    [[ "$output" != *\|recorded ]]
}

@test "t3202: a legacy record at its ceiling still reads as internal" {
    _fixture legacy3.yaml <<'YAML'
last_run:
  total_seconds: 600
  ceiling_seconds: 600
  timed_out: true
  killed_in_section: "oe-daily"
YAML
    run python3 "$CLASSIFY" "$TMP_T3202/legacy3.yaml" 0.70
    [[ "$output" == TIMED_OUT\|600\|600\|oe-daily ]]
}

# ── The writer: the shipped function, invoked ──

@test "t3202: writer records kill_source external when total is below the ceiling" {
    run _run_writer 45 3000
    [ "$status" -eq 0 ]
    run grep -q "kill_source: external" "$TMP_T3202/out.yaml"
    [ "$status" -eq 0 ]
}

@test "t3202: writer records kill_source internal when total reaches the ceiling" {
    run _run_writer 50 45
    [ "$status" -eq 0 ]
    run grep -q "kill_source: internal" "$TMP_T3202/out.yaml"
    [ "$status" -eq 0 ]
}

@test "t3202: writer emits exactly one kill_source line" {
    # CONTROL: guards against a writer that emits both branches, which would
    # satisfy either grep above on its own.
    run _run_writer 45 3000
    [ "$status" -eq 0 ]
    run grep -c "kill_source:" "$TMP_T3202/out.yaml"
    [ "$output" -eq 1 ]
}

@test "t3202: writer emits NO kill_source on a clean run" {
    sed -n '/^_audit_write_timing_yaml() {$/,/^}$/p' "$AUDIT" > "$TMP_T3202/writer.sh"
    bash -c "
        AUDIT_TIMING_FILE='$TMP_T3202/clean-out.yaml'
        AUDIT_RUN_START_ISO='2026-01-01T00:00:00+00:00'
        AUDIT_TIMEOUT=3000
        declare -a SECTION_NAMES=('structure')
        declare -a SECTION_DURATIONS=(12)
        source '$TMP_T3202/writer.sh'
        _audit_write_timing_yaml 0 '' 1895
    "
    run grep -q "kill_source:" "$TMP_T3202/clean-out.yaml"
    [ "$status" -ne 0 ]
}

# ── The doctor message: AC3, the advice must stop misdirecting ──

@test "t3202: doctor does NOT tell the reader to raise the timeout on an external kill" {
    run _run_doctor_arm "KILLED_EXTERNAL|900|3000|oe-daily|recorded"
    [[ "$output" == *"KILLED FROM OUTSIDE"* ]]
    [[ "$output" == *"will NOT help"* ]]
}

@test "t3202: doctor DOES tell the reader to raise the timeout on a real ceiling exhaustion" {
    # CONTROL: separates "the new arm fires" from "the advice was deleted
    # everywhere". Raising the ceiling is still the right advice here.
    run _run_doctor_arm "TIMED_OUT|3000|3000|oe-daily"
    [[ "$output" == *"FW_AUDIT_FULL_TIMEOUT"* ]]
    [[ "$output" != *"KILLED FROM OUTSIDE"* ]]
}

@test "t3202: doctor names the derived provenance when the record does not state it" {
    run _run_doctor_arm "KILLED_EXTERNAL|900|3000|oe-daily|derived"
    [[ "$output" == *"inferred"* ]]
}

@test "t3202: doctor stays silent about provenance when the record states it" {
    run _run_doctor_arm "KILLED_EXTERNAL|900|3000|oe-daily|recorded"
    [[ "$output" != *"inferred"* ]]
}

# ── End to end: the real script, a real external kill ──

@test "t3202: a real externally-killed audit records kill_source external" {
    TIMING_FILE="$FRAMEWORK_ROOT/.context/audits/full-audit-timing.yaml"
    PREV=""
    [ -f "$TIMING_FILE" ] && PREV="$(cat "$TIMING_FILE")"
    rm -f "$TIMING_FILE"

    # Ceiling deliberately far above the external kill, which is the whole
    # point: the run must be killed long before its own watchdog could fire.
    FW_AUDIT_FULL_TIMEOUT=3000 timeout 20 "$AUDIT" \
        --output "$TMP_T3202/audit-out" --quiet || true

    local ok=0
    if [ -f "$TIMING_FILE" ]; then
        grep -q "timed_out: true" "$TIMING_FILE" \
            && grep -q "kill_source: external" "$TIMING_FILE" && ok=1
    fi

    if [ -n "$PREV" ]; then printf '%s\n' "$PREV" > "$TIMING_FILE"; else rm -f "$TIMING_FILE"; fi
    [ "$ok" -eq 1 ]
}

@test "t3202: audit.sh passes shell syntax check" {
    run bash -n "$AUDIT"
    [ "$status" -eq 0 ]
}

@test "t3202: bin/fw passes shell syntax check" {
    run bash -n "$FRAMEWORK_ROOT/bin/fw"
    [ "$status" -eq 0 ]
}
