#!/usr/bin/env bats
# T-1845 — pre-commit large-file gate (agents/git/lib/large-file-scan.sh).
#
# Origin: T-1834 force-push surfaced two tracked binaries — 36MB `os` PostScript
# at repo root, 78MB fw-vec-index.db sqlite-vec index — flagged by GitHub as
# oversized. T-1844 fixed the secret-scan instance of the "no-pre-commit-gate"
# class; T-1845 fixes the large-file instance. Same shape as T-1844's tests.

load ../test_helper

SCANNER="$FRAMEWORK_ROOT/agents/git/lib/large-file-scan.sh"

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
    # Bring an empty allowlist into the test repo; specific cases write their own.
    : > "$TEST_REPO/.large-file-allowlist"
    echo "ok" > README.md
    git add README.md .large-file-allowlist
    git -c commit.gpgsign=false commit -q -m "T-0: init"
}

teardown() {
    cd /
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: write `path` of exactly N bytes (zeroed), stage it, run scan-staged.
_stage_n_bytes() {
    local path="$1" bytes="$2"
    dd if=/dev/zero of="$TEST_REPO/$path" bs=1 count="$bytes" status=none 2>/dev/null
    git -C "$TEST_REPO" add "$path"
    PROJECT_ROOT="$TEST_REPO" "$SCANNER" scan-staged
}

# --- Source-level markers ---

@test "T-1845: scanner exists and is executable" {
    [ -x "$SCANNER" ]
}

@test "T-1845: scanner supports help" {
    run "$SCANNER" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"scan-staged"* ]]
    [[ "$output" == *"scan-tree"* ]]
}

# --- Threshold behaviour ---

@test "T-1845: small staged file passes (under warn threshold)" {
    run _stage_n_bytes "small.bin" 1024
    [ "$status" -eq 0 ]
}

@test "T-1845: warn-range file passes but emits warning" {
    # 2 MiB — above default 1 MiB warn, below 10 MiB block
    run _stage_n_bytes "medium.bin" $((2 * 1024 * 1024))
    [ "$status" -eq 0 ]
    [[ "$output" == *"[WARN]"* ]] || [[ "$output" == *"warn"* ]]
}

@test "T-1845: block-range file is rejected" {
    # 11 MiB — above default 10 MiB block
    run _stage_n_bytes "huge.bin" $((11 * 1024 * 1024))
    [ "$status" -ne 0 ]
    [[ "$output" == *"[BLOCK]"* ]]
}

@test "T-1845: env-var threshold override is honoured" {
    # Tighten block to 512 KiB; a 1 MiB file should now block.
    dd if=/dev/zero of="$TEST_REPO/tight.bin" bs=1 count=$((1024 * 1024)) status=none 2>/dev/null
    git -C "$TEST_REPO" add tight.bin
    run env FW_LARGE_FILE_BLOCK_BYTES=$((512 * 1024)) \
            FW_LARGE_FILE_WARN_BYTES=$((128 * 1024)) \
            PROJECT_ROOT="$TEST_REPO" "$SCANNER" scan-staged
    [ "$status" -ne 0 ]
    [[ "$output" == *"[BLOCK]"* ]]
}

# --- Allowlist behaviour ---

@test "T-1845: allowlisted path is exempt from block" {
    # Mark vendor/ as allowlisted, stage an 11 MiB file under it.
    echo '^vendor/' > "$TEST_REPO/.large-file-allowlist"
    mkdir -p "$TEST_REPO/vendor"
    dd if=/dev/zero of="$TEST_REPO/vendor/big.bin" bs=1 count=$((11 * 1024 * 1024)) status=none 2>/dev/null
    git -C "$TEST_REPO" add .large-file-allowlist vendor/big.bin
    run env PROJECT_ROOT="$TEST_REPO" "$SCANNER" scan-staged
    [ "$status" -eq 0 ]
}

# --- scan-tree behaviour ---

@test "T-1845: scan-tree on clean repo returns 0" {
    run env PROJECT_ROOT="$TEST_REPO" "$SCANNER" scan-tree
    [ "$status" -eq 0 ]
}

@test "T-1845: scan-tree finds an already-tracked block-range file" {
    dd if=/dev/zero of="$TEST_REPO/tracked-big.bin" bs=1 count=$((11 * 1024 * 1024)) status=none 2>/dev/null
    git -C "$TEST_REPO" add tracked-big.bin
    git -C "$TEST_REPO" -c commit.gpgsign=false commit -q -m "T-0: add big"
    run env PROJECT_ROOT="$TEST_REPO" "$SCANNER" scan-tree
    [ "$status" -ne 0 ]
    [[ "$output" == *"[BLOCK]"* ]]
    [[ "$output" == *"tracked-big.bin"* ]]
}

# --- Framework integration markers ---

@test "T-1845: allowlist exists in framework root" {
    [ -f "$FRAMEWORK_ROOT/.large-file-allowlist" ]
}

@test "T-1845: pre-commit hook generator references the scanner" {
    run grep -q "large-file-scan" "$FRAMEWORK_ROOT/agents/git/lib/hooks.sh"
    [ "$status" -eq 0 ]
}

@test "T-1845: real repo scan-tree is clean post-cleanup" {
    # Validates that os + fw-vec-index.db are untracked and no other
    # tracked file exceeds the block threshold.
    run env PROJECT_ROOT="$FRAMEWORK_ROOT" "$SCANNER" scan-tree
    [ "$status" -eq 0 ]
}
