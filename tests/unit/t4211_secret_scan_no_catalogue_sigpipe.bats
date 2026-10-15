#!/usr/bin/env bats
# T-4211: with no .secret-scan-patterns, `_secret_scan_run_patterns` returned without
# reading stdin. The `echo "$diff_stream" |` feeding it died of SIGPIPE whenever the
# staged diff outgrew the pipe buffer (or lost the race on a loaded host), pipefail made
# the pipeline non-zero, and the pre-commit hook reported "detected matches" with none —
# flaky fixture commits in t3511/t3110 under the parallel unit suite.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    R="$TEST_TEMP_DIR/repo"
    mkdir -p "$R" && cd "$R" && git init -q && git config user.email t@t && git config user.name t
    SCAN="$FRAMEWORK_ROOT/agents/git/lib/secret-scan.sh"
    printf 'seed\n' > "$R/seed.txt" && git -C "$R" add seed.txt && git -C "$R" commit -qm init
    export PROJECT_ROOT="$R"
    unset FW_SECRET_SCAN_STRICT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_stage_big_file() {
    # ~400 KB of added lines: far beyond a 64 KB pipe buffer, so an unread pipe
    # always kills the writer.
    awk 'BEGIN { for (i = 0; i < 8000; i++) printf "line %06d plain text with no secret shape here\n", i }' > "$R/big.txt"
    git -C "$R" add big.txt
}

@test "T-4211: scan-staged with no catalogue fails open (0) on a staged diff larger than a pipe buffer" {
    _stage_big_file
    for _ in 1 2 3; do
        run bash "$SCAN" scan-staged
        [ "$status" -eq 0 ]
        [[ "$output" == *"RUNNING WITHOUT PATTERNS"* ]]
    done
}

@test "T-4211: strict mode still blocks a large staged diff when the catalogue is missing" {
    _stage_big_file
    FW_SECRET_SCAN_STRICT=1 run bash "$SCAN" scan-staged
    [ "$status" -ne 0 ]
    [[ "$output" == *"FW_SECRET_SCAN_STRICT=1"* ]]
}
