#!/usr/bin/env bats
# T-2266 (T-2240 closure-arc): self-vendor agents/ helper (5th class).
#
# Surfaces under test:
#   - lib/upgrade.sh:_self_vendor_agents() — sibling to _self_vendor_libs/templates/policy/shim,
#     same structural shape, RECURSIVE over subdirs filtered to *.sh + *.py
#     (matches audit.sh:1534's exact drift-scan filter).
#   - lib/upgrade.sh:do_upgrade — invokes ALL FIVE helpers (libs + templates + policy
#     + shim + agents) under the same --no-self-vendor flag.
#   - bin/fw vendor self — invokes ALL FIVE helpers; --help mentions all classes.
#
# AC mapping (per .tasks/active/T-2266-*.md):
#   helper exists + sibling shape           — t1
#   consumer-safe early-return              — t2
#   real-run syncs diffed files recursively — t3
#   dry-run reports "would sync N agents/"  — t4
#   do_upgrade calls helper                 — t5
#   fw vendor self --help lists agents/     — t6
#   fw vendor self --dry-run live drift     — t7

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t2266-XXXXXX)"
    export FRAMEWORK_ROOT
    export FW_VERSION="1.6.37"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build a synthetic framework tree with two subdirs holding *.sh and *.py:
#   agents/foo/same.sh   == .agentic-framework/agents/foo/same.sh   (skip)
#   agents/foo/changed.sh != .agentic-framework/agents/foo/changed.sh (sync)
#   agents/bar/new.py     missing in vendored                         (sync)
#   agents/extra/ignored.md (filter excludes — never synced)
make_synthetic_fw_with_agents_diff() {
    local syn_fw="$TEST_TEMP_DIR/syn-fw-agents"
    mkdir -p "$syn_fw/agents/foo" "$syn_fw/agents/bar" "$syn_fw/agents/extra"
    mkdir -p "$syn_fw/.agentic-framework/agents/foo" "$syn_fw/.agentic-framework/agents/bar"
    # same — should be skipped
    echo "echo same" > "$syn_fw/agents/foo/same.sh"
    echo "echo same" > "$syn_fw/.agentic-framework/agents/foo/same.sh"
    # changed — should be synced
    echo "echo new" > "$syn_fw/agents/foo/changed.sh"
    echo "echo old" > "$syn_fw/.agentic-framework/agents/foo/changed.sh"
    # new — missing in vendored, should be synced (recursive subdir creation)
    echo "print('new')" > "$syn_fw/agents/bar/new.py"
    # excluded — filter is *.sh + *.py only
    echo "# markdown" > "$syn_fw/agents/extra/ignored.md"
    echo "$syn_fw"
}

# Minimal consumer fixture (no .agentic-framework/agents/ → guard skips).
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

@test "t2266 t1: _self_vendor_agents() helper extracted in lib/upgrade.sh + wired in do_upgrade" {
    local fw_src="$FRAMEWORK_ROOT/lib/upgrade.sh"
    grep -qE '^_self_vendor_agents\(\) \{' "$fw_src"
    grep -qE '_self_vendor_agents "\$dry_run"' "$fw_src"
}

# ─────────────────────────────────────────────────────────────────────────
# Helper consumer-safety
# ─────────────────────────────────────────────────────────────────────────

