#!/usr/bin/env bats
# T-2267 (T-2240 closure-arc): self-vendor web/ helper (6th class).
#
# Surfaces under test:
#   - lib/upgrade.sh:_self_vendor_web() — sibling to _self_vendor_libs/templates/
#     policy/shim/agents, same structural shape, RECURSIVE over subdirs filtered
#     to *.sh + *.py (matches audit.sh:1534's exact drift-scan filter).
#   - lib/upgrade.sh:do_upgrade — invokes ALL SIX helpers (libs + templates +
#     policy + shim + agents + web) under the same --no-self-vendor flag.
#   - bin/fw vendor self — invokes ALL SIX helpers; --help mentions all classes.
#
# AC mapping (per .tasks/active/T-2267-*.md):
#   helper exists + sibling shape           — t1
#   consumer-safe early-return              — t2
#   real-run syncs diffed files recursively — t3
#   dry-run reports "would sync N web/"     — t4
#   do_upgrade calls helper                 — t5
#   fw vendor self --help lists web/        — t6
#   fw vendor self --dry-run live drift     — t7

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t2267-XXXXXX)"
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
#   web/app.py             == .agentic-framework/web/app.py             (skip)
#   web/blueprints/x.py    != .agentic-framework/web/blueprints/x.py    (sync)
#   web/smoke.sh             missing in vendored                         (sync)
#   web/templates/page.html  (filter excludes — never synced)
make_synthetic_fw_with_web_diff() {
    local syn_fw="$TEST_TEMP_DIR/syn-fw-web"
    mkdir -p "$syn_fw/web/blueprints" "$syn_fw/web/templates"
    mkdir -p "$syn_fw/.agentic-framework/web/blueprints"
    # same — should be skipped
    echo "x = 1" > "$syn_fw/web/app.py"
    echo "x = 1" > "$syn_fw/.agentic-framework/web/app.py"
    # changed — should be synced
    echo "new" > "$syn_fw/web/blueprints/x.py"
    echo "old" > "$syn_fw/.agentic-framework/web/blueprints/x.py"
    # new — missing in vendored, should be synced (recursive at root level)
    echo "echo smoke" > "$syn_fw/web/smoke.sh"
    # excluded — filter is *.sh + *.py only
    echo "<html></html>" > "$syn_fw/web/templates/page.html"
    echo "$syn_fw"
}

# Minimal consumer fixture (no .agentic-framework/web/ → guard skips).
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

@test "t2267 t1: _self_vendor_web() helper extracted in lib/upgrade.sh + wired in do_upgrade" {
    local fw_src="$FRAMEWORK_ROOT/lib/upgrade.sh"
    grep -qE '^_self_vendor_web\(\) \{' "$fw_src"
    grep -qE '_self_vendor_web "\$dry_run"' "$fw_src"
}

# ─────────────────────────────────────────────────────────────────────────
# Helper consumer-safety
# ─────────────────────────────────────────────────────────────────────────

