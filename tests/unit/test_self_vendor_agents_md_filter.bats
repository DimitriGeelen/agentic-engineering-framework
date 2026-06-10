#!/usr/bin/env bats
# T-2304 (OBS-068): regression test for _self_vendor_agents .md filter
# extension.
#
# Pre-T-2304: lib/upgrade.sh:_self_vendor_agents filtered on `.sh + .py` only.
# AGENT.md files (intelligence siblings, e.g., agents/resume/AGENT.md) drifted
# silently between source agents/ and vendored .agentic-framework/agents/.
# Origin: T-2301 hit this on the resume agent.
#
# T-2304: filter extended to `.sh + .py + .md`. This test pins the .md leg so
# any future refactor that narrows the filter trips the gate.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export FRAMEWORK_ROOT_OVERRIDE="$TEST_TEMP_DIR"

    # Simulate a framework checkout with a vendored .agentic-framework/agents/
    # subtree. Agent intelligence file (AGENT.md) exists in BOTH source and
    # vendored — in sync at setup.
    mkdir -p "$TEST_TEMP_DIR/agents/sample" \
             "$TEST_TEMP_DIR/.agentic-framework/agents/sample" \
             "$TEST_TEMP_DIR/.agentic-framework/lib"

    cat > "$TEST_TEMP_DIR/agents/sample/sample.sh" <<'EOF'
#!/usr/bin/env bash
echo "sample agent"
EOF
    cat > "$TEST_TEMP_DIR/.agentic-framework/agents/sample/sample.sh" <<'EOF'
#!/usr/bin/env bash
echo "sample agent"
EOF

    cat > "$TEST_TEMP_DIR/agents/sample/AGENT.md" <<'EOF'
# sample AGENT.md
Intelligence file v1.
EOF
    cat > "$TEST_TEMP_DIR/.agentic-framework/agents/sample/AGENT.md" <<'EOF'
# sample AGENT.md
Intelligence file v1.
EOF
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: source the upgrade.sh and run _self_vendor_agents only.
_run_self_vendor_agents() {
    local dry_run="${1:-false}"
    (
        export FRAMEWORK_ROOT="$TEST_TEMP_DIR"
        export GREEN='' YELLOW='' RED='' NC=''
        source "$FRAMEWORK_ROOT_OVERRIDE/../lib/upgrade.sh" 2>/dev/null \
            || source "$BATS_TEST_DIRNAME/../../lib/upgrade.sh"
        _self_vendor_agents "$dry_run"
    )
}

@test "T-2304: .md drift in agents/ surfaces in dry-run output" {
    # Mutate AGENT.md in source (vendored copy is now stale)
    cat > "$TEST_TEMP_DIR/agents/sample/AGENT.md" <<'EOF'
# sample AGENT.md
Intelligence file v2 — MUTATED.
EOF

    run _run_self_vendor_agents true
    [[ "$output" == *"would sync"*"agents/"* ]]
    # Must report exactly 1 file (the .md drift)
    [[ "$output" == *"would sync 1 agents/"* ]]
}

@test "T-2304: real-run syncs the .md drift" {
    cat > "$TEST_TEMP_DIR/agents/sample/AGENT.md" <<'EOF'
# sample AGENT.md
Intelligence file v2 — MUTATED.
EOF

    run _run_self_vendor_agents false
    [[ "$output" == *"synced"*"agents/"* ]]

    # Vendored copy now matches source
    run diff -q "$TEST_TEMP_DIR/agents/sample/AGENT.md" \
                "$TEST_TEMP_DIR/.agentic-framework/agents/sample/AGENT.md"
    [ "$status" -eq 0 ]
}

@test "T-2304: .sh drift still caught (regression of original filter leg)" {
    cat > "$TEST_TEMP_DIR/agents/sample/sample.sh" <<'EOF'
#!/usr/bin/env bash
echo "sample agent v2 — MUTATED"
EOF

    run _run_self_vendor_agents true
    [[ "$output" == *"would sync 1 agents/"* ]]
}

@test "T-2304: no drift → no output (clean state pin)" {
    run _run_self_vendor_agents true
    [ -z "$(echo "$output" | grep -E 'would sync|synced')" ]
}
