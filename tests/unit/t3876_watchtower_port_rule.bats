#!/usr/bin/env bats
# T-3876: ONE port rule for Watchtower start and restart (bin/watchtower.sh
# choose_port): explicit --port > configured PORT (free or ours) > the last port
# this project ran on (free or ours) > allocate. Before, do_start ignored the
# last port and do_restart (T-2598) put it ABOVE the configured PORT, so after
# the 2026-10-05 reboot AEF moved 3002 -> 3000 and 055 lost 3050, and 055's
# `fw config set PORT 3050` was ignored by a bare restart.
#
# choose_port is extracted from bin/watchtower.sh itself and run against stubs
# for the port probes, so the test follows the real function.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    WT="${BATS_TEST_DIRNAME}/../../bin/watchtower.sh"
    PORT_FILE="$TEST_TEMP_DIR/watchtower.port"
    IN_USE=""; OURS=""; CONFIGURED=0; DEFAULT_PORT=3000; ALLOC=3009
    eval "$(awk '/^choose_port\(\) \{/{p=1} p{print} p&&/^\}/{exit}' "$WT")"
}

port_in_use()                    { [[ " $IN_USE " == *" $1 "* ]]; }
_watchtower_port_holder_is_ours() { [[ " $OURS " == *" $1 "* ]]; }
port_configured()                { [ "$CONFIGURED" = 1 ]; }
allocate_port()                  { echo "$ALLOC"; }

@test "t3876: choose_port is found in bin/watchtower.sh (guards the extractor)" {
    type choose_port >/dev/null
}

@test "t3876: an explicit --port always wins" {
    CONFIGURED=1; echo 3050 > "$PORT_FILE"
    run choose_port 4444
    [ "$output" = "4444 explicit" ]
}

@test "t3876: configured PORT wins when free (fw config set PORT takes effect on restart)" {
    CONFIGURED=1; DEFAULT_PORT=3050; echo 3002 > "$PORT_FILE"
    run choose_port
    [ "$output" = "3050 configured" ]
}

@test "t3876: configured PORT held by our own Watchtower is reused" {
    CONFIGURED=1; DEFAULT_PORT=3050; IN_USE="3050"; OURS="3050"
    run choose_port
    [ "$output" = "3050 configured" ]
}

@test "t3876: THE 055 CASE — no PORT configured, last port 3050 free → 3050, not first free from 3000" {
    CONFIGURED=0; echo 3050 > "$PORT_FILE"; IN_USE="3000"
    run choose_port
    [ "$output" = "3050 last" ]
}

@test "t3876: configured PORT held by a FOREIGN service → last port, not abort" {
    CONFIGURED=1; DEFAULT_PORT=3000; IN_USE="3000"; echo 3002 > "$PORT_FILE"
    run choose_port
    [ "$output" = "3002 last" ]
}

@test "t3876: last port held by a foreign service is skipped → allocate" {
    CONFIGURED=0; echo 3050 > "$PORT_FILE"; IN_USE="3050"
    run choose_port
    [ "$output" = "3009 allocated" ]
}

@test "t3876: nothing configured, no last port → allocate" {
    run choose_port
    [ "$output" = "3009 allocated" ]
}

@test "t3876: restart has no port rule of its own any more" {
    run awk '/^do_restart\(\) \{/{p=1} p{print} p&&/^\}/{exit}' "$WT"
    [[ "$output" != *'do_start --port "$prev_port"'* ]]
    [[ "$output" == *'do_start "$@"'* ]]
}
