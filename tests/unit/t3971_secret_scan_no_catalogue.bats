#!/usr/bin/env bats
# T-3971 (ring20, measured): `secret-scan.sh scan-tree` with no .secret-scan-patterns
# warned and exited 0 even with a planted AWS key, skipped the filename axis, and
# `fw audit` printed "[PASS] Secret scan: tracked tree clean". Audit mode now says
# NOT CHECKED (rc 3) and the audit FAILs on it. scan-staged (the commit hook) keeps its
# deliberate fail-open-with-warning, strict under FW_SECRET_SCAN_STRICT=1.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    R="$TEST_TEMP_DIR/repo"
    mkdir -p "$R" && cd "$R" && git init -q && git config user.email t@t && git config user.name t
    SCAN="$FRAMEWORK_ROOT/agents/git/lib/secret-scan.sh"
    # Built at run time so this file never contains a key-shaped literal.
    KEY="AKIA$(printf 'IOSFODNN7EXAMPLE')"
    printf 'aws_key = "%s"\n' "$KEY" > "$R/config.ini"
    git -C "$R" add config.ini && git -C "$R" commit -qm init
    export PROJECT_ROOT="$R"
    unset FW_SECRET_SCAN_STRICT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "T-3971: scan-tree with no catalogue is NOT CHECKED (3), never 0 — planted key present" {
    run "$SCAN" scan-tree
    [ "$status" -eq 3 ]
    [[ "$output" == *"NOT CHECKED"* ]]
}

@test "T-3971: scan-tree with no catalogue still runs the filename axis (rc 1 on a key file)" {
    printf 'x\n' > "$R/id_rsa" && git -C "$R" add id_rsa && git -C "$R" commit -qm key
    run "$SCAN" scan-tree
    [ "$status" -eq 1 ]
}

@test "T-3971: scan-file with no catalogue is NOT CHECKED (3)" {
    run "$SCAN" scan-file "$R/config.ini"
    [ "$status" -eq 3 ]
}

@test "T-3971: scan-staged keeps its fail-open warning, and strict mode blocks" {
    printf 'more = "%s"\n' "$KEY" >> "$R/config.ini" && git -C "$R" add config.ini
    run "$SCAN" scan-staged
    [ "$status" -eq 0 ]
    [[ "$output" == *"WITHOUT PATTERNS"* ]]
    FW_SECRET_SCAN_STRICT=1 run "$SCAN" scan-staged
    [ "$status" -eq 1 ]
}

@test "T-3971/control: with the catalogue, the planted key is found (1) and a clean tree is 0" {
    cp "$FRAMEWORK_ROOT/.secret-scan-patterns" "$R/.secret-scan-patterns"
    run "$SCAN" scan-tree
    [ "$status" -eq 1 ]
    git -C "$R" rm -q config.ini && git -C "$R" commit -qm clean
    run "$SCAN" scan-tree
    [ "$status" -eq 0 ]
}

@test "T-3971: fw audit maps scan-tree rc 3 to FAIL NOT CHECKED, never PASS" {
    block="$(awk '/^SECRET_SCANNER=/{p=1} p{print} p&&/^fi$/{exit}' "$FRAMEWORK_ROOT/agents/audit/audit.sh")"
    [[ "$block" == *'"$_ss_rc" -eq 3'* ]]
    stub="$TEST_TEMP_DIR/fw"; mkdir -p "$stub/agents/git/lib"
    printf '#!/bin/bash\necho "secret-scan: NOT CHECKED: no patterns catalogue" >&2\nexit 3\n' \
        > "$stub/agents/git/lib/secret-scan.sh"
    chmod +x "$stub/agents/git/lib/secret-scan.sh"
    run bash -c "fail() { echo \"FAIL: \$1\"; }; pass() { echo \"PASS: \$1\"; }
        FRAMEWORK_ROOT='$stub'; PROJECT_ROOT='$R'
        $block"
    [[ "$output" == *"FAIL: Secret scan NOT CHECKED"* ]]
    [[ "$output" != *"PASS"* ]]
}
