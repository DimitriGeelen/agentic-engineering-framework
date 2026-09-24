#!/usr/bin/env bats
# T-3451 — the audit timing ledger two derivations depend on
# (fw_prepush_lock_wait_default, fw_handover_push_timeout_default,
# lib/prepush-lock-wait.sh) was written only by a full, unscoped `fw audit`
# run, never by the scoped `--section structure` run the pre-push hook
# actually pays on every push. Measured live (T-3450's handback): ledger said
# 268s, a clean scoped run right next to it took 325s.
#
# Fix: agents/audit/audit.sh now records every completed section — full OR
# scoped — into a new `section_runs:` ledger block via
# `_audit_record_section_run`, and lib/prepush-lock-wait.sh's readers
# resolve through it first, falling back to the historical
# `last_run.sections` shape only when section_runs has nothing for that
# section. `fw doctor` gets a staleness WARN
# (AUDIT_STRUCTURE_TIMING_STALE_DAYS, default 7) so a stale ledger is visible
# rather than silently trusted.
#
# Hermetic: every ledger here is a fixture under TEST_TEMP_DIR. Extraction
# convention (T-3202): shipped functions/blocks are sed-extracted from the
# real source and invoked, never re-implemented — a test that restates the
# logic it guards cannot detect that logic being changed.

load ../test_helper

LIB="$FRAMEWORK_ROOT/lib/prepush-lock-wait.sh"
AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    mkdir -p "$TEST_TEMP_DIR/.context/audits"
    # T-2787/T-2788 gotcha, the other direction: a bats file's top-level
    # statements run ONCE at parse time, before any test's setup() — so
    # LEDGER must be (re)computed HERE, per test, after TEST_TEMP_DIR exists,
    # not as a top-level `LEDGER=...` assignment evaluated against an empty
    # TEST_TEMP_DIR.
    LEDGER="$TEST_TEMP_DIR/.context/audits/full-audit-timing.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

run_lock_default() { run bash -c "source '$LIB'; fw_prepush_lock_wait_default '$TEST_TEMP_DIR'"; }
run_push_default()  { run bash -c "source '$LIB'; fw_handover_push_timeout_default '$TEST_TEMP_DIR'"; }
run_seconds()        { run bash -c "source '$LIB'; fw_audit_timing_read_structure_seconds '$TEST_TEMP_DIR'"; }
run_measured_at()    { run bash -c "source '$LIB'; fw_audit_timing_last_measured_at '$TEST_TEMP_DIR' structure"; }
run_is_stale()       { run bash -c "source '$LIB'; fw_audit_timing_is_stale '$TEST_TEMP_DIR' structure ${1:-7}"; }

# ── AC1/AC4: a fixture ledger written by a SCOPED run (section_runs: only,
#    no last_run: block at all — the shape a first-ever scoped run produces
#    on a host that has never run a full audit) is read identically by both
#    derivations ──

@test "scoped-only ledger (no last_run:): seconds reader finds the section_runs entry" {
    cat > "$LEDGER" <<EOF
section_runs:
  - name: "structure"
    seconds: 325
    timestamp: "$(date -Iseconds)"
    timed_out: false
    excludes_lock_wait: true
EOF
    run_seconds
    [ "$status" -eq 0 ]
    [ "$output" = "325" ]
}

@test "scoped-only ledger: fw_prepush_lock_wait_default derives ceil(1.25x) from it" {
    cat > "$LEDGER" <<EOF
section_runs:
  - name: "structure"
    seconds: 325
    timestamp: "$(date -Iseconds)"
    timed_out: false
    excludes_lock_wait: true
EOF
    run_lock_default
    [ "$status" -eq 0 ]
    [ "$output" = "407" ]   # ceil(325*1.25) = 406.25 -> 407, clamped [90,600]
}

@test "scoped-only ledger: fw_handover_push_timeout_default derives ceil(1.5x) from it" {
    cat > "$LEDGER" <<EOF
section_runs:
  - name: "structure"
    seconds: 325
    timestamp: "$(date -Iseconds)"
    timed_out: false
    excludes_lock_wait: true
EOF
    run_push_default
    [ "$status" -eq 0 ]
    [ "$output" = "488" ]   # ceil(325*1.5) = 487.5 -> 488, clamped [180,900]
}

@test "scoped-only ledger: push timeout still exceeds lock wait (dominance holds on the new shape too)" {
    cat > "$LEDGER" <<EOF
section_runs:
  - name: "structure"
    seconds: 325
    timestamp: "$(date -Iseconds)"
    timed_out: false
    excludes_lock_wait: true
EOF
    run_lock_default; lock="$output"
    run_push_default; push="$output"
    [ "$push" -gt "$lock" ]
}

