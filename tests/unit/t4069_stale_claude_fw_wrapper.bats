#!/usr/bin/env bats
# T-4069: a claude-fw wrapper started before bin/claude-fw changed keeps the old
# code (bash loaded it). The helper must flag it; other projects' wrappers and
# untouched wrappers must not be reported. Fixtures are sleeping bash processes
# of our own; nothing real is signalled.

HELPER="$BATS_TEST_DIRNAME/../../lib/stale_claude_fw.py"

setup() {
    PA="$BATS_TEST_TMPDIR/projA"; PB="$BATS_TEST_TMPDIR/projB"
    for p in "$PA" "$PB"; do
        mkdir -p "$p/bin"
        printf '#!/bin/bash\nsleep 120\n' > "$p/bin/claude-fw"
        chmod +x "$p/bin/claude-fw"
        touch -d '1 hour ago' "$p/bin/claude-fw"
    done
    PIDS=""
}

teardown() {
    # only the fixture pids this test started
    for p in $PIDS; do kill "$p" 2>/dev/null || true; done
}

start_wrapper() {  # start_wrapper <project>; sets WPID
    (cd "$1" && exec bash "$1/bin/claude-fw" -c) >/dev/null 2>&1 3>&- &
    WPID=$!
    PIDS="$PIDS $WPID"
    sleep 0.5
}

@test "untouched wrapper is not stale" {
    start_wrapper "$PA"
    run python3 "$HELPER" "$PA"
    [ "$status" -eq 0 ]
    [[ "$output" == "$WPID"$'\t'* ]]
    [ "$(echo "$output" | awk -F'\t' '{print $5}')" = "0" ]
}

@test "script touched newer than the start flags the wrapper stale" {
    start_wrapper "$PA"
    touch -d '+1 hour' "$PA/bin/claude-fw"
    run python3 "$HELPER" "$PA" --stale-only
    [ "$status" -eq 0 ]
    [[ "$output" == "$WPID"$'\t'* ]]
    [ "$(echo "$output" | awk -F'\t' '{print $5}')" = "1" ]
}

@test "another project's wrapper is not reported" {
    start_wrapper "$PB"
    touch -d '+1 hour' "$PB/bin/claude-fw"
    run python3 "$HELPER" "$PA"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "doctor wires the check and the upgrade/vendor notice" {
    grep -q 'stale_claude_fw.py' "$BATS_TEST_DIRNAME/../../bin/fw"
    grep -q '_t4069_stale_wrapper_notice' "$BATS_TEST_DIRNAME/../../lib/upgrade.sh"
}
