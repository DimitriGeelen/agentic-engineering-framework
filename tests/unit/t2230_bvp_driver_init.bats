#!/usr/bin/env bats
# T-2230 (T-2229 Slice 1): `fw bvp driver --init` consumer policy bootstrap.
#
# Verifies the verb the existing error message at lib/bvp.sh:133 already
# promises. Idempotent by default, --force overrides. Not §ACD-gated.
#
# Covers: create path, idempotent path, --force overwrite, rank-after-init,
# error-message rewrite, help/usage advertisement.

load ../test_helper

setup() {
    # test_helper.bash already sets FRAMEWORK_ROOT + TEST_TEMP_DIR; we just
    # need an isolated PROJECT_ROOT pointing at a fresh consumer-shaped dir.
    unset PROJECT_ROOT  # T-2185 / L-456: avoid project-root leak from parent shell
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR

    # Framework template MUST exist for these tests to be meaningful.
    [ -f "$FRAMEWORK_ROOT/policy/value-drivers.yaml" ] || \
        skip "framework template missing — broken install"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ---------------------------------------------------------------- create path

@test "fw bvp driver --init creates policy/value-drivers.yaml in empty project" {
    [ ! -f "$TEST_TEMP_DIR/policy/value-drivers.yaml" ]

    run env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" bvp driver --init
    [ "$status" -eq 0 ]
    [ -f "$TEST_TEMP_DIR/policy/value-drivers.yaml" ]
    echo "$output" | grep -q "created from framework template"
}

@test "created file is byte-identical to framework template" {
    env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" bvp driver --init >/dev/null
    rc=0
    cmp -s "$FRAMEWORK_ROOT/policy/value-drivers.yaml" \
           "$TEST_TEMP_DIR/policy/value-drivers.yaml" || rc=$?
    [ "$rc" -eq 0 ]
}

# ----------------------------------------------------------- idempotent path

@test "fw bvp driver --init is idempotent — refuses to overwrite without --force" {
    # First call creates.
    env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" bvp driver --init >/dev/null
    # Mutate the file so we can detect overwrite.
    echo "# CONSUMER-CUSTOMISATION-MARKER" >> "$TEST_TEMP_DIR/policy/value-drivers.yaml"

    run env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" bvp driver --init
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "already exists"
    # The customisation marker must survive.
    grep -q "CONSUMER-CUSTOMISATION-MARKER" "$TEST_TEMP_DIR/policy/value-drivers.yaml"
}

# ------------------------------------------------------------- --force path

@test "fw bvp driver --init --force overwrites an existing file" {
    env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" bvp driver --init >/dev/null
    echo "# CONSUMER-CUSTOMISATION-MARKER" >> "$TEST_TEMP_DIR/policy/value-drivers.yaml"

    run env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" bvp driver --init --force
    [ "$status" -eq 0 ]
    # Marker must be GONE — file overwritten from template.
    rc=0
    grep -q "CONSUMER-CUSTOMISATION-MARKER" "$TEST_TEMP_DIR/policy/value-drivers.yaml" || rc=$?
    [ "$rc" -ne 0 ]
}

# ------------------------------------------------------ rank-after-init smoke

@test "after --init, fw bvp no longer emits 'policy file not found'" {
    env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" bvp driver --init >/dev/null

    # `fw bvp` (rank) needs .tasks/{active,completed}/ to exist; create empty dirs.
    mkdir -p "$TEST_TEMP_DIR/.tasks/active" "$TEST_TEMP_DIR/.tasks/completed"

    run env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" bvp
    # No policy-not-found error in stderr/stdout.
    rc=0
    echo "$output" | grep -q "policy file not found" || rc=$?
    [ "$rc" -ne 0 ]
}

# ---------------------------------------------------- error-message rewrite

@test "lib/bvp.sh no longer references 'once T-1920 ships' (dead reference removed)" {
    rc=0
    grep -q "once T-1920 ships" "$FRAMEWORK_ROOT/lib/bvp.sh" || rc=$?
    [ "$rc" -ne 0 ]
}

@test "lib/bvp.sh error path points at the working verb" {
    grep -q "Bootstrap with: fw bvp driver --init" "$FRAMEWORK_ROOT/lib/bvp.sh"
}

# ----------------------------------------------------- usage advertisement

@test "fw bvp driver (no args) shows --init in usage" {
    run env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" bvp driver
    # exit code 2 (usage) is expected.
    [ "$status" -eq 2 ]
    echo "$output" | grep -q -- "--init"
}

@test "fw bvp --help advertises driver --init" {
    run env PROJECT_ROOT="$FRAMEWORK_ROOT" "$FRAMEWORK_ROOT/bin/fw" bvp --help
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "driver --init"
}

# --------------------------------------------------- §ACD: not gated for --init

@test "--init is NOT §ACD-gated (works under simulated CLAUDECODE=1)" {
    # T-2230: bootstrap is sovereignty-neutral; agents may run it.
    # Customisation (weight, --add, --remove) IS gated separately.
    run env CLAUDECODE=1 PROJECT_ROOT="$TEST_TEMP_DIR" \
        "$FRAMEWORK_ROOT/bin/fw" bvp driver --init
    [ "$status" -eq 0 ]
    [ -f "$TEST_TEMP_DIR/policy/value-drivers.yaml" ]
}
