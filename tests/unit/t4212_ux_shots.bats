#!/usr/bin/env bats
# T-4212 (T-4202 leg A) — `fw ux shots` CLI wiring: the width list comes from the
# UX_SHOT_WIDTHS registry key, is validated (>=3 entries), and --plan-only names
# the convention paths without launching a browser.

setup() {
    export PROJECT_ROOT="$BATS_TEST_TMPDIR/project"
    mkdir -p "$PROJECT_ROOT"
    FW="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/bin/fw"
}

@test "T-4212: registry default for UX_SHOT_WIDTHS is the T-4202 trio" {
    run bash -c "source '$BATS_TEST_DIRNAME/../../lib/config.sh' && fw_config UX_SHOT_WIDTHS"
    [ "$status" -eq 0 ]
    [ "$output" = "1024,1440,1920" ]
}

@test "T-4212: fw ux shots --plan-only plans every state at every default width" {
    run "$FW" ux shots T-4212 a=file:///tmp/a.html --plan-only
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | wc -l)" -eq 3 ]
    echo "$output" | grep -q '/.context/visual/T-4212/a@1024.png$'
    echo "$output" | grep -q '/.context/visual/T-4212/a@1440.png$'
    echo "$output" | grep -q '/.context/visual/T-4212/a@1920.png$'
}

@test "T-4212: FW_UX_SHOT_WIDTHS override with fewer than 3 widths is refused (exit 2)" {
    run env FW_UX_SHOT_WIDTHS="1024,1440" "$FW" ux shots T-4212 a=file:///tmp/a.html --plan-only
    [ "$status" -eq 2 ]
    echo "$output" | grep -q 'requires at least 3'
}

@test "T-4212: fw ux shots with no subcommand prints usage and exits 2" {
    run "$FW" ux
    [ "$status" -eq 2 ]
    echo "$output" | grep -q 'Usage: fw ux shots'
}

@test "T-4212: fw ux-review (palette engine) is still routed to its own verb" {
    run grep -c '^    ux-review)' "$FW"
    [ "$output" = "1" ]
}
