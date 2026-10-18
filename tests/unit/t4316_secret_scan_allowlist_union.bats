#!/usr/bin/env bats
# T-4316 — the secret-scan allowlist is the UNION of the project-root file and
# the allowlist next to the pattern catalogue.
#
# Origin: 055 (their T-545). _secret_scan_config_dir picks ONE directory for
# patterns and allowlist: the project root only when it has its own
# .secret-scan-patterns, else .agentic-framework/. A consumer keeping the shipped
# patterns could therefore only allowlist by editing the vendored copy, which
# fw upgrade replaces — the entries silently vanished. The split case (patterns
# vendored, allowlist local) was never exercised: every other test copies both
# files into the repo root.
#
# Fixture strings are synthesized to MATCH the patterns; they are not secrets.
# They are assembled at run time (printf pieces) so this file itself carries no
# pattern-shaped literal and needs no entry in .secret-scan-allowlist.

load ../test_helper

SCANNER="$FRAMEWORK_ROOT/agents/git/lib/secret-scan.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    TEST_REPO="$TEST_TEMP_DIR/repo"
    mkdir -p "$TEST_REPO/.agentic-framework"
    cd "$TEST_REPO"
    git init -q
    git config user.email "test@local"
    git config user.name "test"
    git config commit.gpgsign false
    # Consumer layout: patterns ONLY in the vendored copy, none at the root.
    cp "$FRAMEWORK_ROOT/.secret-scan-patterns" "$TEST_REPO/.agentic-framework/.secret-scan-patterns"
    echo "ok" > README.md
    git add README.md
    git commit -q -m "T-0: init"
}

teardown() {
    cd /
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_scan() { PROJECT_ROOT="$TEST_REPO" bash "$SCANNER" "$@"; }

_track_leak() {
    printf 'config: %s%s end\n' AKIA IOSFODNN7EXAMPLE > "$TEST_REPO/leak.txt"
    git -C "$TEST_REPO" add leak.txt
}

@test "T-4316: project-root allowlist suppresses scan-staged while patterns are vendored" {
    _track_leak
    run _scan scan-staged
    [ "$status" -eq 1 ]
    echo '^leak\.txt:' > "$TEST_REPO/.secret-scan-allowlist"
    run _scan scan-staged
    [ "$status" -eq 0 ]
}

@test "T-4316: project-root allowlist suppresses scan-tree while patterns are vendored" {
    _track_leak
    git -C "$TEST_REPO" commit -q -m "T-0: leak"
    run _scan scan-tree
    [ "$status" -eq 1 ]
    echo '^leak\.txt:' > "$TEST_REPO/.secret-scan-allowlist"
    run _scan scan-tree
    [ "$status" -eq 0 ]
}

@test "T-4316: project-root allowlist suppresses scan-file while patterns are vendored" {
    _track_leak
    run _scan scan-file leak.txt
    [ "$status" -eq 1 ]
    echo '^leak\.txt:' > "$TEST_REPO/.secret-scan-allowlist"
    run _scan scan-file leak.txt
    [ "$status" -eq 0 ]
}

@test "T-4316: project-root allowlist suppresses scan-names while patterns are vendored" {
    echo "x" > "$TEST_REPO/deploy.pem"
    git -C "$TEST_REPO" add -f deploy.pem
    git -C "$TEST_REPO" commit -q -m "T-0: pem"
    run _scan scan-names
    [ "$status" -eq 1 ]
    echo '^deploy\.pem:' > "$TEST_REPO/.secret-scan-allowlist"
    run _scan scan-names
    [ "$status" -eq 0 ]
}

@test "T-4316: vendored allowlist still applies (union, not replacement)" {
    _track_leak
    echo '^leak\.txt:' > "$TEST_REPO/.agentic-framework/.secret-scan-allowlist"
    # An unrelated project-root entry must not shadow the vendored one.
    echo '^unrelated/' > "$TEST_REPO/.secret-scan-allowlist"
    run _scan scan-staged
    [ "$status" -eq 0 ]
}

@test "T-4316: entries from both files are each honoured" {
    _track_leak
    printf 'token: %s_%s end\n' ghp aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa > "$TEST_REPO/gh.txt"
    git -C "$TEST_REPO" add gh.txt
    echo '^leak\.txt:' > "$TEST_REPO/.agentic-framework/.secret-scan-allowlist"
    echo '^gh\.txt:'   > "$TEST_REPO/.secret-scan-allowlist"
    run _scan scan-staged
    [ "$status" -eq 0 ]
    # Drop the root entry: gh.txt must surface again.
    rm "$TEST_REPO/.secret-scan-allowlist"
    run _scan scan-staged
    [ "$status" -eq 1 ]
    [[ "$output" == *"gh.txt"* ]]
}

@test "T-4316: neither allowlist present — scanner still runs and reports" {
    _track_leak
    run _scan scan-staged
    [ "$status" -eq 1 ]
    [[ "$output" == *"leak.txt"* ]]
}

@test "T-4316: block message names the project-root allowlist" {
    run grep -n 'secret-scan-allowlist' "$FRAMEWORK_ROOT/agents/git/lib/hooks.sh"
    [[ "$output" == *"project root"* ]]
}
