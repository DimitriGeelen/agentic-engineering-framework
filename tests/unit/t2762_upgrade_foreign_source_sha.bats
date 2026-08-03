#!/usr/bin/env bats
# T-2762: a source repo that cannot resolve the consumer's recorded commit is not
# a valid upgrade source.
#
# THE DEFECT
#
# fw_version_relation resolves the consumer's commit inside $froot — the framework
# doing the upgrading (lib/version-relation.sh:86,89). A stale or foreign source is
# exactly the repo that does NOT contain the consumer's sha or version tag, so cref
# comes back empty and the relation is `undecidable`. With
# FW_UNDECIDABLE_VERSION_PROCEED defaulting to 1, that WARNs and proceeds — and the
# consumer is downgraded by a source that never held its code.
#
# Measured before the fix, with the field numbers from the 2026-08-03 report:
#
#     consumer 1.6.295 / framework 1.6.121 / sha absent from source
#       relation:      undecidable
#       should_refuse: NO  -> PROCEEDS
#
# WHY THE OLD BUCKET IS WRONG
#
# Two very different states collapsed into one `undecidable`:
#
#   (a) legacy pin, no sha recorded at all   -> genuinely no evidence; proceeding
#                                               with a warning is defensible, and
#                                               refusing would brick legacy consumers
#   (b) sha recorded, source cannot resolve  -> NOT an absence of evidence. It is
#                                               positive evidence about the source:
#                                               a repo that does not contain the
#                                               consumer's history cannot be its
#                                               upgrade source
#
# (b) is the field failure. Splitting it out of (a) is the whole fix.
#
# WHY A PATH COMPARISON WOULD NOT HAVE WORKED
#
# T-2761 first framed this as "refuse when FRAMEWORK_ROOT != target/.agentic-framework".
# That is the SANCTIONED path — it is remediation option 3 in the existing T-1542 block
# message. Refusing on it would refuse every correct upgrade. Test 7 pins that the
# normal upstream-checkout flow still passes.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    FWROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"

    # A sha that is well-formed but cannot exist in any repo here.
    ABSENT_SHA="$(printf 'T-2762-absent' | sha1sum | cut -c1-40)"
    # A sha that genuinely lives in this framework repo.
    PRESENT_SHA="$(git -C "$FWROOT" rev-parse HEAD~5 2>/dev/null || git -C "$FWROOT" rev-parse HEAD)"

    # shellcheck source=../../lib/version-relation.sh
    source "$FWROOT/lib/version-relation.sh"
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ── unit: the relation itself ────────────────────────────────────────────────

@test "T-2762: recorded-but-unresolvable sha is NOT the same relation as no-sha" {
    fw_version_relation "1.6.295" "1.6.121" "$ABSENT_SHA" "$FWROOT" >/dev/null
    local with_sha="$FW_VERSION_RELATION"

    fw_version_relation "1.6.295" "1.6.121" "" "$FWROOT" >/dev/null
    local without_sha="$FW_VERSION_RELATION"

    # The entire defect was these two collapsing into one bucket.
    [ "$with_sha" != "$without_sha" ]
}

@test "T-2762: recorded-but-unresolvable sha refuses by default" {
    fw_version_relation "1.6.295" "1.6.121" "$ABSENT_SHA" "$FWROOT" >/dev/null
    run fw_version_relation_should_refuse "$FW_VERSION_RELATION"
    [ "$status" -eq 0 ]
}

@test "T-2762: legacy no-sha consumer still proceeds (do not brick legacy pins)" {
    # Deliberately unchanged behaviour. A consumer whose pin predates version_sha
    # has given us nothing to judge; refusing would strand it exactly the way
    # T-2713's origin case was stranded.
    fw_version_relation "1.6.295" "1.6.121" "" "$FWROOT" >/dev/null
    [ "$FW_VERSION_RELATION" = "undecidable" ]
    run fw_version_relation_should_refuse "$FW_VERSION_RELATION"
    [ "$status" -ne 0 ]
}

@test "T-2762: the bypass env var makes it proceed, and is honoured only when set" {
    fw_version_relation "1.6.295" "1.6.121" "$ABSENT_SHA" "$FWROOT" >/dev/null
    local rel="$FW_VERSION_RELATION"

    FW_ALLOW_FOREIGN_SOURCE=1 run fw_version_relation_should_refuse "$rel"
    [ "$status" -ne 0 ]

    FW_ALLOW_FOREIGN_SOURCE=0 run fw_version_relation_should_refuse "$rel"
    [ "$status" -eq 0 ]
}

@test "T-2762: the reason names the real cause and never claims no sha was recorded" {
    fw_version_relation "1.6.295" "1.6.121" "$ABSENT_SHA" "$FWROOT" >/dev/null
    # The old string said "no version_sha recorded" for a case where one WAS
    # recorded — sending the reader to add a field that is already present.
    [[ "$FW_VERSION_RELATION_REASON" != *"no version_sha recorded"* ]]
    # It must point at the source repo, which is the thing actually at fault.
    [[ "$FW_VERSION_RELATION_REASON" == *"source"* ]] || \
        [[ "$FW_VERSION_RELATION_REASON" == *"framework repo does not contain"* ]]
}

