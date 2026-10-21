#!/usr/bin/env bats
# T-4234: a consumer's `fw upgrade --dry-run` (bare-from-consumer, T-1634) stopped
# at "would clone <url>" and returned before fetching, so the operator never saw
# which files the upgrade would touch (1409 msg eb27d14e, finding 3). The dry run
# now clones into its temp dir and hands off to the clone's own --dry-run, whose
# report names the files; the consumer stays byte-identical.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export NO_COLOR=1
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.agentic-framework"
    (cd "$PROJ/.agentic-framework" && git init -q && touch FRAMEWORK.md && git add FRAMEWORK.md \
        && git -c user.email=t@t -c user.name=t commit -q -m init)
    (cd "$PROJ" && git init -q)
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_snapshot() {
    (cd "$TEST_TEMP_DIR" && find proj -path '*/.git' -prune -o -type f -print0 \
        | sort -z | xargs -0 md5sum)
}

_bare_dry_run() {
    run timeout 300 bash -c 'source "$1/lib/colors.sh"; source "$1/lib/upgrade.sh"
        FRAMEWORK_ROOT="$2/.agentic-framework" do_upgrade "$2" --dry-run' _ "$FRAMEWORK_ROOT" "$PROJ"
}

@test "T-4234: consumer dry-run previews the per-file changes and writes nothing" {
    printf 'project_name: proj\nversion: 1.4.0\nprovider: claude\nupstream_repo: %s\n' \
        "$FRAMEWORK_ROOT" > "$PROJ/.framework.yaml"
    _snapshot > "$TEST_TEMP_DIR/before"
    _bare_dry_run
    [ "$status" -eq 0 ]
    [[ "$output" == *"would clone"* ]]
    # The clone's own dry run ran: its mode banner and per-step reports are present.
    [[ "$output" == *"DRY RUN"* ]]
    [[ "$output" == *"CLAUDE.md"* ]]
    [[ "$output" == *".claude/settings.json"* ]]
    [[ "$output" == *"Dry Run Complete"* ]]
    _snapshot > "$TEST_TEMP_DIR/after"
    diff "$TEST_TEMP_DIR/before" "$TEST_TEMP_DIR/after"
    # The temp clone named in the plan is gone.
    local tmpd
    tmpd=$(printf '%s\n' "$output" | sed -n 's/.*would clone .* into \(.*\)\/fw$/\1/p' | head -1)
    [ -n "$tmpd" ]
    [ ! -e "$tmpd" ]
}

@test "T-4234: unreachable upstream in dry-run says the preview is unavailable" {
    printf 'project_name: proj\nversion: 1.4.0\nprovider: claude\nupstream_repo: %s\n' \
        "$TEST_TEMP_DIR/no-such-upstream" > "$PROJ/.framework.yaml"
    _snapshot > "$TEST_TEMP_DIR/before"
    _bare_dry_run
    [ "$status" -eq 0 ]
    [[ "$output" == *"would clone"* ]]
    [[ "$output" == *"preview unavailable"* ]]
    _snapshot > "$TEST_TEMP_DIR/after"
    diff "$TEST_TEMP_DIR/before" "$TEST_TEMP_DIR/after"
}
