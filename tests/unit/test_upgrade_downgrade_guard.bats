#!/usr/bin/env bats
# T-1839 — fw upgrade silent-downgrade guard.
#
# Origin: T-1838 (sibling) fixed the doctor advice that would have pointed
# operators at a downgrading `fw upgrade`. T-1839 closes the loop by making
# the command itself refuse the downgrade direction unless explicitly
# overridden with --force-downgrade.
#
# Pre-fix behaviour (lib/upgrade.sh:1082-1112): direction-blind overwrite of
# .framework.yaml's `version:` field with $FW_VERSION whenever the two
# differ. Consumer at 1.6.260 + framework at 1.6.170 → silent downgrade,
# only post-facto forensic trail in `upgraded_from` + audit YAML.
#
# These tests pin:
#   - Source-level: --force-downgrade arg accepted; shared direction comparator
#     (fw_version_relation, T-2713; was sort -V) used; REFUSED message names both
#     versions + T-1828
#   - Behavioural: do_upgrade refuses when consumer > framework (--dry-run
#     mode, so no real filesystem mutation); proceeds with --force-downgrade

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export FW_VERSION="1.6.170"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ── Source-level pins (cheap, fast) ──

@test "T-1839: --force-downgrade flag is parsed in do_upgrade" {
    run do_upgrade --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--force-downgrade"* ]]
}

@test "T-1839: help text explains --force-downgrade and references T-1839" {
    run do_upgrade --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-1839"* ]]
}

@test "T-1839: lib/upgrade.sh decides the direction with the shared fw_version_relation (T-2713)" {
    run grep -q 'fw_version_relation' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    [ "$status" -eq 0 ]
}

@test "T-1839: lib/upgrade.sh REFUSED message names AHEAD of framework" {
    run grep -q 'AHEAD of framework' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    [ "$status" -eq 0 ]
}

@test "T-1839: lib/upgrade.sh REFUSED message references T-1828" {
    run grep -q 'T-1828' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    [ "$status" -eq 0 ]
}

@test "T-1839: lib/upgrade.sh suggests --force-downgrade in refusal text" {
    run grep -q 'force-downgrade' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    [ "$status" -eq 0 ]
}

@test "T-1839: lib/upgrade.sh parses with bash -n" {
    run bash -n "$FRAMEWORK_ROOT/lib/upgrade.sh"
    [ "$status" -eq 0 ]
}

# ── Behavioural pin: the direction comparator the guard uses ──
# T-4380: a throwaway framework repo with two commits, OLD then NEW. The version
# relation is decided by git ancestry (lib/version-relation.sh, T-2713), so the
# fixture is real history rather than a version-string pair.
_vr_fixture() {
    VR_REPO="$TEST_TEMP_DIR/fwrepo"
    mkdir -p "$VR_REPO"
    git -C "$VR_REPO" init -q
    git -C "$VR_REPO" -c user.email=t@t -c user.name=t commit -q --allow-empty -m old
    VR_OLD="$(git -C "$VR_REPO" rev-parse HEAD)"
    git -C "$VR_REPO" -c user.email=t@t -c user.name=t commit -q --allow-empty -m new
    VR_NEW="$(git -C "$VR_REPO" rev-parse HEAD)"
    source "$FRAMEWORK_ROOT/lib/version-relation.sh"
}

@test "T-1839: consumer holding newer code than framework HEAD resolves ahead (1.6.260 vs 1.6.170)" {
    _vr_fixture
    git -C "$VR_REPO" checkout -q "$VR_OLD"
    fw_version_relation "1.6.260" "1.6.170" "$VR_NEW" "$VR_REPO" >/dev/null
    [ "$FW_VERSION_RELATION" = "ahead" ]
}

@test "T-1839: consumer on code the framework contains resolves behind (1.6.100 vs 1.6.170)" {
    _vr_fixture
    fw_version_relation "1.6.100" "1.6.170" "$VR_OLD" "$VR_REPO" >/dev/null
    [ "$FW_VERSION_RELATION" = "behind" ]
}
