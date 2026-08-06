#!/usr/bin/env bats
# T-2844: an empty cron registry is not drift.
#
# `fw init` seeds `.context/cron-registry.yaml` with `jobs: []`. Both `fw doctor`
# and `fw audit` gated their registry→generated→deployed drift checks on the
# registry FILE existing, so every project warned about ungenerated cron from the
# moment it was created.
#
# The malformed cases matter as much as the empty one: -1 must not collapse into
# 0, or an unreadable registry would silently skip the drift checks entirely —
# trading a false positive for a false negative, which is the worse trade.

setup() {
    FW_ROOT="$BATS_TEST_DIRNAME/../.."
    source "$FW_ROOT/lib/cron-registry.sh"
    TMP="$BATS_TEST_TMPDIR/reg.yaml"
}

@test "freshly seeded registry (jobs: []) counts 0" {
    printf 'jobs: []\n' > "$TMP"
    run cron_registry_job_count "$TMP"
    [ "$output" = "0" ]
}

@test "the literal bytes fw init writes count 0" {
    # Guard against the seed template drifting away from what this test assumes.
    printf '%s\n' \
        '# Cron Registry — Structured source of truth for scheduled jobs (T-448)' \
        '# Read by web/blueprints/cron.py and fw cron generate.' \
        '# Editable by humans, controllable via Watchtower web UI.' \
        'jobs: []' > "$TMP"
    run cron_registry_job_count "$TMP"
    [ "$output" = "0" ]
}

@test "registry with no jobs key at all counts 0" {
    printf 'something_else: 1\n' > "$TMP"
    run cron_registry_job_count "$TMP"
    [ "$output" = "0" ]
}

@test "jobs: null counts 0" {
    printf 'jobs:\n' > "$TMP"
    run cron_registry_job_count "$TMP"
    [ "$output" = "0" ]
}

@test "NEGATIVE CONTROL: a registry with one job counts 1, so drift checks still run" {
    printf 'jobs:\n  - id: nightly-audit\n    schedule: "0 3 * * *"\n    command: fw audit\n' > "$TMP"
    run cron_registry_job_count "$TMP"
    [ "$output" = "1" ]
}

@test "NEGATIVE CONTROL: three jobs count 3" {
    printf 'jobs:\n  - id: a\n  - id: b\n  - id: c\n' > "$TMP"
    run cron_registry_job_count "$TMP"
    [ "$output" = "3" ]
}

@test "malformed YAML counts -1, not 0 (must not silently skip drift checks)" {
    printf 'jobs: [\n  - broken: : :\n' > "$TMP"
    run cron_registry_job_count "$TMP"
    [ "$output" = "-1" ]
}

@test "jobs held as a mapping rather than a list counts -1" {
    printf 'jobs:\n  a: 1\n  b: 2\n' > "$TMP"
    run cron_registry_job_count "$TMP"
    [ "$output" = "-1" ]
}

@test "a missing registry counts -1" {
    run cron_registry_job_count "$BATS_TEST_TMPDIR/does-not-exist.yaml"
    [ "$output" = "-1" ]
}

@test "a registry that is not a mapping counts -1" {
    printf -- '- just\n- a\n- list\n' > "$TMP"
    run cron_registry_job_count "$TMP"
    [ "$output" = "-1" ]
}
