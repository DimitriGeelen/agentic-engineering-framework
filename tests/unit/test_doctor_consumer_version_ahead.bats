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
#   - version_relation (match | behind | ahead) is computed via sort -V
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

@test "T-1838: version comparison uses sort -V (semver-aware, not string equality alone)" {
    # Pin the comparison primitive — sort -V handles dotted version numbers.
    run grep -q 'sort -V' "$FW_BIN"
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

# ── Behavioural pin (semver compare matches real-world inputs) ──

@test "T-1838: sort -V correctly identifies 1.6.260 as ahead of 1.6.170" {
    # Real input from this anchor: framework v1.6.170, termlink consumer v1.6.260.
    # Confirms the comparison primitive resolves correctly for dotted x.y.z.
    local cv="1.6.260"
    local fv="1.6.170"
    local top
    top=$(printf '%s\n%s\n' "$cv" "$fv" | sort -V | tail -1)
    [ "$top" = "$cv" ]
}

@test "T-1838: sort -V correctly identifies 1.5.999 as behind 1.6.0" {
    # Pin behind-case to catch a regression that flips the direction sense.
    local cv="1.5.999"
    local fv="1.6.0"
    local top
    top=$(printf '%s\n%s\n' "$cv" "$fv" | sort -V | tail -1)
    [ "$top" = "$fv" ]
}
