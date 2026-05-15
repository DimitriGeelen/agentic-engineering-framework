#!/usr/bin/env bats
# T-1844 — pre-commit secret-scan hook (agents/git/lib/secret-scan.sh).
#
# Origin: T-1828/T-1834 — an Azure DevOps PAT was committed at 79e3361d
# (T-1736 Spike B, 2026-05-05). GitHub mirror has been GH013-blocked for
# 9+ hours. The framework had no structural gate against secrets reaching
# commits. These tests pin the scanner's pattern catalogue + allowlist
# semantics and the hook's bypass behaviour.
#
# IMPORTANT: This file contains pattern-shaped strings used as test
# fixtures. The .secret-scan-allowlist exempts this file by path so
# the scanner doesn't self-trigger when running on the repo. The strings
# below are synthesized to MATCH the patterns but are not real secrets.

load ../test_helper

SCANNER="$FRAMEWORK_ROOT/agents/git/lib/secret-scan.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    TEST_REPO="$TEST_TEMP_DIR/repo"
    mkdir -p "$TEST_REPO"
    cd "$TEST_REPO"
    git init -q
    git config user.email "test@local"
    git config user.name "test"
    git config commit.gpgsign false
    # Bring framework's patterns + allowlist into the test repo so the
    # scanner's config-resolution finds them at $TEST_REPO root.
    cp "$FRAMEWORK_ROOT/.secret-scan-patterns" "$TEST_REPO/.secret-scan-patterns"
    cp "$FRAMEWORK_ROOT/.secret-scan-allowlist" "$TEST_REPO/.secret-scan-allowlist"
    # Initial commit so subsequent `git diff --cached` against HEAD~ works.
    echo "ok" > README.md
    git add README.md .secret-scan-patterns .secret-scan-allowlist
    git -c commit.gpgsign=false commit -q -m "T-0: init"
}