# ── AC1: section_runs is CANONICAL — it wins over a stale last_run.sections
#    entry for the same section when both are present ──

@test "section_runs entry takes precedence over an older last_run.sections entry" {
    cat > "$LEDGER" <<EOF
last_run:
  timestamp: "2020-01-01T00:00:00+00:00"
  total_seconds: 999
  ceiling_seconds: 3000
  timed_out: false
  sections:
    - name: "structure"
      seconds: 100
section_runs:
  - name: "structure"
    seconds: 400
    timestamp: "$(date -Iseconds)"
    timed_out: false
    excludes_lock_wait: true
EOF
    run_seconds
    [ "$output" = "400" ]
}

# ── AC1: an old-format ledger (pre-T-3451 shape, no section_runs: at all)
#    still parses — the fallback leg ──

@test "old-format ledger (last_run.sections only, no section_runs:) still parses" {
    cat > "$LEDGER" <<'EOF'
# Full-audit run timing - written by agents/audit/audit.sh (T-3127)
last_run:
  timestamp: "2026-09-22T17:56:41+02:00"
  total_seconds: 1556
  ceiling_seconds: 3000
  timed_out: false
  sections:
    - name: "structure"
      seconds: 268
    - name: "tree"
      seconds: 182
EOF
    run_seconds
    [ "$status" -eq 0 ]
    [ "$output" = "268" ]
    run_lock_default
    [ "$output" = "335" ]
    run_push_default
    [ "$output" = "402" ]
}

@test "old-format ledger: timed_out fallback for push-timeout still reads the last_run-level flag" {
    cat > "$LEDGER" <<'EOF'
last_run:
  timestamp: "2026-09-22T17:56:41+02:00"
  total_seconds: 1556
  ceiling_seconds: 3000
  timed_out: true
  sections:
    - name: "structure"
      seconds: 268
EOF
    run_push_default
    [ "$output" = "650" ]   # timed_out -> fallback, unchanged T-3450 behaviour
    run_lock_default
    [ "$output" = "335" ]   # lock-wait ignores timed_out, unchanged T-3421 behaviour
}

@test "a section_runs entry's OWN timed_out does not leak into an unrelated section's trust" {
    # 'tree' timed out; 'structure' did not. fw_audit_timing_last_run_timed_out
    # (used by push-timeout for 'structure') must say false here — a naive
    # 'grep timed_out: true anywhere in the file' would wrongly say true.
    cat > "$LEDGER" <<EOF
section_runs:
  - name: "tree"
    seconds: 50
    timestamp: "$(date -Iseconds)"
    timed_out: true
    excludes_lock_wait: true
  - name: "structure"
    seconds: 325
    timestamp: "$(date -Iseconds)"
    timed_out: false
    excludes_lock_wait: true
EOF
    run bash -c "source '$LIB'; fw_audit_timing_last_run_timed_out '$TEST_TEMP_DIR'"
    [ "$status" -eq 1 ]
    run_push_default
    [ "$output" = "488" ]   # trusts 325, does not fall back to 650
}

# ── AC4: writer round-trip — a scoped run's record survives a later full
#    run's write, and vice versa. Extraction convention per T-3202: sed the
#    shipped functions out of audit.sh rather than reimplementing them. ──

_extract_fn() {
    sed -n "/^$1() {\$/,/^}\$/p" "$AUDIT"
}

@test "a scoped run's section_runs entry survives a later full run's last_run: write" {
    _extract_fn "_audit_record_section_run" > "$TEST_TEMP_DIR/record.sh"
    _extract_fn "_audit_write_timing_yaml" > "$TEST_TEMP_DIR/write.sh"
    [ -s "$TEST_TEMP_DIR/record.sh" ]
    [ -s "$TEST_TEMP_DIR/write.sh" ]

    # Step 1: a scoped `--section structure` run records its own measurement.
    bash -c "
        AUDIT_TIMING_FILE='$LEDGER'
        source '$TEST_TEMP_DIR/record.sh'
        _audit_record_section_run structure 325 0
    "
    run_seconds
    [ "$output" = "325" ]

    # Step 2: a full run completes later, writing its own last_run: summary
    # (a DIFFERENT structure measurement, e.g. 300s this time) — must not
    # drop the section_runs: block built in step 1's entry for other
    # sections, and its own last_run.sections.structure entry now competes
    # with (and loses to, being older by construction here) section_runs.
    bash -c "
        AUDIT_TIMING_FILE='$LEDGER'
        AUDIT_RUN_START_ISO='2020-01-01T00:00:00+00:00'
        AUDIT_TIMEOUT=3000
        declare -a SECTION_NAMES=('structure' 'tree')
        declare -a SECTION_DURATIONS=(300 50)
        source '$TEST_TEMP_DIR/write.sh'
        _audit_write_timing_yaml 0 '' 350
    "
    grep -q '^last_run:' "$LEDGER"
    grep -q '^section_runs:' "$LEDGER"
    # section_runs (fresher, from step 1) still wins over the full run's own
    # (older-timestamped, by construction of this test) last_run.sections entry.
    run_seconds
    [ "$output" = "325" ]
}