@test "t2266 t2: helper consumer-safe early-return when no .agentic-framework/agents" {
    local consumer_like="$TEST_TEMP_DIR/no-vendored-agents-dir"
    mkdir -p "$consumer_like/agents/foo"
    echo "echo would-be sync" > "$consumer_like/agents/foo/test.sh"
    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$consumer_like"
    run _self_vendor_agents "false"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    [[ "$output" != *"Self-vendor:"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# Helper sync behaviour
# ─────────────────────────────────────────────────────────────────────────

@test "t2266 t3: helper syncs diffed + new files recursively, skips matches + non-{sh,py}" {
    local syn_fw
    syn_fw=$(make_synthetic_fw_with_agents_diff)
    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$syn_fw"
    run _self_vendor_agents "false"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    # synced 2 files (foo/changed.sh + bar/new.py); foo/same.sh skipped, extra/ignored.md filtered
    [[ "$output" == *"synced 2 agents/ file(s)"* ]]
    # changed.sh now matches the source
    diff -q "$syn_fw/agents/foo/changed.sh" "$syn_fw/.agentic-framework/agents/foo/changed.sh"
    # new.py was created in the vendored copy (subdir auto-mkdir)
    [ -f "$syn_fw/.agentic-framework/agents/bar/new.py" ]
    diff -q "$syn_fw/agents/bar/new.py" "$syn_fw/.agentic-framework/agents/bar/new.py"
    # ignored.md NOT mirrored (filter excludes)
    [ ! -f "$syn_fw/.agentic-framework/agents/extra/ignored.md" ]
}

@test "t2266 t4: helper dry-run reports 'would sync N agents/ file(s)' without copying" {
    local syn_fw
    syn_fw=$(make_synthetic_fw_with_agents_diff)
    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$syn_fw"
    run _self_vendor_agents "true"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    [[ "$output" == *"would sync 2 agents/ file(s)"* ]]
    # Dry-run must NOT print the real-run verb (catches regression of the split)
    [[ "$output" != *"Self-vendor:"*" synced 2 agents/"* ]]
    # Dry-run: the vendored copy is NOT mutated
    ! diff -q "$syn_fw/agents/foo/changed.sh" "$syn_fw/.agentic-framework/agents/foo/changed.sh" >/dev/null 2>&1
    # Dry-run: NOT created in vendored copy either
    [ ! -f "$syn_fw/.agentic-framework/agents/bar/new.py" ]
}

# ─────────────────────────────────────────────────────────────────────────
# do_upgrade calls the helper
# ─────────────────────────────────────────────────────────────────────────

@test "t2266 t5: do_upgrade --dry-run invokes _self_vendor_agents alongside siblings" {
    local proj="$TEST_TEMP_DIR/five-helpers-proj"
    make_consumer "$proj"
    do_vendor() { return 0; }
    export -f do_vendor 2>/dev/null || true
    # Mock each helper to mark when it's called.
    _self_vendor_libs() { echo "LIBS_CALLED with dry_run=$1"; return 0; }
    _self_vendor_templates() { echo "TEMPLATES_CALLED with dry_run=$1"; return 0; }
    _self_vendor_policy() { echo "POLICY_CALLED with dry_run=$1"; return 0; }
    _self_vendor_shim() { echo "SHIM_CALLED with dry_run=$1"; return 0; }
    _self_vendor_agents() { echo "AGENTS_CALLED with dry_run=$1"; return 0; }
    export -f _self_vendor_libs _self_vendor_templates _self_vendor_policy _self_vendor_shim _self_vendor_agents 2>/dev/null || true

    run do_upgrade "$proj" --dry-run
    [[ "$output" == *"AGENTS_CALLED with dry_run=true"* ]]
    # --no-self-vendor must still skip ALL FIVE (T-2095 contract)
    run do_upgrade "$proj" --dry-run --no-self-vendor
    [[ "$output" == *"Self-vendor skipped"* ]]
    [[ "$output" != *"AGENTS_CALLED"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# fw vendor self verb parity
# ─────────────────────────────────────────────────────────────────────────

@test "t2266 t6: fw vendor self --help mentions agents/ class with T-2266 annotation" {
    run "$FRAMEWORK_ROOT/bin/fw" vendor self --help
    [ "$status" -eq 0 ]
    [[ "$output" == *".agentic-framework/agents"* ]]
    [[ "$output" == *"T-2266"* ]]
}

@test "t2266 t7: fw vendor self --dry-run reports agents/ class when drift present" {
    # Synthetic FRAMEWORK_ROOT with drift in agents/ (+ a minimal sibling-pleaser
    # to make the helpers reach the agents call without other classes throwing).
    local syn_fw="$TEST_TEMP_DIR/syn-fw-agents-only"
    mkdir -p "$syn_fw/agents/foo" "$syn_fw/.agentic-framework/agents/foo"
    echo "echo new" > "$syn_fw/agents/foo/changed.sh"
    echo "echo old" > "$syn_fw/.agentic-framework/agents/foo/changed.sh"

    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$syn_fw"
    run bash -c "source '$saved/lib/colors.sh'; source '$saved/lib/upgrade.sh'; _self_vendor_agents true"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    [[ "$output" == *"would sync 1 agents/ file(s)"* ]]
}