teardown() {
    cd /
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: stage a file with given content and invoke scan-staged.
# Returns the scanner's exit code; output captured into $output via run.
_stage_and_scan() {
    local path="$1" content="$2"
    printf '%s\n' "$content" > "$TEST_REPO/$path"
    git -C "$TEST_REPO" add "$path"
    PROJECT_ROOT="$TEST_REPO" "$SCANNER" scan-staged
}

# --- Source-level markers ---

@test "T-1844: scanner exists and is executable" {
    [ -x "$SCANNER" ]
}

@test "T-1844: pattern catalogue exists with required entries" {
    [ -f "$FRAMEWORK_ROOT/.secret-scan-patterns" ]
    run grep -q "Azure DevOps PAT" "$FRAMEWORK_ROOT/.secret-scan-patterns"
    [ "$status" -eq 0 ]
    run grep -q "AWS Access Key" "$FRAMEWORK_ROOT/.secret-scan-patterns"
    [ "$status" -eq 0 ]
    run grep -q "SSH Private Key" "$FRAMEWORK_ROOT/.secret-scan-patterns"
    [ "$status" -eq 0 ]
    run grep -q "GitHub PAT" "$FRAMEWORK_ROOT/.secret-scan-patterns"
    [ "$status" -eq 0 ]
}

@test "T-1844: allowlist exists" {
    [ -f "$FRAMEWORK_ROOT/.secret-scan-allowlist" ]
}

# --- Case: clean diff is allowed ---

@test "T-1844 case a: clean diff is allowed" {
    run _stage_and_scan "clean.txt" "nothing to see here, just plain text"
    [ "$status" -eq 0 ]
}

# --- Case: AWS Access Key shape blocked ---

@test "T-1844 case b: AWS Access Key shape is blocked" {
    # Synthesized — not a real AWS key.
    run _stage_and_scan "aws.txt" "config: AKIAIOSFODNN7EXAMPLE end"
    [ "$status" -ne 0 ]
    [[ "$output" == *"AWS Access Key"* ]]
}

# --- Case: GitHub PAT shape blocked ---

@test "T-1844 case c: GitHub PAT shape is blocked" {
    run _stage_and_scan "gh.txt" "token: ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa end"
    [ "$status" -ne 0 ]
    [[ "$output" == *"GitHub PAT"* ]]
}

# --- Case: SSH private key header blocked ---

@test "T-1844 case d: SSH private key header is blocked" {
    run _stage_and_scan "id.pem" "-----BEGIN OPENSSH PRIVATE KEY-----
fake_body
-----END OPENSSH PRIVATE KEY-----"
    [ "$status" -ne 0 ]
    [[ "$output" == *"SSH Private Key"* ]]
}

# --- Case: Anthropic API key blocked ---

@test "T-1844 case e: Anthropic API key shape is blocked" {
    run _stage_and_scan "ant.txt" "ANTHROPIC_API_KEY=sk-ant-aaaaaaaaaaaaaaaaaaaaa"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Anthropic API Key"* ]]
}

# --- Case: allowlist suppresses a match ---

@test "T-1844 case f: allowlisted path suppresses match" {
    # Append an allowlist entry that exempts allowlisted/ paths
    echo "^allowlisted/" >> "$TEST_REPO/.secret-scan-allowlist"
    git -C "$TEST_REPO" add .secret-scan-allowlist
    git -C "$TEST_REPO" -c commit.gpgsign=false commit -q -m "T-0: extend allowlist"
    mkdir -p "$TEST_REPO/allowlisted"
    # Now stage a file in the allowlisted path that contains an AWS key shape
    run _stage_and_scan "allowlisted/test.txt" "AKIAIOSFODNN7EXAMPLE inside an allowlisted path"
    [ "$status" -eq 0 ]
}

# --- Case: bypass via --no-verify works (synthetic repo) ---

@test "T-1844 case g: git commit --no-verify bypasses the hook" {
    # Install the framework's pre-commit hook into the test repo
    mkdir -p "$TEST_REPO/.git/hooks"
    cp "$FRAMEWORK_ROOT/.git/hooks/pre-commit" "$TEST_REPO/.git/hooks/pre-commit"
    chmod +x "$TEST_REPO/.git/hooks/pre-commit"
    # The hook resolves the scanner via $FRAMEWORK_ROOT/agents/git/lib/secret-scan.sh,
    # falling back to $PROJECT_ROOT/.agentic-framework/.... In a synthetic test
    # repo neither exists, so set up the consumer-vendored layout:
    mkdir -p "$TEST_REPO/.agentic-framework/agents/git/lib"
    cp "$FRAMEWORK_ROOT/agents/git/lib/secret-scan.sh" "$TEST_REPO/.agentic-framework/agents/git/lib/secret-scan.sh"
    chmod +x "$TEST_REPO/.agentic-framework/agents/git/lib/secret-scan.sh"
    cp "$FRAMEWORK_ROOT/.secret-scan-patterns" "$TEST_REPO/.agentic-framework/.secret-scan-patterns"
    cp "$FRAMEWORK_ROOT/.secret-scan-allowlist" "$TEST_REPO/.agentic-framework/.secret-scan-allowlist"
    # Stage a file with an AWS key shape
    echo "AKIAIOSFODNN7EXAMPLE" > "$TEST_REPO/leak.txt"
    git -C "$TEST_REPO" add leak.txt
    # Without --no-verify, the commit should be blocked
    run git -C "$TEST_REPO" -c commit.gpgsign=false commit -m "T-1844: should block"
    [ "$status" -ne 0 ]
    # With --no-verify, the commit goes through
    run git -C "$TEST_REPO" -c commit.gpgsign=false commit --no-verify -m "T-1844: bypass"
    [ "$status" -eq 0 ]
}

# --- Case: scanner resolves config in consumer layout (.agentic-framework/) ---

@test "T-1844 case h: scanner finds config in .agentic-framework/ vendored layout" {
    # Build a synthetic consumer: no top-level config, but .agentic-framework/ has copies
    rm -f "$TEST_REPO/.secret-scan-patterns" "$TEST_REPO/.secret-scan-allowlist"
    mkdir -p "$TEST_REPO/.agentic-framework"
    cp "$FRAMEWORK_ROOT/.secret-scan-patterns" "$TEST_REPO/.agentic-framework/.secret-scan-patterns"
    cp "$FRAMEWORK_ROOT/.secret-scan-allowlist" "$TEST_REPO/.agentic-framework/.secret-scan-allowlist"
    # Stage a file with a match — scanner should still find it via the vendored config
    echo "AKIAIOSFODNN7EXAMPLE in consumer layout" > "$TEST_REPO/leak2.txt"
    git -C "$TEST_REPO" add leak2.txt
    run bash -c "PROJECT_ROOT=$TEST_REPO $SCANNER scan-staged"
    [ "$status" -ne 0 ]
    [[ "$output" == *"AWS Access Key"* ]]
}

# --- Case: scan-tree subcommand works for audit mode ---

@test "T-1844 case i: scan-tree finds matches in tracked files" {
    # Stage a file with a match and commit it (so scan-tree sees it as tracked)
    echo "AKIAIOSFODNN7EXAMPLE in tracked file" > "$TEST_REPO/already-leaked.txt"
    git -C "$TEST_REPO" add already-leaked.txt
    git -C "$TEST_REPO" -c commit.gpgsign=false commit --no-verify -q -m "T-0: pretend pre-gate"
    run bash -c "cd $TEST_REPO && PROJECT_ROOT=$TEST_REPO $SCANNER scan-tree"
    [ "$status" -ne 0 ]
    [[ "$output" == *"AWS Access Key"* ]]
}