@test "t2267 t2: helper consumer-safe early-return when no .agentic-framework/web" {
    local consumer_like="$TEST_TEMP_DIR/no-vendored-web-dir"
    mkdir -p "$consumer_like/web"
    echo "x = 1" > "$consumer_like/web/test.py"
    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$consumer_like"
    run _self_vendor_web "false"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    [[ "$output" != *"Self-vendor:"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# Helper sync behaviour
# ─────────────────────────────────────────────────────────────────────────

@test "t2267 t3: helper syncs diffed + new files recursively, skips matches + non-{sh,py}" {
    local syn_fw
    syn_fw=$(make_synthetic_fw_with_web_diff)
    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$syn_fw"
    run _self_vendor_web "false"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    # synced 2 files (blueprints/x.py + smoke.sh); app.py skipped, templates/page.html filtered
    [[ "$output" == *"synced 2 web/ file(s)"* ]]
    diff -q "$syn_fw/web/blueprints/x.py" "$syn_fw/.agentic-framework/web/blueprints/x.py"
    [ -f "$syn_fw/.agentic-framework/web/smoke.sh" ]
    diff -q "$syn_fw/web/smoke.sh" "$syn_fw/.agentic-framework/web/smoke.sh"
    # html NOT mirrored (filter excludes)
    [ ! -f "$syn_fw/.agentic-framework/web/templates/page.html" ]
}

@test "t2267 t4: helper dry-run reports 'would sync N web/ file(s)' without copying" {
    local syn_fw
    syn_fw=$(make_synthetic_fw_with_web_diff)
    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$syn_fw"
    run _self_vendor_web "true"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    [[ "$output" == *"would sync 2 web/ file(s)"* ]]
    [[ "$output" != *"Self-vendor:"*" synced 2 web/"* ]]
    ! diff -q "$syn_fw/web/blueprints/x.py" "$syn_fw/.agentic-framework/web/blueprints/x.py" >/dev/null 2>&1
    [ ! -f "$syn_fw/.agentic-framework/web/smoke.sh" ]
}

# ─────────────────────────────────────────────────────────────────────────
# do_upgrade calls the helper
# ─────────────────────────────────────────────────────────────────────────

@test "t2267 t5: do_upgrade --dry-run invokes _self_vendor_web alongside siblings" {
    local proj="$TEST_TEMP_DIR/six-helpers-proj"
    make_consumer "$proj"
    do_vendor() { return 0; }
    export -f do_vendor 2>/dev/null || true
    # Mock all six helpers to mark when each is called.
    _self_vendor_libs() { echo "LIBS_CALLED with dry_run=$1"; return 0; }
    _self_vendor_templates() { echo "TEMPLATES_CALLED with dry_run=$1"; return 0; }
    _self_vendor_policy() { echo "POLICY_CALLED with dry_run=$1"; return 0; }
    _self_vendor_shim() { echo "SHIM_CALLED with dry_run=$1"; return 0; }
    _self_vendor_agents() { echo "AGENTS_CALLED with dry_run=$1"; return 0; }
    _self_vendor_web() { echo "WEB_CALLED with dry_run=$1"; return 0; }
    export -f _self_vendor_libs _self_vendor_templates _self_vendor_policy _self_vendor_shim _self_vendor_agents _self_vendor_web 2>/dev/null || true

    run do_upgrade "$proj" --dry-run
    [[ "$output" == *"WEB_CALLED with dry_run=true"* ]]
    # --no-self-vendor must still skip ALL SIX
    run do_upgrade "$proj" --dry-run --no-self-vendor
    [[ "$output" == *"Self-vendor skipped"* ]]
    [[ "$output" != *"WEB_CALLED"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# fw vendor self verb parity
# ─────────────────────────────────────────────────────────────────────────

@test "t2267 t6: fw vendor self --help mentions web/ class with T-2267 annotation" {
    run "$FRAMEWORK_ROOT/bin/fw" vendor self --help
    [ "$status" -eq 0 ]
    [[ "$output" == *".agentic-framework/web"* ]]
    [[ "$output" == *"T-2267"* ]]
}

@test "t2267 t7: fw vendor self --dry-run reports web/ class when drift present" {
    local syn_fw="$TEST_TEMP_DIR/syn-fw-web-only"
    mkdir -p "$syn_fw/web" "$syn_fw/.agentic-framework/web"
    echo "new" > "$syn_fw/web/app.py"
    echo "old" > "$syn_fw/.agentic-framework/web/app.py"

    local saved="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$syn_fw"
    run bash -c "source '$saved/lib/colors.sh'; source '$saved/lib/upgrade.sh'; _self_vendor_web true"
    FRAMEWORK_ROOT="$saved"

    [ "$status" -eq 0 ]
    [[ "$output" == *"would sync 1 web/ file(s)"* ]]
}
