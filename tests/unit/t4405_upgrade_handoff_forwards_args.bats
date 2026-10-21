#!/usr/bin/env bats
# T-4405: fw upgrade's bare-from-consumer handoff (T-1634) rebuilt the upstream
# invocation from two booleans, so every other flag the caller passed was
# dropped. ring20-dashboard passed --allow-delete-locals and the upstream run
# refused, asking for --allow-delete-locals. The replay is now the caller's own
# argv, minus the target (re-supplied, absolute) and --from-upstream.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export FW_VERSION="1.5.0"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
    # A local upstream whose bin/fw records its argv, one argument per line.
    UP="$TEST_TEMP_DIR/upstream-src"
    ARGV_LOG="$TEST_TEMP_DIR/argv.log"
    mkdir -p "$UP/bin"
    cat > "$UP/bin/fw" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$ARGV_LOG"
exit 0
STUB
    chmod +x "$UP/bin/fw"
    (cd "$UP" && git init -q && git add . \
        && git -c user.email=t@t -c user.name=t commit -q -m seed)
    # The target path has a space: quoting must survive the handoff.
    PROJ="$TEST_TEMP_DIR/consumer with space"
    mkdir -p "$PROJ/.agentic-framework"
    (cd "$PROJ/.agentic-framework" && git init -q && touch FRAMEWORK.md && git add FRAMEWORK.md \
        && git -c user.email=t@t -c user.name=t commit -q -m init)
    printf 'project_name: c\nversion: 1.4.0\nupstream_repo: %s\n' "$UP" > "$PROJ/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_bare_upgrade() {
    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$PROJ/.agentic-framework"
    run do_upgrade "$@"
    FRAMEWORK_ROOT="$saved"
}

@test "T-4405: --allow-delete-locals and the other flags reach the upstream bin/fw, argv exact" {
    _bare_upgrade "$PROJ" --allow-delete-locals --strict --no-self-vendor --force
    [ "$status" -eq 0 ]
    [ -f "$ARGV_LOG" ]
    printf '%s\n' upgrade "$PROJ" --allow-delete-locals --strict --no-self-vendor --force > "$TEST_TEMP_DIR/want"
    diff "$TEST_TEMP_DIR/want" "$ARGV_LOG"
}

@test "T-4405: flags before the target keep their order; the target is passed once, absolute" {
    cd "$TEST_TEMP_DIR"
    _bare_upgrade --allow-delete-locals --with-messaging "consumer with space"
    [ "$status" -eq 0 ]
    printf '%s\n' upgrade "$PROJ" --allow-delete-locals --with-messaging > "$TEST_TEMP_DIR/want"
    diff "$TEST_TEMP_DIR/want" "$ARGV_LOG"
}

@test "T-4405: --from-upstream (both spellings) is not forwarded — the clone is the source" {
    _bare_upgrade "$PROJ" --from-upstream "$UP" --allow-delete-locals
    [ "$status" -eq 0 ]
    ! grep -q -- '--from-upstream' "$ARGV_LOG" || false
    ! grep -qxF "$UP" "$ARGV_LOG" || false
    grep -qx -- '--allow-delete-locals' "$ARGV_LOG"
    _bare_upgrade "$PROJ" "--from-upstream=$UP" --strict
    [ "$status" -eq 0 ]
    ! grep -q -- '--from-upstream' "$ARGV_LOG" || false
    grep -qx -- '--strict' "$ARGV_LOG"
}

@test "T-4405: the dry-run plan names the forwarded flags" {
    _bare_upgrade "$PROJ" --dry-run --allow-delete-locals
    [ "$status" -eq 0 ]
    [[ "$output" == *"would re-invoke:"*"--allow-delete-locals"* ]]
    [[ "$output" == *"--dry-run"* ]]
    # T-4234: the dry run hands off to preview the changes — with --dry-run in argv.
    grep -qx -- '--dry-run' "$ARGV_LOG"
    grep -qx -- '--allow-delete-locals' "$ARGV_LOG"
}
