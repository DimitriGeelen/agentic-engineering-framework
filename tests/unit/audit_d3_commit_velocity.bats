#!/usr/bin/env bats
# D3 commit-velocity anomaly check (agents/audit/audit.sh embedded python).
# Origin: T-100123 — drop WARN fired at 01:02 local ("today=5 avg=55") because
# a partial day was compared against full-day averages. Fix prorates the drop
# threshold by fraction-of-day elapsed and skips the drop check before 06:00.
#
# The tests extract the D3EOF python block from audit.sh, pin the clock via a
# mechanical datetime.now() -> FAKE_NOW substitution, and feed commit dates
# through a fake `git` on PATH.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
AUDIT_SH="$FRAMEWORK_ROOT/agents/audit/audit.sh"

setup() {
    TEST_DIR="$BATS_TMPDIR/fw_d3_test_$$"
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/git" <<'FAKEGIT'
#!/bin/bash
cat "$FAKE_GIT_LOG_FILE"
FAKEGIT
    chmod +x "$TEST_DIR/bin/git"
    export PATH="$TEST_DIR/bin:$PATH"
    export FAKE_GIT_LOG_FILE="$TEST_DIR/gitlog.txt"
}

teardown() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}

# Emit N commit dates for a given day (local +02:00 offset, midday)
emit_day() {  # $1=YYYY-MM-DD $2=count
    for _ in $(seq 1 "$2"); do
        echo "${1}T12:00:00+02:00" >> "$FAKE_GIT_LOG_FILE"
    done
}

# Extract the D3 python block, pin the clock to $FAKE_NOW, run it.
run_d3() {
    python3 - "$AUDIT_SH" <<'PYEOF'
import re, sys, os
src = open(sys.argv[1]).read()
m = re.search(r"d3_result=\$\(python3 << 'D3EOF'\n(.*?)\nD3EOF", src, re.S)
if not m:
    print("SKIP d3_block_not_found"); sys.exit(1)
code = m.group(1)
code = code.replace("datetime.now()",
                    "datetime.fromisoformat(os.environ['FAKE_NOW'])")
code = "import os\n" + code
exec(compile(code, "d3", "exec"))
PYEOF
}

seed_seven_busy_days() {
    : > "$FAKE_GIT_LOG_FILE"
    for d in 2026-06-27 2026-06-28 2026-06-29 2026-06-30 2026-07-01 2026-07-02 2026-07-03; do
        emit_day "$d" 55
    done
}

@test "T-100123 regression: 5 commits at 01:02 with avg=55 is PASS (no midnight-window drop WARN)" {
    seed_seven_busy_days
    emit_day 2026-07-04 5
    export FAKE_NOW="2026-07-04T01:02:00"
    run run_d3
    [ "$status" -eq 0 ]
    [[ "$output" == PASS* ]]
    [[ "$output" != *"drop"* ]]
}

@test "genuine drop still fires: 5 commits by 18:00 with avg=55 is WARN drop (prorated)" {
    seed_seven_busy_days
    emit_day 2026-07-04 5
    export FAKE_NOW="2026-07-04T18:00:00"
    run run_d3
    [ "$status" -eq 0 ]
    [[ "$output" == "WARN drop"* ]]
    [[ "$output" == *"expected_by_now="* ]]
}

@test "spike fires regardless of time of day: 130 commits at 01:02 with avg=55 is WARN spike" {
    seed_seven_busy_days
    emit_day 2026-07-04 130
    export FAKE_NOW="2026-07-04T01:02:00"
    run run_d3
    [ "$status" -eq 0 ]
    [[ "$output" == "WARN spike"* ]]
}

@test "on-pace day is PASS: 30 commits by 12:00 with avg=55" {
    seed_seven_busy_days
    emit_day 2026-07-04 30
    export FAKE_NOW="2026-07-04T12:00:00"
    run run_d3
    [ "$status" -eq 0 ]
    [[ "$output" == PASS* ]]
}
