#!/usr/bin/env bats
# T-3714: a SHALLOW framework clone cannot see a consumer's recorded
# version_sha by construction. fw_version_relation used to convict it as a
# FOREIGN source ("it cannot be the origin of the consumer's code"), and the
# upgrade block sent the reader after a stale global shim. Reported by 055
# (2026-10-02) and 832 (2026-10-05, a --depth 1 clone of v1.8.2).
#
# Contract: still refuse (the commit is unverifiable), but name the shallow
# clone and the one-command remedy. The full-history foreign case keeps its
# own reason (control), and unshallowing turns the same pair into `behind`.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    FWROOT="${BATS_TEST_DIRNAME}/../.."
    source "$FWROOT/lib/version-relation.sh"
    local g=(git -c user.name=t3714 -c user.email=t3714@example.invalid)
    git init -q "$TEST_TEMP_DIR/up"
    "${g[@]}" -C "$TEST_TEMP_DIR/up" commit -q --allow-empty -m a
    A_SHA="$(git -C "$TEST_TEMP_DIR/up" rev-parse HEAD)"
    "${g[@]}" -C "$TEST_TEMP_DIR/up" commit -q --allow-empty -m b
    git clone -q --depth 1 "file://$TEST_TEMP_DIR/up" "$TEST_TEMP_DIR/shallow"
    git init -q "$TEST_TEMP_DIR/other"
    "${g[@]}" -C "$TEST_TEMP_DIR/other" commit -q --allow-empty -m unrelated
}

@test "t3714: fixture really is shallow and really lacks the consumer's commit" {
    run fw_source_is_shallow "$TEST_TEMP_DIR/shallow"; [ "$status" -eq 0 ]
    run fw_source_is_shallow "$TEST_TEMP_DIR/up"; [ "$status" -ne 0 ]
    run git -C "$TEST_TEMP_DIR/shallow" rev-parse -q --verify "${A_SHA}^{commit}"
    [ "$status" -ne 0 ]
}

@test "t3714: shallow source still refuses, but names the shallow clone and the remedy" {
    fw_version_relation 1.7.740 1.8.2 "$A_SHA" "$TEST_TEMP_DIR/shallow" >/dev/null
    [ "$FW_VERSION_RELATION" = "foreign-source" ]
    run fw_version_relation_should_refuse "$FW_VERSION_RELATION"; [ "$status" -eq 0 ]
    [[ "$FW_VERSION_RELATION_REASON" == *"SHALLOW clone"* ]]
    [[ "$FW_VERSION_RELATION_REASON" == *"fetch --unshallow"* ]]
    [[ "$FW_VERSION_RELATION_REASON" != *"cannot be the origin"* ]]
}

@test "t3714: after fetch --unshallow the same pair resolves to behind" {
    git -C "$TEST_TEMP_DIR/shallow" fetch -q --unshallow
    fw_version_relation 1.7.740 1.8.2 "$A_SHA" "$TEST_TEMP_DIR/shallow" >/dev/null
    [ "$FW_VERSION_RELATION" = "behind" ]
}

@test "t3714: CONTROL — a full-history foreign source keeps the foreign reason" {
    fw_version_relation 1.7.740 1.8.2 "$A_SHA" "$TEST_TEMP_DIR/other" >/dev/null
    [ "$FW_VERSION_RELATION" = "foreign-source" ]
    [[ "$FW_VERSION_RELATION_REASON" == *"cannot be the origin"* ]]
    [[ "$FW_VERSION_RELATION_REASON" != *"unshallow"* ]]
}
