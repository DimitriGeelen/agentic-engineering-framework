#!/usr/bin/env bats
# T-3924: `fw config set inception_commit_limit 15` wrote a lowercase key that
# fw_config (which reads .framework.yaml by the exact uppercase registry key)
# never read, so the inception commit limit silently stayed 2.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TEST_DIR="$(mktemp -d "${BATS_TMPDIR:-/tmp}/t3924.XXXXXX")"
    export PROJECT_ROOT="$TEST_DIR"
    export FRAMEWORK_ROOT
    printf 'project_name: t3924\nversion: 1.0.0\n' > "$TEST_DIR/.framework.yaml"
    unset FW_INCEPTION_COMMIT_LIMIT
}

teardown() {
    rm -rf "$TEST_DIR"
}

# Run in a fresh shell so the libs' load guards and _config_yaml bind to TEST_DIR.
_cfg() {
    bash -c 'source "$FRAMEWORK_ROOT/lib/config.sh"; source "$FRAMEWORK_ROOT/lib/config-file.sh"; do_config "$@"' _ "$@"
}

@test "set with a lowercase registry key writes the canonical key that fw_config reads" {
    run _cfg set inception_commit_limit 7
    [ "$status" -eq 0 ]
    [[ "$output" == *"INCEPTION_COMMIT_LIMIT"* ]]
    grep -q '^INCEPTION_COMMIT_LIMIT: 7$' "$TEST_DIR/.framework.yaml"
    ! grep -q '^inception_commit_limit:' "$TEST_DIR/.framework.yaml" || false
    run bash -c 'source "$FRAMEWORK_ROOT/lib/config.sh"; fw_config INCEPTION_COMMIT_LIMIT 2'
    [ "$output" = "7" ]
}

@test "get with a lowercase registry key reads the canonical key" {
    printf 'INCEPTION_COMMIT_LIMIT: 9\n' >> "$TEST_DIR/.framework.yaml"
    run _cfg get inception_commit_limit
    [ "$status" -eq 0 ]
    [ "$output" = "9" ]
}

@test "set refuses an unknown key and names the closest registry key" {
    run _cfg set INCEPTION_COMIT_LIMIT 7
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown config key"* ]]
    [[ "$output" == *"INCEPTION_COMMIT_LIMIT"* ]]
    ! grep -q 'COMIT' "$TEST_DIR/.framework.yaml" || false
}

@test "set --force writes an unknown key verbatim" {
    run _cfg set MY_CUSTOM_THING 1 --force
    [ "$status" -eq 0 ]
    grep -q '^MY_CUSTOM_THING: 1$' "$TEST_DIR/.framework.yaml"
}

@test "set still accepts known non-registry keys, dotted keys and keys already present" {
    run _cfg set PROTECT_MASTER 1
    [ "$status" -eq 0 ]
    run _cfg set project_name renamed
    [ "$status" -eq 0 ]
    run _cfg set watchtower.port 3001
    [ "$status" -eq 0 ]
    printf 'LEGACY_THING: a\n' >> "$TEST_DIR/.framework.yaml"
    run _cfg set LEGACY_THING b
    [ "$status" -eq 0 ]
    grep -q '^LEGACY_THING: b$' "$TEST_DIR/.framework.yaml"
}

@test "case-mismatch scan (fw doctor) names a dead lowercase key and leaves the file alone" {
    printf 'inception_commit_limit: 15\nCONTEXT_WINDOW: 975000\n' >> "$TEST_DIR/.framework.yaml"
    before="$(cat "$TEST_DIR/.framework.yaml")"
    run bash -c 'source "$FRAMEWORK_ROOT/lib/config.sh"; fw_config_case_mismatches "$PROJECT_ROOT/.framework.yaml"'
    [ "$status" -eq 0 ]
    [ "$output" = "inception_commit_limit|INCEPTION_COMMIT_LIMIT" ]
    [ "$(cat "$TEST_DIR/.framework.yaml")" = "$before" ]
}

@test "fw doctor wires the case-mismatch scan into a WARN with the fix" {
    grep -q 'fw_config_case_mismatches "\$PROJECT_ROOT/.framework.yaml"' "$FRAMEWORK_ROOT/bin/fw"
    grep -q "is ignored — the setting is" "$FRAMEWORK_ROOT/bin/fw"
}

@test "the inception gate hint names the canonical key" {
    grep -q 'config set INCEPTION_COMMIT_LIMIT N' "$FRAMEWORK_ROOT/agents/git/lib/hooks.sh"
    ! grep -q 'config set inception_commit_limit' "$FRAMEWORK_ROOT/agents/git/lib/hooks.sh" || false
}
