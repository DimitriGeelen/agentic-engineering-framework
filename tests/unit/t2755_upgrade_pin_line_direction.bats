#!/usr/bin/env bats
# T-2755: the `fw upgrade` header must report the DIRECTION it was given, not
# "behind" for every mismatch.
#
# ORIGIN (2026-08-03, operator report from /opt/002-Claude-Partner-Network).
# One `fw upgrade` run printed, two lines apart:
#
#     Pinned:    v1.6.354 (behind v1.6.8)
#     REFUSED    Consumer v1.6.354 is AHEAD of framework v1.6.8
#
# The header was `[ "$project_version" = "$fw_version" ]` — an EQUALITY test with
# a directional label bolted onto its else-branch. Every mismatch rendered
# "behind", including the ones the guard was refusing. A reader who trusts the
# header reaches for --force-downgrade at exactly the moment the guard is
# protecting them, and a downgrade did occur on that host (1.6.295 -> 1.6.121).
#
# The comparator was never the missing piece: T-2713 had already replaced
# `sort -V` with git ancestry *because a resetting counter cannot order*, and
# wired it into the guard. It was not wired into the sentence above the guard.
#
# WHY THESE TESTS ARE AT THE RENDERER, NOT END-TO-END
# The old line was only observable by running a real upgrade against a real
# mismatched consumer — which is why nothing caught it. do_upgrade now delegates
# to fw_upgrade_render_pin_line, so the wording is reachable directly. Test 7 is
# the seam check: it asserts do_upgrade still calls the renderer, so these tests
# cannot pass against a do_upgrade that quietly re-inlined the old branch.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR

    FWROOT="${BATS_TEST_DIRNAME}/../.."
    # should_refuse lives here; the renderer derives its suffix from it.
    source "$FWROOT/lib/version-relation.sh"

    # Colour vars the renderer interpolates. Empty keeps assertions on the words.
    GREEN='' YELLOW='' RED='' NC='' BOLD='' CYAN=''
    export GREEN YELLOW RED NC BOLD CYAN

    source "$FWROOT/lib/upgrade.sh"
}

@test "T-2755: ahead renders AHEAD — never 'behind'" {
    run fw_upgrade_render_pin_line "1.6.354" "1.6.8" "ahead" false
    [ "$status" -eq 0 ]
    # The exact regression: this line used to read "(behind v1.6.8)".
    [[ "$output" != *"behind"* ]]
    [[ "$output" == *"AHEAD of v1.6.8"* ]]
}

@test "T-2755: ahead header agrees with the guard that follows it" {
    # AC2 — the header must not promise an outcome the guard contradicts.
    run fw_upgrade_render_pin_line "1.6.354" "1.6.8" "ahead" false
    [[ "$output" == *"upgrade will refuse"* ]]
    # And the predicate driving that suffix is the guard's own.
    fw_version_relation_should_refuse "ahead"
}

@test "T-2755: behind still renders behind" {
    run fw_upgrade_render_pin_line "1.6.121" "1.6.305" "behind" false
    [ "$status" -eq 0 ]
    [[ "$output" == *"behind v1.6.305"* ]]
    # A behind consumer is not about to be refused; no scary suffix.
    [[ "$output" != *"refuse"* ]]
}

@test "T-2755: same renders current" {
    run fw_upgrade_render_pin_line "1.6.305" "1.6.305" "same" false
    [ "$status" -eq 0 ]
    [[ "$output" == *"current"* ]]
    [[ "$output" != *"behind"* ]]
}

@test "T-2755: undecidable says undecidable, does not default to behind" {
    # The T-2713 lesson one layer up: asserting a direction we cannot compute is
    # what froze a consumer for weeks. An unknown relation must not fall through
    # to the behind branch.
    run fw_upgrade_render_pin_line "1.6.264" "1.6.163" "undecidable" false
    [ "$status" -eq 0 ]
    [[ "$output" == *"undecidable"* ]]
    [[ "$output" != *"behind"* ]]
    [[ "$output" != *"AHEAD"* ]]
}

@test "T-2755: diverged is reported as diverged and refuses" {
    run fw_upgrade_render_pin_line "1.6.354" "1.6.8" "diverged" false
    [ "$status" -eq 0 ]
    [[ "$output" == *"diverged"* ]]
    [[ "$output" == *"upgrade will refuse"* ]]
    [[ "$output" != *"behind"* ]]
}

@test "T-2755: --force-downgrade changes the suffix, not the direction" {
    run fw_upgrade_render_pin_line "1.6.354" "1.6.8" "ahead" true
    [ "$status" -eq 0 ]
    # Still tells the truth about direction...
    [[ "$output" == *"AHEAD of v1.6.8"* ]]
    # ...but no longer claims a refusal that will not happen.
    [[ "$output" != *"upgrade will refuse"* ]]
    [[ "$output" == *"force-downgrade"* ]]
}

@test "T-2755: do_upgrade delegates to the renderer (seam not re-inlined)" {
    # Without this, someone could restore the equality branch inside do_upgrade
    # and every test above would still pass against the orphaned renderer.
    run grep -n "fw_upgrade_render_pin_line" "$FWROOT/lib/upgrade.sh"
    [ "$status" -eq 0 ]
    # definition + at least one call site
    [ "$(echo "$output" | wc -l)" -ge 2 ]

    # And the old equality-with-directional-label shape is gone from the header.
    run grep -n 'behind v\${fw_version}' "$FWROOT/lib/upgrade.sh"
    [ "$status" -ne 0 ]
}

@test "T-2755: renderer never compares versions itself" {
    # One comparator, not two (AC1). The renderer takes a relation and renders
    # it; if it starts deciding direction, the two answers can drift apart again.
    body="$(declare -f fw_upgrade_render_pin_line)"
    [[ "$body" != *"sort -V"* ]]
    [[ "$body" != *"merge-base"* ]]
    [[ "$body" != *"fw_version_relation "* ]]
}
