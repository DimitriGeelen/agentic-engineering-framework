#!/usr/bin/env bats
# T-2095 (T-2078 V1-D): self-vendor extraction into a separate verb (F2).
#
# Surfaces under test:
#   - lib/upgrade.sh:_self_vendor_libs() — extracted helper, same logic
#   - lib/upgrade.sh:do_upgrade — inline call replaced with helper call,
#     gated on --no-self-vendor flag
#   - bin/fw vendor self — explicit entry point routed to the helper
#
# AC mapping (per .tasks/active/T-2095-*.md):
#   Helper extracted (structural)            — t1
#   Helper consumer-safe early-return         — t2
#   Helper performs the same sync behavior    — t3
#   fw vendor self subcommand                 — t4 (+ t5 --help)
#   --no-self-vendor flag advertised in help  — t6
#   --no-self-vendor flag skips inline call   — t7
#   Default behavior unchanged                — t8

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t2095-XXXXXX)"
    export FRAMEWORK_ROOT
    export FW_VERSION="1.5.0"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build a minimal consumer fixture sufficient for do_upgrade to reach
# the self-vendor call site. Mirrors t2093/t2094 fixture shape.
make_consumer() {
    local proj="$1"
    mkdir -p "$proj/.agentic-framework"
    touch "$proj/.agentic-framework/FRAMEWORK.md"
    cat > "$proj/.framework.yaml" <<YAML
project_name: $(basename "$proj")
version: 1.4.0
provider: claude
YAML
}

# Build a synthetic framework tree with two lib/*.sh files and a vendored
# copy where one file diffs (needs sync) and one matches (skip). Returns
# the synthetic FRAMEWORK_ROOT path.
make_synthetic_fw_with_diff() {
    local syn_fw="$TEST_TEMP_DIR/syn-fw"
    mkdir -p "$syn_fw/lib" "$syn_fw/.agentic-framework/lib"
    # File 1: same in both (should be skipped)
    echo "# same content" > "$syn_fw/lib/same.sh"
    echo "# same content" > "$syn_fw/.agentic-framework/lib/same.sh"
    # File 2: differs (should be synced)
    echo "# new version" > "$syn_fw/lib/changed.sh"
    echo "# old version" > "$syn_fw/.agentic-framework/lib/changed.sh"
    echo "$syn_fw"
}

# ─────────────────────────────────────────────────────────────────────────
# Helper structural
# ─────────────────────────────────────────────────────────────────────────

@test "t2095 t1: _self_vendor_libs() helper extracted in lib/upgrade.sh" {
    local fw_src="$FRAMEWORK_ROOT/lib/upgrade.sh"
    grep -qE '^_self_vendor_libs\(\) \{' "$fw_src"
    # Inline call site uses the helper (not the inlined block)
    grep -qE '_self_vendor_libs "\$dry_run"' "$fw_src"
}

# ─────────────────────────────────────────────────────────────────────────
# Helper consumer-safety
# ─────────────────────────────────────────────────────────────────────────

@test "t2095 t2: helper consumer-safe early-return when no .agentic-framework/lib" {
    # Consumer scenario: FRAMEWORK_ROOT/.agentic-framework/lib does NOT exist.
    local consumer_like="$TEST_TEMP_DIR/no-vendored-dir"
    mkdir -p "$consumer_like/lib"
    echo "# would-be sync" > "$consumer_like/lib/test.sh"
    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$consumer_like"
    run _self_vendor_libs "false"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    # Helper said nothing — no sync line, no error
    [[ "$output" != *"Self-vendor:"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# Helper sync behaviour preserved
# ─────────────────────────────────────────────────────────────────────────

@test "t2095 t3: helper syncs only the diffed file (idempotent on match)" {
    local syn_fw
    syn_fw=$(make_synthetic_fw_with_diff)
    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$syn_fw"
    run _self_vendor_libs "false"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    # synced 1 file (changed.sh); same.sh skipped
    [[ "$output" == *"synced 1 file"* ]]
    # changed.sh now matches the source
    diff -q "$syn_fw/lib/changed.sh" "$syn_fw/.agentic-framework/lib/changed.sh"
    # same.sh untouched (still matches; same content)
    diff -q "$syn_fw/lib/same.sh" "$syn_fw/.agentic-framework/lib/same.sh"
}

@test "t2095 t4: helper dry-run reports the would-sync count without copying" {
    local syn_fw
    syn_fw=$(make_synthetic_fw_with_diff)
    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$syn_fw"
    run _self_vendor_libs "true"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    [[ "$output" == *"synced 1 file"* ]]
    # Dry-run: the vendored copy is NOT mutated (still differs from source)
    ! diff -q "$syn_fw/lib/changed.sh" "$syn_fw/.agentic-framework/lib/changed.sh" >/dev/null 2>&1
}

# ─────────────────────────────────────────────────────────────────────────
# fw vendor self subcommand
# ─────────────────────────────────────────────────────────────────────────

@test "t2095 t5: fw vendor self --help prints the new subcommand help" {
    run "$FRAMEWORK_ROOT/bin/fw" vendor self --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw vendor self"* ]]
    [[ "$output" == *"T-2095"* ]] || [[ "$output" == *"T-2078"* ]]
    [[ "$output" == *".agentic-framework/lib"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# do_upgrade --help advertises --no-self-vendor
# ─────────────────────────────────────────────────────────────────────────

@test "t2095 t6: do_upgrade --help advertises --no-self-vendor flag" {
    run do_upgrade --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--no-self-vendor"* ]]
    [[ "$output" == *"T-1217"* ]] || [[ "$output" == *"T-2095"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# --no-self-vendor flag skips inline call
# ─────────────────────────────────────────────────────────────────────────

@test "t2095 t7: --no-self-vendor flag emits 'Self-vendor skipped' and bypasses helper" {
    local proj="$TEST_TEMP_DIR/no-self-vendor-proj"
    make_consumer "$proj"
    # Stub do_vendor to fail at step 4b so the test exits quickly.
    do_vendor() { return 0; }
    export -f do_vendor 2>/dev/null || true
    # Trip-wire: stub _self_vendor_libs to indicate IF called.
    _self_vendor_libs() { echo "TRIP-WIRE: helper was called despite --no-self-vendor" >&2; return 0; }
    export -f _self_vendor_libs 2>/dev/null || true

    run do_upgrade "$proj" --dry-run --no-self-vendor
    [[ "$output" == *"Self-vendor skipped"* ]]
    [[ "$output" != *"TRIP-WIRE: helper was called"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# Default behaviour unchanged (no flag → helper called)
# ─────────────────────────────────────────────────────────────────────────

@test "t2095 t8: default (no flag) calls _self_vendor_libs (inline behavior preserved)" {
    local proj="$TEST_TEMP_DIR/default-proj"
    make_consumer "$proj"
    do_vendor() { return 0; }
    export -f do_vendor 2>/dev/null || true
    # Mark when the helper is called.
    _self_vendor_libs() { echo "HELPER_CALLED with dry_run=$1"; return 0; }
    export -f _self_vendor_libs 2>/dev/null || true

    run do_upgrade "$proj" --dry-run
    [[ "$output" == *"HELPER_CALLED with dry_run=true"* ]]
    # Skip message must NOT appear under default
    [[ "$output" != *"Self-vendor skipped"* ]]
}
