#!/usr/bin/env bats
# T-2241 (F2 N×M follow-on to T-2095 / T-2240): self-vendor templates helper.
#
# Surfaces under test:
#   - lib/upgrade.sh:_self_vendor_templates() — sibling to _self_vendor_libs(),
#     same structural shape, syncs FRAMEWORK_ROOT/.tasks/templates/*.md to
#     .agentic-framework/.tasks/templates/
#   - lib/upgrade.sh:do_upgrade — invokes BOTH helpers (libs + templates) under
#     the same --no-self-vendor flag
#   - bin/fw vendor self — invokes BOTH helpers; --help mentions both classes
#
# AC mapping (per .tasks/active/T-2241-*.md):
#   Slice 1 helper extracted (structural)        — t1
#   Slice 1 consumer-safe early-return            — t2
#   Slice 1 same sync behaviour, dry-run wording  — t3 (real) + t4 (dry-run)
#   Slice 2 do_upgrade calls both helpers          — t5
#   Slice 3 fw vendor self --help mentions both    — t6
#   Slice 3 fw vendor self invokes both helpers    — t7

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t2241-XXXXXX)"
    export FRAMEWORK_ROOT
    export FW_VERSION="1.5.0"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build a synthetic framework tree with two templates and a vendored copy
# where one template diffs (needs sync) and one matches (skip).
make_synthetic_fw_with_template_diff() {
    local syn_fw="$TEST_TEMP_DIR/syn-fw-templates"
    mkdir -p "$syn_fw/.tasks/templates" "$syn_fw/.agentic-framework/.tasks/templates"
    # Template 1: same in both (should be skipped)
    echo "# same template" > "$syn_fw/.tasks/templates/same.md"
    echo "# same template" > "$syn_fw/.agentic-framework/.tasks/templates/same.md"
    # Template 2: differs (should be synced)
    echo "# new version" > "$syn_fw/.tasks/templates/changed.md"
    echo "# old version" > "$syn_fw/.agentic-framework/.tasks/templates/changed.md"
    echo "$syn_fw"
}

# Minimal consumer fixture (no .agentic-framework/.tasks/templates/ → guard skips).
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

# ─────────────────────────────────────────────────────────────────────────
# Helper structural
# ─────────────────────────────────────────────────────────────────────────

@test "t2241 t1: _self_vendor_templates() helper extracted in lib/upgrade.sh" {
    local fw_src="$FRAMEWORK_ROOT/lib/upgrade.sh"
    grep -qE '^_self_vendor_templates\(\) \{' "$fw_src"
    # Inline call site: do_upgrade invokes _self_vendor_templates alongside _self_vendor_libs
    grep -qE '_self_vendor_templates "\$dry_run"' "$fw_src"
}

# ─────────────────────────────────────────────────────────────────────────
# Helper consumer-safety
# ─────────────────────────────────────────────────────────────────────────

