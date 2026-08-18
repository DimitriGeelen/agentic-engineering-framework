#!/usr/bin/env bats
# T-3077 — guard: running tests/governance/test_pretooluse_gates.bats must not
# touch the live Tier 0 approvals surface, at any point during the run.
#
# The defect this pins: check-tier0.sh files a real approval request when it
# blocks (.context/working/.tier0-approval.pending + the Watchtower card at
# .context/approvals/pending-<hash12>.yaml). Run against the live PROJECT_ROOT,
# the gates suite put `rm -rf /` and `git push --force origin master` on the
# operator's /approvals queue with an Approve button next to each — four times
# over four months, three of them committed to git. Approving writes the command
# HASH into .context/working/.tier0-approval, pre-authorising that exact command.
#
# Why a separate guard file rather than a teardown assertion inside the suite:
# the suite cannot credibly audit itself (a helper naming the wrong file looks
# identical to one that works — that is precisely how this survived). This file
# watches the live surface from outside, across the whole run, and holds the
# suite to the invariant whatever hook a future test reaches for.
#
# Asserted on CONTENT and on TRANSIENCE, not on a final count: a card created
# and then deleted before the suite exits still appeared on /approvals for the
# duration of the run, and must still fail here.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
GATES_SUITE="$FRAMEWORK_ROOT/tests/governance/test_pretooluse_gates.bats"

# Manifest of the live approvals surface: path + sha256 of every file, sorted.
_surface_manifest() {
    {
        find "$FRAMEWORK_ROOT/.context/approvals" -type f -print0 2>/dev/null
        find "$FRAMEWORK_ROOT/.context/working" -maxdepth 1 -name '.tier0-approval*' \
             -type f -print0 2>/dev/null
    } | sort -z | xargs -0 -r sha256sum 2>/dev/null | sort
}

# Anything that would be VISIBLE on /approvals or actionable by `fw tier0 approve`.
_live_surface_paths() {
    find "$FRAMEWORK_ROOT/.context/approvals" -maxdepth 1 -name 'pending-*.yaml' 2>/dev/null
    find "$FRAMEWORK_ROOT/.context/working" -maxdepth 1 -name '.tier0-approval*' 2>/dev/null
}

@test "T-3077 A1: gates suite leaves the live approvals surface byte-identical" {
    local before after suite_out sightings suite_pid
    suite_out="$BATS_TEST_TMPDIR/gates-suite.out"
    sightings="$BATS_TEST_TMPDIR/sightings.txt"
    : > "$sightings"

    before="$(_surface_manifest)"

    # Sample the live surface while the suite runs, so a card that is created and
    # then cleaned up before the suite exits is still caught.
    env -u BATS_TEST_NAME -u BATS_TEST_FILENAME -u BATS_TEST_NUMBER \
        -u BATS_TEST_DESCRIPTION -u BATS_TEST_TMPDIR \
        bats "$GATES_SUITE" > "$suite_out" 2>&1 &
    suite_pid=$!
    while kill -0 "$suite_pid" 2>/dev/null; do
        _live_surface_paths >> "$sightings"
        sleep 0.05
    done
    wait "$suite_pid" || true
    _live_surface_paths >> "$sightings"

    # Positive control on the guard itself: the suite must actually have run, and
    # the Tier 0 tests must still be in it and passing. Without this, a suite that
    # deleted its Tier 0 coverage would satisfy every assertion below.
    grep -q '^ok 1 ' "$suite_out"
    grep -q "^ok .* check-tier0: blocks 'git push --force' without approval$" "$suite_out"
    grep -q "^ok .* check-tier0: blocks 'rm -rf /' wildcard$" "$suite_out"

    # Nothing was ever visible on the live queue during the run.
    if [ -s "$sightings" ]; then
        echo "live Tier 0 approval artefacts observed during the run:" >&2
        sort -u "$sightings" >&2
        return 1
    fi

    # ...and nothing was left behind.
    after="$(_surface_manifest)"
    [ "$before" = "$after" ]
}

@test "T-3077: the suite never writes the GRANTED approval file" {
    # .context/working/.tier0-approval is the file that pre-authorises a command
    # hash. A test must never create it, under any root. Distinct from the pending
    # request above: this one grants real authority.
    [ ! -e "$FRAMEWORK_ROOT/.context/working/.tier0-approval" ] \
        || skip "operator has a live grant in place; not a test artefact"
    run bats "$GATES_SUITE"
    [ ! -e "$FRAMEWORK_ROOT/.context/working/.tier0-approval" ]
}
