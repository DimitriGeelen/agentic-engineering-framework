#!/usr/bin/env bats
# T-5131 (832 T-763 / RA-052, operator ruling): a dated audit record is never overwritten. A
# second manual run on the same date moves the earlier <date>.yaml aside to
# <date>-<HHMM of its mtime>.yaml (counter on a clash); <date>.yaml is always the newest.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"; export TEST_TEMP_DIR
    AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
    D="$TEST_TEMP_DIR/audits"; mkdir -p "$D"
    BLOCK="$TEST_TEMP_DIR/naming.sh"
    # the naming block: from its header comment to the closing `fi` of the if/else
    awk '/^# Cron audits use datetime filenames/{f=1} f{print} f && /^fi$/{exit}' "$AUDIT" > "$BLOCK"
    grep -q 'T-5131' "$BLOCK" || { echo "T-5131 code not in the extracted naming block" >&2; return 1; }
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

run_naming() {  # writes a record the way audit.sh does, after its naming block
    OUTPUT_DIR="${1:-}" EFFECTIVE_OUTPUT_DIR="${1:-$D}" AUDIT_DATE=2026-11-14 AUDIT_DATETIME=2026-11-14-1700 \
        bash -c 'source "$1"; echo "run=$2" > "$AUDIT_FILE"; echo "$AUDIT_FILE"' _ "$BLOCK" "$2"
}

@test "first run writes <date>.yaml" {
    run run_naming "" one
    [ "$status" -eq 0 ]
    [ "$(cat "$D/2026-11-14.yaml")" = "run=one" ]
}

@test "a second run on the same date keeps the first record under its own time" {
    run_naming "" one >/dev/null
    touch -d "2026-11-14 09:30" "$D/2026-11-14.yaml"
    run_naming "" two >/dev/null
    [ "$(cat "$D/2026-11-14.yaml")" = "run=two" ]
    [ "$(cat "$D/2026-11-14-0930.yaml")" = "run=one" ]
}

@test "a third run with the same HHMM keeps both earlier records (counter)" {
    run_naming "" one >/dev/null; touch -d "2026-11-14 09:30" "$D/2026-11-14.yaml"
    run_naming "" two >/dev/null; touch -d "2026-11-14 09:30" "$D/2026-11-14.yaml"
    run_naming "" three >/dev/null
    [ "$(cat "$D/2026-11-14.yaml")" = "run=three" ]
    [ "$(cat "$D/2026-11-14-0930.yaml")" = "run=one" ]
    [ "$(cat "$D/2026-11-14-0930-2.yaml")" = "run=two" ]
    [ "$(ls "$D" | wc -l)" -eq 3 ]
}

@test "cron runs (OUTPUT_DIR) keep their datetime name and move nothing" {
    C="$TEST_TEMP_DIR/cron"; mkdir -p "$C"
    echo existing > "$C/2026-11-14.yaml"
    run run_naming "$C" cron
    [[ "$output" == "$C/2026-11-14-1700.yaml" ]]
    [ "$(cat "$C/2026-11-14.yaml")" = "existing" ]
}