@test "the TERM-trap kill path records the in-flight section into section_runs regardless of scope" {
    grep -q '_audit_record_section_run "\$_SECTION_MARK_NAME" "\$(( SECONDS - _SECTION_MARK_START ))" 1' "$AUDIT"
}

@test "section_mark records every completed section via _audit_record_section_run" {
    grep -q '_audit_record_section_run "\$_SECTION_MARK_NAME" "\$_dur" 0' "$AUDIT"
}

# ── AC1, the fix itself: the TRAILING flush must run on scoped runs too.
#
#    `section_mark ""` closes the section opened before it, so on a
#    `--section structure` run — exactly what the pre-push hook executes —
#    the one section that matters is only ever closed by this trailing call.
#    While it sat inside the full-runs-only `if`, a scoped run measured its
#    section and then threw the measurement away, which is why the ledger
#    went stale while the gate paid a cost nobody recorded.
#
#    This is a POSITIONAL fix, so a grep for the call is not enough — the
#    call existed before, on the wrong side of the guard. Both legs are
#    pinned so they stay tellable apart: the flush must escape the guard,
#    and `_audit_write_timing_yaml` must stay inside it (a scoped run's
#    total_seconds answers a different question than the full-run ceiling).

_extract_trailing_flush() {
    sed -n '/^section_mark ""$/,/^fi$/p' "$AUDIT"
}

@test "trailing flush: the block extracts, and section_mark comes BEFORE the guard opens" {
    _extract_trailing_flush > "$TEST_TEMP_DIR/tail.sh"
    [ -s "$TEST_TEMP_DIR/tail.sh" ]
    # First line, column 0 — outside the guard, not indented within it.
    [ "$(head -1 "$TEST_TEMP_DIR/tail.sh")" = 'section_mark ""' ]
    # And the guard really is the next thing, so this is the right block.
    grep -q '^if \[ -z "\$SECTIONS" \]; then' "$TEST_TEMP_DIR/tail.sh"
}

# Run the real extracted block with both collaborators stubbed, and record
# which of them fired. Scope is the only variable between the two legs.
_run_trailing_flush_with_scope() {
    _extract_trailing_flush > "$TEST_TEMP_DIR/tail.sh"
    bash -c "
        SECTIONS='$1'
        SECONDS=42
        section_mark() { echo 'FLUSH'; }
        _audit_write_timing_yaml() { echo 'SUMMARY'; }
        source '$TEST_TEMP_DIR/tail.sh'
    "
}

@test "trailing flush: a SCOPED run flushes its last section but writes no full-run summary" {
    run _run_trailing_flush_with_scope "structure"
    [ "$status" -eq 0 ]
    [[ "$output" == *"FLUSH"* ]]
    # The regression leg: before the fix this said nothing at all.
    [[ "$output" != *"SUMMARY"* ]]
}

@test "trailing flush: a FULL run flushes its last section AND writes the full-run summary" {
    run _run_trailing_flush_with_scope ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"FLUSH"* ]]
    [[ "$output" == *"SUMMARY"* ]]
}

@test "trailing flush: the t3070 sed anchor still resolves to its own block, not this one" {
    # t3070 extracts the AUDIT_TIMEOUT resolution block by an exact-line sed
    # match on `if [ -z "$SECTIONS" ]; then`. The guard line here carries a
    # trailing comment precisely so it does NOT match that anchor and pull
    # this block into t3070's extraction. Pin that, or the next person to
    # "tidy" the comment away breaks a test in a different file.
    run grep -c '^if \[ -z "\$SECTIONS" \]; then$' "$AUDIT"
    [ "$output" = "1" ]
}

# ── AC3: lock contention is explicitly excluded from the measurement, and
#    the writer says so in the recorded value ──

