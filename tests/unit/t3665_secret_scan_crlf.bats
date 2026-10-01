#!/usr/bin/env bats
# T-3665 — a CRLF checkout silently disabled the secret scan (P-01 Win F-07).
#
# With core.autocrlf=true, .secret-scan-patterns is checked out with CRLF line
# endings. `IFS=$'\t' read -r _name _re` then leaves a trailing \r on every
# regex, so each pattern demands a literal carriage return after the secret.
# The staged diff comes from the index (LF), so nothing ever matched and the
# scanner reported clean — the same output as a genuinely clean commit.
#
# These tests convert the catalogue and allowlist to CRLF, exactly the bytes an
# autocrlf checkout produces, and assert the scanner still catches a planted
# secret in every mode. Fixture strings are synthesized to MATCH the patterns;
# they are not real secrets (this file is path-allowlisted like its siblings).

load ../test_helper

SCANNER="$FRAMEWORK_ROOT/agents/git/lib/secret-scan.sh"

# Synthesized fixtures, assembled at run time so this file's own text does not
# match the catalogue.
AWS_FIXTURE="AKIA""ABCDEFGHIJKLMNOP"
GH_FIXTURE="ghp_""abcdefghijklmnopqrstuvwxyz0123456789AB"

_to_crlf() {
    # Normalise to LF first so the conversion is idempotent, then add CR.
    sed -i 's/\r$//; s/$/\r/' "$1"
}

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
    cp "$FRAMEWORK_ROOT/.secret-scan-patterns" "$TEST_REPO/.secret-scan-patterns"
    cp "$FRAMEWORK_ROOT/.secret-scan-allowlist" "$TEST_REPO/.secret-scan-allowlist"
    _to_crlf "$TEST_REPO/.secret-scan-patterns"
    _to_crlf "$TEST_REPO/.secret-scan-allowlist"
    echo "ok" > README.md
    git add README.md
    git commit -q -m "T-0: init"
}

teardown() {
    cd /
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "T-3665: fixture really is CRLF (control — the test exercises the bug shape)" {
    grep -q $'\r$' "$TEST_REPO/.secret-scan-patterns"
    grep -q $'\r$' "$TEST_REPO/.secret-scan-allowlist"
}

@test "T-3665: scan-staged catches a planted AWS key with a CRLF catalogue" {
    printf 'aws = "%s"\n' "$AWS_FIXTURE" > "$TEST_REPO/config.txt"
    git -C "$TEST_REPO" add config.txt
    run env PROJECT_ROOT="$TEST_REPO" bash "$SCANNER" scan-staged
    [ "$status" -eq 1 ]
    [[ "$output" == *"[AWS Access Key]"* ]]
}

@test "T-3665: scan-staged catches a planted GitHub PAT with a CRLF catalogue" {
    printf 'token: %s\n' "$GH_FIXTURE" > "$TEST_REPO/settings.txt"
    git -C "$TEST_REPO" add settings.txt
    run env PROJECT_ROOT="$TEST_REPO" bash "$SCANNER" scan-staged
    [ "$status" -eq 1 ]
    [[ "$output" == *"[GitHub PAT]"* ]]
}

@test "T-3665: scan-staged catches a secret in a file whose own content is CRLF" {
    printf 'aws = "%s"\r\n' "$AWS_FIXTURE" > "$TEST_REPO/win.txt"
    git -C "$TEST_REPO" add win.txt
    run env PROJECT_ROOT="$TEST_REPO" bash "$SCANNER" scan-staged
    [ "$status" -eq 1 ]
    [[ "$output" == *"[AWS Access Key]"* ]]
}

@test "T-3665: scan-file catches a planted secret with a CRLF catalogue" {
    printf 'aws = "%s"\n' "$AWS_FIXTURE" > "$TEST_REPO/loose.txt"
    run env PROJECT_ROOT="$TEST_REPO" bash "$SCANNER" scan-file "$TEST_REPO/loose.txt"
    [ "$status" -eq 1 ]
    [[ "$output" == *"[AWS Access Key]"* ]]
}

@test "T-3665: scan-tree catches a tracked secret with a CRLF catalogue" {
    printf 'aws = "%s"\n' "$AWS_FIXTURE" > "$TEST_REPO/tracked.txt"
    git -C "$TEST_REPO" add tracked.txt
    git -C "$TEST_REPO" commit -q -m "T-0: plant"
    run env PROJECT_ROOT="$TEST_REPO" bash "$SCANNER" scan-tree
    [ "$status" -eq 1 ]
    [[ "$output" == *"[AWS Access Key]"* ]]
}

@test "T-3665: a CRLF allowlist entry still suppresses its finding" {
    printf '^allowed\\.txt:\n' >> "$TEST_REPO/.secret-scan-allowlist"
    _to_crlf "$TEST_REPO/.secret-scan-allowlist"
    printf 'aws = "%s"\n' "$AWS_FIXTURE" > "$TEST_REPO/allowed.txt"
    git -C "$TEST_REPO" add allowed.txt
    run env PROJECT_ROOT="$TEST_REPO" bash "$SCANNER" scan-staged
    [ "$status" -eq 0 ]
}

@test "T-3665: .gitattributes pins eol=lf for the scanner and its config" {
    cd "$FRAMEWORK_ROOT"
    for p in agents/git/lib/secret-scan.sh .secret-scan-patterns .secret-scan-allowlist tests/unit/t3665_secret_scan_crlf.bats; do
        out="$(git check-attr eol -- "$p")"
        [[ "$out" == *"eol: lf" ]] || { echo "not eol=lf: $out"; return 1; }
    done
}
