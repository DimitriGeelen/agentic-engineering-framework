#!/usr/bin/env bats
# T-4892 (832, msg 48e82957): `fw config get KEY` documents the EFFECTIVE value (T-4807),
# but for a registered key that is unset it exited 1 with no output. The effective value
# of such a key is its registry default — what fw_config returns — so that is printed now.
# `--file` (the file alone) and unknown keys still exit 1.

setup() {
    FW="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/bin/fw"
    P="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$P"
    printf 'project_name: proj\n' > "$P/.framework.yaml"
}

_get() { run env -u FW_REVIEWER_JUDGE_WEEKLY_SPEND_CEILING PROJECT_ROOT="$P" bash -c "cd '$P' && '$FW' config get $*"; }

@test "an unset registered key prints its registry default, exit 0" {
    _get REVIEWER_JUDGE_WEEKLY_SPEND_CEILING
    [ "$status" -eq 0 ]
    [ "$output" = "10000" ]
}

@test "a set registered key still prints its value" {
    printf 'project_name: proj\nREVIEWER_JUDGE_WEEKLY_SPEND_CEILING: 250\n' > "$P/.framework.yaml"
    _get REVIEWER_JUDGE_WEEKLY_SPEND_CEILING
    [ "$status" -eq 0 ]
    [ "$output" = "250" ]
}

@test "--file asks about the file alone: an unset key still exits 1" {
    _get --file REVIEWER_JUDGE_WEEKLY_SPEND_CEILING
    [ "$status" -eq 1 ]
}

@test "an unknown key still exits 1" {
    _get NO_SUCH_KEY_T4892
    [ "$status" -eq 1 ]
}