@test "the writer records excludes_lock_wait: true on every section_runs entry" {
    _extract_fn "_audit_record_section_run" > "$TEST_TEMP_DIR/record.sh"
    bash -c "
        AUDIT_TIMING_FILE='$LEDGER'
        source '$TEST_TEMP_DIR/record.sh'
        _audit_record_section_run structure 325 0
    "
    grep -q 'excludes_lock_wait: true' "$LEDGER"
}

# ── AC2: staleness is visible — fw_audit_timing_is_stale, both legs pinned
#    distinguishably (a guard that never fires and one that fires correctly
#    must be tellable apart) ──

@test "fw_audit_timing_is_stale: fresh measurement (just now) is NOT stale at the 7-day default" {
    cat > "$LEDGER" <<EOF
section_runs:
  - name: "structure"
    seconds: 325
    timestamp: "$(date -Iseconds)"
    timed_out: false
    excludes_lock_wait: true
EOF
    run_is_stale 7
    [ "$status" -eq 1 ]
}

@test "fw_audit_timing_is_stale: a 10-day-old measurement IS stale at the 7-day default" {
    cat > "$LEDGER" <<EOF
section_runs:
  - name: "structure"
    seconds: 325
    timestamp: "$(date -d '-10 days' -Iseconds)"
    timed_out: false
    excludes_lock_wait: true
EOF
    run_is_stale 7
    [ "$status" -eq 0 ]
}

@test "fw_audit_timing_is_stale: an unmeasured section counts as stale (no silent trust of nothing)" {
    cat > "$LEDGER" <<'EOF'
section_runs:
  - name: "tree"
    seconds: 50
    timestamp: "2026-01-01T00:00:00Z"
    timed_out: false
EOF
    run_is_stale 7
    [ "$status" -eq 0 ]
}

@test "AUDIT_STRUCTURE_TIMING_STALE_DAYS is registered with a description (config-registry-parity)" {
    grep -q '"AUDIT_STRUCTURE_TIMING_STALE_DAYS|7|' "$FRAMEWORK_ROOT/lib/config.sh"
}

# ── AC2: fw doctor wires the WARN/OK — extracted block, both legs pinned ──

_run_doctor_block() {
    # $1 = ledger timestamp to write for 'structure'
    cat > "$LEDGER" <<EOF
section_runs:
  - name: "structure"
    seconds: 325
    timestamp: "$1"
    timed_out: false
    excludes_lock_wait: true
EOF
    sed -n '/# T-3451-STRUCTURE-STALENESS-START/,/# T-3451-STRUCTURE-STALENESS-END/p' "$FW" > "$TEST_TEMP_DIR/block.sh"
    [ -s "$TEST_TEMP_DIR/block.sh" ] || return 91
    bash -c "
        source '$LIB'
        RED=''; NC=''; YELLOW='YELLOW:'; GREEN='GREEN:'; CYAN='CYAN:'
        PROJECT_ROOT='$TEST_TEMP_DIR'
        warnings=0
        fw_config() { echo \"\$2\"; }
        source '$TEST_TEMP_DIR/block.sh'
        echo \"warnings=\$warnings\"
    "
}

@test "doctor: structure-timing WARN fires on a stale (10-day-old) measurement" {
    run _run_doctor_block "$(date -d '-10 days' -Iseconds)"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'YELLOW:.*Structure-section timing is'
    echo "$output" | grep -q 'warnings=1'
}

@test "doctor: structure-timing check is silent (OK, no WARN) on a fresh measurement" {
    run _run_doctor_block "$(date -Iseconds)"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'GREEN:.*Structure-section timing is current'
    echo "$output" | grep -q 'warnings=0'
    # T-3138/T-3191 dead-negation lint: a bare `! cmd` must be the test's LAST
    # statement (or ||-guarded) or its failure never fails the test. Last on
    # purpose here.
    ! echo "$output" | grep -q 'YELLOW:'
}

@test "doctor: unmeasured structure timing is an INFO, not a WARN, and does not count as an issue" {
    rm -f "$LEDGER"
    sed -n '/# T-3451-STRUCTURE-STALENESS-START/,/# T-3451-STRUCTURE-STALENESS-END/p' "$FW" > "$TEST_TEMP_DIR/block.sh"
    run bash -c "
        source '$LIB'
        RED=''; NC=''; YELLOW='YELLOW:'; GREEN='GREEN:'; CYAN='CYAN:'
        PROJECT_ROOT='$TEST_TEMP_DIR'
        warnings=0
        fw_config() { echo \"\$2\"; }
        source '$TEST_TEMP_DIR/block.sh'
        echo \"warnings=\$warnings\"
    "
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'CYAN:.*not measured yet'
    echo "$output" | grep -q 'warnings=0'
}
