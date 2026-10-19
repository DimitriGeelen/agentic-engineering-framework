#!/usr/bin/env bats
# T-4400: fw init's T-000 bootstrap commit stages the whole vendored framework
# (~3,800 new paths, ~57 MB of added lines) and the pre-commit secret scan took
# 92-198 s on it. The regexes were never the cost (< 1 s over the stream as a
# file): scan_staged held the diff in bash variables and re-echoed it once per
# pattern, and the name axis forked three processes per new path.
#
# The fix keeps the scan's coverage identical, so this file pins both halves:
# a bootstrap-scale commit scans within a bound, and a secret planted in that
# same commit is still caught — in a project file and in a vendored file.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    R="$TEST_TEMP_DIR/repo"
    mkdir -p "$R" && git -C "$R" init -q
    SCAN="$FRAMEWORK_ROOT/agents/git/lib/secret-scan.sh"
    cp "$FRAMEWORK_ROOT/.secret-scan-patterns" "$R/.secret-scan-patterns"
    export PROJECT_ROOT="$R"
    unset FW_SECRET_SCAN_STRICT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Bootstrap shape: thousands of new vendored paths plus a multi-MB diff.
_stage_bootstrap_scale() {
    local v="$R/.agentic-framework/agents"
    mkdir -p "$v"
    (cd "$v" && awk 'BEGIN { for (d = 0; d < 30; d++) { system("mkdir -p d" d);
        for (i = 0; i < 100; i++) printf "plain line %d\n", i > ("d" d "/f" i ".sh") } }')
    awk 'BEGIN { for (i = 0; i < 250000; i++) printf "line %07d plain text with no secret shape here at all\n", i }' \
        > "$R/.agentic-framework/big.txt"
    mkdir -p "$R/src"
    printf 'print("hello")\n' > "$R/src/app.py"
    git -C "$R" add -A
}

# Fake credential assembled at run time so this file holds no literal one.
_fake_aws() { printf 'AKIA%s' "IOSFODNN7EXAMPLQ"; }

@test "T-4400: bootstrap-scale staged commit scans within 30 s" {
    _stage_bootstrap_scale
    [ "$(git -C "$R" diff --cached --name-only | wc -l)" -ge 3000 ]
    SECONDS=0
    run bash "$SCAN" scan-staged
    local took=$SECONDS
    echo "scan-staged took ${took}s: $output"
    [ "$status" -eq 0 ]
    [ "$took" -lt 30 ]
}

@test "T-4400: a secret in a project file is caught in the same bootstrap-scale commit" {
    _stage_bootstrap_scale
    printf 'aws_key = "%s"\n' "$(_fake_aws)" >> "$R/src/app.py"
    git -C "$R" add src/app.py
    run bash "$SCAN" scan-staged
    [ "$status" -eq 1 ]
    [[ "$output" == *"[AWS Access Key] src/app.py:2:"* ]]
}

@test "T-4400: a secret in a vendored file is still caught — no path is exempted" {
    _stage_bootstrap_scale
    printf 'k=%s\n' "$(_fake_aws)" >> "$R/.agentic-framework/agents/d7/f42.sh"
    printf 'x\n' > "$R/.agentic-framework/agents/id_rsa"
    git -C "$R" add -A
    run bash "$SCAN" scan-staged
    [ "$status" -eq 1 ]
    [[ "$output" == *"[AWS Access Key] .agentic-framework/agents/d7/f42.sh:2:"* ]]
    [[ "$output" == *"[name:DEFINITIVE] .agentic-framework/agents/id_rsa"* ]]
}

@test "T-4400: a clean bootstrap-scale commit reports no hits" {
    _stage_bootstrap_scale
    run bash "$SCAN" scan-staged
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