@test "t2241 t2: helper consumer-safe early-return when no .agentic-framework/.tasks/templates" {
    local consumer_like="$TEST_TEMP_DIR/no-vendored-templates-dir"
    mkdir -p "$consumer_like/.tasks/templates"
    echo "# would-be sync" > "$consumer_like/.tasks/templates/test.md"
    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$consumer_like"
    run _self_vendor_templates "false"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    [[ "$output" != *"Self-vendor:"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# Helper sync behaviour preserved
# ─────────────────────────────────────────────────────────────────────────

@test "t2241 t3: helper syncs only the diffed template (idempotent on match)" {
    local syn_fw
    syn_fw=$(make_synthetic_fw_with_template_diff)
    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$syn_fw"
    run _self_vendor_templates "false"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    # synced 1 template (changed.md); same.md skipped
    [[ "$output" == *"synced 1 template"* ]]
    # changed.md now matches the source
    diff -q "$syn_fw/.tasks/templates/changed.md" "$syn_fw/.agentic-framework/.tasks/templates/changed.md"
    # same.md untouched
    diff -q "$syn_fw/.tasks/templates/same.md" "$syn_fw/.agentic-framework/.tasks/templates/same.md"
}

@test "t2241 t4: helper dry-run reports 'would sync N template(s)' without copying" {
    local syn_fw
    syn_fw=$(make_synthetic_fw_with_template_diff)
    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$syn_fw"
    run _self_vendor_templates "true"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    [[ "$output" == *"would sync 1 template"* ]]
    # Dry-run must NOT print the real-run verb (catches regression of the split)
    [[ "$output" != *"Self-vendor:"*" synced 1 template"* ]]
    # Dry-run: the vendored copy is NOT mutated
    ! diff -q "$syn_fw/.tasks/templates/changed.md" "$syn_fw/.agentic-framework/.tasks/templates/changed.md" >/dev/null 2>&1
}

# ─────────────────────────────────────────────────────────────────────────
# do_upgrade calls both helpers (Slice 2)
# ─────────────────────────────────────────────────────────────────────────

@test "t2241 t5: do_upgrade --dry-run invokes BOTH _self_vendor_libs AND _self_vendor_templates" {
    local proj="$TEST_TEMP_DIR/both-helpers-proj"
    make_consumer "$proj"
    do_vendor() { return 0; }
    export -f do_vendor 2>/dev/null || true
    # Mark when each helper is called.
    _self_vendor_libs() { echo "LIBS_CALLED with dry_run=$1"; return 0; }
    _self_vendor_templates() { echo "TEMPLATES_CALLED with dry_run=$1"; return 0; }
    export -f _self_vendor_libs _self_vendor_templates 2>/dev/null || true

    run do_upgrade "$proj" --dry-run
    [[ "$output" == *"LIBS_CALLED with dry_run=true"* ]]
    [[ "$output" == *"TEMPLATES_CALLED with dry_run=true"* ]]
    # --no-self-vendor flag must still skip BOTH (Slice 2 spec)
    run do_upgrade "$proj" --dry-run --no-self-vendor
    [[ "$output" == *"Self-vendor skipped"* ]]
    [[ "$output" != *"LIBS_CALLED"* ]]
    [[ "$output" != *"TEMPLATES_CALLED"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# fw vendor self verb parity (Slice 3)
# ─────────────────────────────────────────────────────────────────────────

@test "t2241 t6: fw vendor self --help mentions BOTH classes (lib + templates)" {
    run "$FRAMEWORK_ROOT/bin/fw" vendor self --help
    [ "$status" -eq 0 ]
    [[ "$output" == *".agentic-framework/lib"* ]]
    [[ "$output" == *".agentic-framework/.tasks/templates"* ]]
    [[ "$output" == *"T-2241"* ]]
}

@test "t2241 t7: fw vendor self --dry-run output covers BOTH classes (when both drift)" {
    # Live integration: the framework's own state must be clean by this point
    # (the build/refresh already happened in the parent session). Force drift
    # in a synthetic root and run via the real `bin/fw vendor self` flow.
    local syn_fw="$TEST_TEMP_DIR/syn-fw-bothclasses"
    mkdir -p "$syn_fw/lib" "$syn_fw/.agentic-framework/lib"
    mkdir -p "$syn_fw/.tasks/templates" "$syn_fw/.agentic-framework/.tasks/templates"
    # lib drift
    echo "# new lib" > "$syn_fw/lib/changed.sh"
    echo "# old lib" > "$syn_fw/.agentic-framework/lib/changed.sh"
    # template drift
    echo "# new tpl" > "$syn_fw/.tasks/templates/changed.md"
    echo "# old tpl" > "$syn_fw/.agentic-framework/.tasks/templates/changed.md"

    # Source helpers from real framework, then point FRAMEWORK_ROOT at the synthetic tree.
    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$syn_fw"
    run bash -c "source '$saved/lib/colors.sh'; source '$saved/lib/upgrade.sh'; _self_vendor_libs true; _self_vendor_templates true"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    [[ "$output" == *"would sync 1 file"* ]]
    [[ "$output" == *"would sync 1 template"* ]]
}