@test "T-2762: a resolvable sha is unaffected — still ordered by ancestry" {
    fw_version_relation "1.6.100" "1.6.11" "$PRESENT_SHA" "$FWROOT" >/dev/null
    [ "$FW_VERSION_RELATION" = "behind" ]
    run fw_version_relation_should_refuse "$FW_VERSION_RELATION"
    [ "$status" -ne 0 ]
}

# ── end-to-end: the field case, through real `fw upgrade` ────────────────────
#
# These assert on the GUARD'S OWN MESSAGE, never on exit status alone.
#
# Reason, measured while writing them: on this host a full `fw upgrade` aborts at
# step 4c with
#     REFUSED  /root/.local/bin/fw resolves into a framework repo
# because the global shim points into a stale checkout. That is a real and correct
# refusal — and it is unrelated to this guard, but it sets exit 1 all the same. An
# exit-status assertion therefore passed the "refuses" test and failed the "allows"
# test before a single line of the fix existed. Both were measuring the host, not
# the code.
#
# HOME is controlled for the same reason: without it these tests report on whatever
# the developer's global shim happens to point at.

_mk_consumer() {   # _mk_consumer <dir> <version> <sha>
    mkdir -p "$1"
    cat > "$1/.framework.yaml" <<EOF
project_name: $(basename "$1")
framework_root: $FWROOT
version: $2
version_sha: $3
EOF
}

@test "T-2762: fw upgrade refuses a consumer whose sha this source cannot resolve" {
    local consumer="$TEST_TEMP_DIR/consumer"
    _mk_consumer "$consumer" "9.9.999" "$ABSENT_SHA"

    HOME="$TEST_TEMP_DIR/home" run "$FWROOT/bin/fw" upgrade "$consumer" --no-self-vendor
    [ "$status" -ne 0 ]
    # Must be THIS guard, not some other refusal that happens to be non-zero.
    [[ "$output" == *"foreign-source"* ]]
    [[ "$output" == *"does not contain that commit"* ]]
    # And it must name the bypass that actually works for this relation (L-399).
    [[ "$output" == *"FW_ALLOW_FOREIGN_SOURCE=1"* ]]

    # The operator-visible symptom this guards: the pin must not have moved.
    run grep '^version: 9.9.999' "$consumer/.framework.yaml"
    [ "$status" -eq 0 ]
}

@test "T-2762: refusal fires BEFORE any mutation" {
    # The T-1912 lesson: a guard that fires after step 4b has already vendored is
    # not a guard, it is a postmortem. Nothing may exist in the consumer beyond the
    # pin we wrote.
    local consumer="$TEST_TEMP_DIR/untouched"
    _mk_consumer "$consumer" "9.9.999" "$ABSENT_SHA"

    HOME="$TEST_TEMP_DIR/home" run "$FWROOT/bin/fw" upgrade "$consumer" --no-self-vendor
    [ "$status" -ne 0 ]
    [ ! -d "$consumer/.agentic-framework" ]
    [ ! -d "$consumer/.claude" ]
    [ ! -d "$consumer/.context" ]
}

@test "T-2762: the normal upstream-checkout flow is NOT refused by this guard" {
    # Guards against the mechanism T-2761 first proposed: refusing whenever
    # FRAMEWORK_ROOT differs from target/.agentic-framework would refuse this,
    # the documented correct invocation (T-1542 remediation option 3).
    #
    # Asserts absence of THIS refusal rather than exit 0 — a bare temp dir can trip
    # unrelated steps, and that is not what this test is about.
    local consumer="$TEST_TEMP_DIR/ok-consumer"
    _mk_consumer "$consumer" "1.6.1" "$PRESENT_SHA"

    HOME="$TEST_TEMP_DIR/home" run "$FWROOT/bin/fw" upgrade "$consumer" --no-self-vendor
    [[ "$output" != *"foreign-source"* ]]
    [[ "$output" != *"FW_ALLOW_FOREIGN_SOURCE"* ]]
    # It should read as an ordinary behind-the-framework upgrade.
    [[ "$output" == *"behind v"* ]]
}

@test "T-2762: FW_ALLOW_FOREIGN_SOURCE=1 gets past the refusal end-to-end" {
    # L-399/T-1890: a bypass contract that the hook advertises but the downstream
    # path rejects is worse than none. Exercise it through the real command.
    local consumer="$TEST_TEMP_DIR/bypass"
    _mk_consumer "$consumer" "9.9.999" "$ABSENT_SHA"

    HOME="$TEST_TEMP_DIR/home" FW_ALLOW_FOREIGN_SOURCE=1 \
        run "$FWROOT/bin/fw" upgrade "$consumer" --no-self-vendor
    [[ "$output" != *"REFUSED  Consumer v9.9.999"* ]]
}
