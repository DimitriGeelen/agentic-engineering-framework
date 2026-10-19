#!/usr/bin/env bats
# T-4427: T-4400 sped up the pre-commit secret scan on fw init's T-000 bootstrap
# commit, but the field test could not measure it (dimitri-mint-dev T-155,
# INCONCLUSIVE): the hook swallows the scanner's output on success, so nothing
# timed the scan on its own. scan-staged now records
# "secret scan: N file(s) in S.s s" to FW_SECRET_SCAN_TIMING_FILE, and fw init
# prints it under the bootstrap-commit line. Verdicts and exit codes unchanged.

bats_require_minimum_version 1.5.0
load ../test_helper

TIMING_RE='^secret scan: [0-9]+ file\(s\) in [0-9]+\.[0-9] s$'

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    R="$TEST_TEMP_DIR/repo"
    mkdir -p "$R" && git -C "$R" init -q
    SCAN="$FRAMEWORK_ROOT/agents/git/lib/secret-scan.sh"
    cp "$FRAMEWORK_ROOT/.secret-scan-patterns" "$R/.secret-scan-patterns"
    export PROJECT_ROOT="$R"
    unset FW_SECRET_SCAN_STRICT FW_SECRET_SCAN_TIMING_FILE
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Fake credential assembled at run time so this file holds no literal one.
_fake_aws() { printf 'AKIA%s' "IOSFODNN7EXAMPLQ"; }

@test "T-4427: scan-staged writes a timing line with file count and duration" {
    printf 'a\n' > "$R/a.txt"; printf 'b\n' > "$R/b.txt"; printf 'c\n' > "$R/c.txt"
    git -C "$R" add -A
    local n; n=$(git -C "$R" diff --cached --name-only | wc -l | tr -d ' ')
    run env FW_SECRET_SCAN_TIMING_FILE="$TEST_TEMP_DIR/timing" bash "$SCAN" scan-staged
    [ "$status" -eq 0 ]
    [ -s "$TEST_TEMP_DIR/timing" ]
    run cat "$TEST_TEMP_DIR/timing"
    echo "timing: $output"
    [[ "$output" =~ $TIMING_RE ]]
    [[ "$output" == "secret scan: $n file(s) in "* ]]
}

@test "T-4427: verdict unchanged — a planted secret still exits 1 with timing on" {
    printf 'key = "%s"\n' "$(_fake_aws)" > "$R/creds.py"
    git -C "$R" add -A
    run env FW_SECRET_SCAN_TIMING_FILE="$TEST_TEMP_DIR/timing" bash "$SCAN" scan-staged
    [ "$status" -eq 1 ]
    [[ "$output" == *"creds.py"* ]]
    run cat "$TEST_TEMP_DIR/timing"
    [[ "$output" =~ $TIMING_RE ]]
}

@test "T-4427: no timing file is written when the variable is unset" {
    printf 'a\n' > "$R/a.txt"; git -C "$R" add -A
    run bash "$SCAN" scan-staged
    [ "$status" -eq 0 ]
    [ ! -e "$TEST_TEMP_DIR/timing" ]
    [[ "$output" != *"secret scan:"* ]]
}

@test "T-4427: fw init prints the scan timing line after the bootstrap commit" {
    local H="$TEST_TEMP_DIR/init"
    mkdir -p "$H/home" "$H/fresh"
    # Fence git discovery at the fixture (T-3603) and keep the operator's
    # identity out of it, as init_head_bootstrap.bats does.
    run env -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL -u GIT_COMMITTER_NAME -u GIT_COMMITTER_EMAIL \
        GIT_CEILING_DIRECTORIES="$H" HOME="$H/home" GIT_CONFIG_GLOBAL="$H/no-such-gitconfig" \
        "$FRAMEWORK_ROOT/bin/fw" init "$H/fresh" --provider generic
    echo "$output" | grep -E "Bootstrap commit|secret scan:" || true
    [[ "$output" == *"Bootstrap commit created"* ]]
    local line
    line=$(echo "$output" | grep -E '^ +secret scan: ' | sed 's/^ *//')
    [[ "$line" =~ $TIMING_RE ]]
    # The file count is the bootstrap commit's own, not zero.
    local n; n=$(echo "$line" | sed -E 's/^secret scan: ([0-9]+) .*/\1/')
    [ "$n" -gt 0 ]
    [ "$n" -eq "$(git -C "$H/fresh" show --name-only --format= HEAD | grep -c .)" ]
    # The timing file lives outside the project and is never committed.
    ! git -C "$H/fresh" show --name-only --format= HEAD | grep -q "scan-timing" || false
}
