#!/usr/bin/env bats
# T-1838 — fw doctor asymmetric version-skew detection.
#
# Origin: T-1828 surfaced a Layer 3 consequence — framework VERSION rolled back
# (tag-counter reset) leaves consumers AHEAD of framework. The pre-T-1838 doctor
# emitted a single direction-blind remediation ("Run: fw upgrade $consumer_dir")
# for any version mismatch. In the consumer-ahead case that command would
# silently downgrade the consumer's pinned version.
#
# These tests pin the asymmetric remediation surface in bin/fw:
#   - the version relation (same | behind | ahead | ...) is computed by the shared
#     comparator lib/version-relation.sh (git ancestry, T-2713; it replaced the
#     original sort -V string comparison, which cannot order a resetting counter)
#   - behind branch preserves the "Run: fw upgrade" suggestion
#   - ahead branch emits a distinct "is AHEAD of framework" reason and the
#     remediation explicitly tells the operator NOT to run fw upgrade,
#     naming T-1828 as the context.

load ../test_helper

# test_helper provides default setup() / teardown() that creates+removes
# TEST_TEMP_DIR. We add FW_BIN as a shared variable for clarity.
FW_BIN="${FRAMEWORK_ROOT}/bin/fw"

# ── Source-level pins (cheap, fast) ──

@test "T-1838: version_relation variable is declared in consumer fleet block" {
    run grep -q "local version_relation=" "$FW_BIN"
    [ "$status" -eq 0 ]
}

@test "T-1838: version comparison goes through the shared fw_version_relation (T-2713)" {
    # Pin the comparison primitive: doctor must call the git-ancestry comparator,
    # not open-code a string comparison.
    run grep -q 'fw_version_relation' "$FW_BIN"
    [ "$status" -eq 0 ]
}

@test "T-1838: ahead branch emits 'is AHEAD of framework' reason text" {
    run grep -q 'is AHEAD of framework' "$FW_BIN"
    [ "$status" -eq 0 ]
}

@test "T-1838: ahead branch remediation tells operator NOT to run fw upgrade" {
    # The ahead branch must produce text that warns against running fw upgrade.
    run grep -q 'DO NOT run' "$FW_BIN"
    [ "$status" -eq 0 ]
}

@test "T-1838: ahead branch names T-1828 as the context for framework rollback" {
    # Without the cross-reference the operator can't find the explanation.
    run grep -q 'T-1828' "$FW_BIN"
    [ "$status" -eq 0 ]
}

@test "T-1838: behind branch still uses 'Run: fw upgrade' suggestion" {
    # Pin the unchanged behind-case text — refactor accidentally dropping it
    # would silently regress the original feature.
    run grep -q 'Run: fw upgrade $consumer_dir' "$FW_BIN"
    [ "$status" -eq 0 ]
}

@test "T-1838: bin/fw parses with bash -n after edits" {
    run bash -n "$FW_BIN"
    [ "$status" -eq 0 ]
}

# ── Behavioural pin (the shared comparator resolves the real directions) ──
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

@test "T-1838: consumer holding newer code than framework HEAD is ahead (1.6.260 vs 1.6.170)" {
    # Real input from this anchor: framework v1.6.170, termlink consumer v1.6.260.
    # The framework HEAD is the OLD commit; the consumer pinned the NEW one.
    _vr_fixture
    git -C "$VR_REPO" checkout -q "$VR_OLD"
    fw_version_relation "1.6.260" "1.6.170" "$VR_NEW" "$VR_REPO" >/dev/null
    [ "$FW_VERSION_RELATION" = "ahead" ]
}

@test "T-1838: consumer on code the framework contains is behind (1.5.999 vs 1.6.0)" {
    # Pin behind-case to catch a regression that flips the direction sense.
    _vr_fixture
    fw_version_relation "1.5.999" "1.6.0" "$VR_OLD" "$VR_REPO" >/dev/null
    [ "$FW_VERSION_RELATION" = "behind" ]
}
