#!/usr/bin/env bats
# T-2443 (F4, T-2442 batch): a fresh `fw init` must scaffold a
# policy/value-drivers.yaml that passes its OWN #@init self-validation.
#
# Regression origin: T-2441 onboarding dogfood — every fresh project printed
#   "Validation: 1 error … yaml-2bv policy/value-drivers.yaml … missing keys: drivers".
# Root cause: lib/init.sh carried `#@init: yaml-2bv policy/value-drivers.yaml drivers`
# but the canonical v3 schema (T-1918/arc-006) has no top-level `drivers:` key —
# it uses `protected_drivers:` + `free_drivers:`. The required-key argument drifted
# from the schema it validates, and no test exercised init against its own validator.
#
# These tests fail with the stale `drivers` key and pass once it is corrected.

load ../test_helper

setup() {
    unset PROJECT_ROOT  # L-456: avoid project-root leak from the parent shell
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    [ -f "$FRAMEWORK_ROOT/policy/value-drivers.yaml" ] || \
        skip "framework template missing — broken install"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ------------------------------------------------------------- contract test
# Direct annotation↔schema contract: the #@init required key(s) for
# value-drivers.yaml must NOT be the stale `drivers`, and each must exist as a
# top-level key in the canonical template. Fast, deterministic, no node/python.
@test "F4: #@init value-drivers required key exists in canonical template (not stale 'drivers')" {
    local line
    line=$(grep -E '#@init: yaml-[0-9a-z]+ policy/value-drivers\.yaml ' "$FRAMEWORK_ROOT/lib/init.sh")
    [ -n "$line" ]

    # Last whitespace-delimited field = required key(s), comma-separated.
    local keys="${line##* }"

    # Regression signature: the stale `drivers` key is gone.
    [ "$keys" != "drivers" ]

    # Every required key must be a real top-level key in the canonical file.
    local k
    IFS=',' read -ra karr <<< "$keys"
    for k in "${karr[@]}"; do
        grep -qE "^${k}[[:space:]]*:" "$FRAMEWORK_ROOT/policy/value-drivers.yaml"
    done
}

# ------------------------------------------------------------------ e2e test
# Scaffold value-drivers.yaml exactly as `fw init` does (same cp from
# FRAMEWORK_ROOT; lib/init.sh:308 == `fw bvp driver --init`), then run the real
# `fw validate-init`, which reads the #@init annotation from lib/init.sh. The
# value-drivers.yaml line must not report the F4 regression.
@test "F4: validate-init reports no missing-key error on a scaffolded value-drivers.yaml" {
    env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" bvp driver --init >/dev/null

    run env FRAMEWORK_ROOT="$FRAMEWORK_ROOT" PROJECT_ROOT="$TEST_TEMP_DIR" \
        "$FRAMEWORK_ROOT/bin/fw" validate-init "$TEST_TEMP_DIR" --provider claude

    # The F4 regression signature must be absent.
    local rc=0
    echo "$output" | grep -q "missing keys: drivers" || rc=$?
    [ "$rc" -ne 0 ]

    # And there must be no missing-key error at all (value-drivers is the only
    # yaml-key check on a freshly-scaffolded policy/ in this slice).
    rc=0
    echo "$output" | grep -q "missing keys" || rc=$?
    [ "$rc" -ne 0 ]
}
