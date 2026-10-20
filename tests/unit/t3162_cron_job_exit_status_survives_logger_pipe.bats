#!/usr/bin/env bats
# T-3162 — Regression: generated cron lines ended '<cmd> 2>&1 | logger -t agentic-cron',
# so the pipeline's status was logger's (always 0) and a crashed job looked
# successful to cron (G-089 / 001-CashWeb field report). The fix appends
# '; exit ${PIPESTATUS[0]}' after the logger pipe in both generators.
#
# Pins (by EXECUTING the generated line, not by reading it — L-365's ungated
# deployed → executable transition is exactly where the masking lived):
#   1. a failing job's generated line exits with the job's status
#   2. a succeeding job's generated line exits 0
#   3. stderr still reaches logger (the T-1720 gain is kept)
#   4. paused and 2>/dev/null-rewritten lines carry the same suffix
#   5. bin/fw cron generate and lib/cron_dry_run.py stay byte-identical

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    TEST_PROJECT="$TEST_TEMP_DIR/proj-t3162"
    mkdir -p "$TEST_PROJECT/.context/cron" "$TEST_TEMP_DIR/bin"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_PROJECT/.framework.yaml"
    cat > "$TEST_PROJECT/.context/cron-registry.yaml" << 'EOF'
jobs:
  - id: failing
    name: Failing job
    schedule: "*/5 * * * *"
    command: "sh -c 'echo t3162-stderr >&2; exit 7'"
    status: active
  - id: passing
    name: Passing job
    schedule: "*/5 * * * *"
    command: "true"
    status: active
  - id: quiet
    name: Quiet job
    schedule: "*/5 * * * *"
    command: "false 2>/dev/null"
    status: paused
EOF
    # logger stub: record what reached it, exit 0 like the real one
    cat > "$TEST_TEMP_DIR/bin/logger" << EOF
#!/bin/sh
cat >> "$TEST_TEMP_DIR/logger.out"
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/bin/logger"
    export PROJECT_ROOT="$TEST_PROJECT"
    CRONTAB="$TEST_PROJECT/.context/cron/agentic-audit.crontab"
    run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$status" -eq 0 ]
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# The command cron would run for job <name>: strip '# PAUSED: ', the 5 schedule
# fields and the user field from the line following '# <name>'.
_job_cmd() {
    grep -A1 -x "# $1" "$CRONTAB" | tail -1 \
        | sed -e 's/^# PAUSED: //' -e 's/^\([^ ]* \)\{5\}root //'
}

# Execute it the way cron.d does: SHELL=/bin/bash -c '<line>'
_run_job() {
    PATH="$TEST_TEMP_DIR/bin:$PATH" /bin/bash -c "$(_job_cmd "$1")"
}

@test "T-3162: a failing job's generated line exits with the job's status" {
    run _run_job "Failing job"
    [ "$status" -eq 7 ]
}

@test "T-3162: a passing job's generated line exits 0" {
    run _run_job "Passing job"
    [ "$status" -eq 0 ]
}

@test "T-3162: stderr still reaches logger" {
    run _run_job "Failing job"
    grep -q t3162-stderr "$TEST_TEMP_DIR/logger.out"
}

@test "T-3162: paused and 2>/dev/null-rewritten lines carry the suffix and propagate" {
    line=$(grep -A1 -x "# Quiet job" "$CRONTAB" | tail -1)
    [[ "$line" == "# PAUSED: "*"2>&1 | logger -t agentic-cron; exit \${PIPESTATUS[0]}" ]]
    run _run_job "Quiet job"
    [ "$status" -eq 1 ]
    [ "$(grep -c 'PIPESTATUS' "$CRONTAB")" -eq 3 ]
}

@test "T-3162: fw cron generate and lib/cron_dry_run.py are byte-identical" {
    python3 "$FRAMEWORK_ROOT/lib/cron_dry_run.py" "$TEST_PROJECT" \
        "$TEST_PROJECT/.context/cron-registry.yaml" "$FRAMEWORK_ROOT/bin/fw" \
        > "$TEST_TEMP_DIR/dry.txt"
    cmp "$TEST_TEMP_DIR/dry.txt" "$CRONTAB"
}
