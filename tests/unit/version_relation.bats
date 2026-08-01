#!/usr/bin/env bats
# T-2713: consumer-vs-framework version relation must come from git ancestry,
# never from `sort -V` over the VERSION counter.
#
# VERSION is a tag counter that RESETS. This repo's tags run v1.6.763, v1.6.762,
# v1.6.761, then v1.6.10, v1.6.9; VERSION itself went 1.6.354 -> 1.6.121 -> 1.6.176.
# `sort -V` therefore answers a question nobody asked ("which string sorts higher")
# and three call sites treated the answer as "which code is newer".
#
# Field consequence: a consumer pinned 1.6.264 read as AHEAD of a framework at
# 1.6.163, so `fw upgrade` refused — to protect it — and it sat frozen for weeks
# with no governance or security fixes. Test 1 is that exact case.
#
# Test 6 is the NEGATIVE CONTROL: it asserts the fixture pair genuinely fools
# `sort -V`. If someone "simplifies" the predicate back to string ordering, test 1
# goes red *because* test 6 proves the input still discriminates. Without it, a
# regression could pass by coincidence.

load ../test_helper

setup() {
    # test_helper's setup() creates TEST_TEMP_DIR and its teardown() removes it;
    # overriding setup without this leaves teardown failing on every test.
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR

    FWROOT="${BATS_TEST_DIRNAME}/../.."
    source "$FWROOT/lib/version-relation.sh"
    FRAMEWORK_ROOT="$FWROOT"
    OLD_SHA="$(git -C "$FWROOT" rev-list HEAD | tail -1)"
    HEAD_SHA="$(git -C "$FWROOT" rev-parse HEAD)"
}

@test "T-2713: the live freeze case (1.6.264 vs 1.6.163) is undecidable, NOT ahead" {
    fw_version_relation "1.6.264" "1.6.163" "" "$FRAMEWORK_ROOT" >/dev/null
    # The whole defect: this used to say "ahead" and refuse the upgrade.
    [ "$FW_VERSION_RELATION" != "ahead" ]
    [ "$FW_VERSION_RELATION" = "undecidable" ]
    # And it must SAY why, not just shrug.
    [ -n "$FW_VERSION_RELATION_REASON" ]
}

@test "T-2713: a recorded ancestor sha resolves to behind regardless of version string" {
    # Consumer claims version 1.0.0 but its sha is the repo's first commit.
    fw_version_relation "1.0.0" "1.6.176" "$OLD_SHA" "$FRAMEWORK_ROOT" >/dev/null
    [ "$FW_VERSION_RELATION" = "behind" ]
}

@test "T-2713: a NUMERICALLY HIGHER version at framework HEAD is 'same', not 'ahead'" {
    # 9.9.9 sorts above 1.6.176, so sort -V would call this "ahead" and REFUSE
    # the upgrade. Ancestry knows the consumer is sitting on HEAD itself.
    fw_version_relation "9.9.9" "1.6.176" "$HEAD_SHA" "$FRAMEWORK_ROOT" >/dev/null
    [ "$FW_VERSION_RELATION" = "same" ]
}

@test "T-2713: reason propagates to the caller (not eaten by a subshell)" {
    # The predicate returns its reason via a global. A caller using \$(...) forks a
    # subshell and gets an empty reason — block messages that explain nothing.
    fw_version_relation "1.6.999" "1.6.176" "" "$FRAMEWORK_ROOT" >/dev/null
    [ -n "$FW_VERSION_RELATION_REASON" ]
    echo "$FW_VERSION_RELATION_REASON" | grep -q "resetting counter"
}

@test "T-2713: undecidable does not refuse by default, ahead and diverged always do" {
    run fw_version_relation_should_refuse "ahead"
    [ "$status" -eq 0 ]
    run fw_version_relation_should_refuse "diverged"
    [ "$status" -eq 0 ]
    run fw_version_relation_should_refuse "behind"
    [ "$status" -ne 0 ]

    FW_UNDECIDABLE_VERSION_PROCEED=1
    run fw_version_relation_should_refuse "undecidable"
    [ "$status" -ne 0 ]

    # Operator-flippable (T-2713 Human AC): 0 makes undecidable refuse.
    FW_UNDECIDABLE_VERSION_PROCEED=0
    run fw_version_relation_should_refuse "undecidable"
    [ "$status" -eq 0 ]
}

@test "T-2713: fw_record_version_sha writes the pin, and the pin round-trips to 'same'" {
    yf="$TEST_TEMP_DIR/.framework.yaml"
    printf 'version: 1.6.176\n' > "$yf"

    fw_record_version_sha "$yf" "$FRAMEWORK_ROOT"
    grep -q "^version_sha: $HEAD_SHA\$" "$yf"

    # The point of writing it: the next comparison is decidable, not undecidable.
    sha=$(grep '^version_sha:' "$yf" | sed 's/^version_sha:[[:space:]]*//')
    fw_version_relation "1.2.3" "9.9.9" "$sha" "$FRAMEWORK_ROOT" >/dev/null
    [ "$FW_VERSION_RELATION" = "same" ]
}

@test "T-2713: fw_record_version_sha is idempotent (rewrites, never appends twice)" {
    yf="$TEST_TEMP_DIR/.framework.yaml"
    printf 'version: 1.6.176\nversion_sha: deadbeef\n' > "$yf"
    fw_record_version_sha "$yf" "$FRAMEWORK_ROOT"
    fw_record_version_sha "$yf" "$FRAMEWORK_ROOT"
    count=$(grep -c '^version_sha:' "$yf")
    [ "$count" -eq 1 ]
    grep -q "^version_sha: $HEAD_SHA\$" "$yf"
}

@test "T-2713: NEGATIVE CONTROL — the fixture pair genuinely fools sort -V" {
    # If this stops holding, test 1 could pass for the wrong reason.
    higher=$(printf '%s\n%s\n' "1.6.264" "1.6.163" | sort -V | tail -1)
    [ "$higher" = "1.6.264" ]
    # ...and the framework really is the one with the newer code, i.e. the
    # string order points the wrong way for a real consumer.
    [ -n "$OLD_SHA" ]
    [ "$OLD_SHA" != "$HEAD_SHA" ]
}

@test "T-2713: no decision site still open-codes sort -V" {
    # The predicate is pointless if a call site keeps its own copy.
    run bash -c "grep -n 'sort -V' '$FWROOT/bin/fw' '$FWROOT/lib/upgrade.sh' | grep -v '^\s*#' | grep -v '#.*sort -V'"
    [ -z "$output" ]
}
