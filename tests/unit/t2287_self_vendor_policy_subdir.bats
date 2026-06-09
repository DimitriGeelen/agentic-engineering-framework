#!/usr/bin/env bats
# T-2287 (arc-010 follow-on): _self_vendor_policy() syncs subdirectory entries.
#
# Surfaces under test:
#   - lib/upgrade.sh:_self_vendor_policy() — loop now includes
#     `capability-overlay/tool-set.yaml` (subdir entry, T-2287); destination
#     subdir is created with `mkdir -p $(dirname "$_svp_dst")` before cp.
#   - Sibling regression unchanged for the flat-list entries
#     (value-drivers.yaml, bvp-scoring-rubric.md).
#
# AC mapping (per .tasks/active/T-2287-*.md):
#   subdir entry in loop                    — t1
#   mkdir -p $(dirname) guard               — t2
#   subdir destination created from scratch — t3
#   real-run syncs diffed subdir file       — t4
#   dry-run reports "would sync N policy/"  — t5
#   second dry-run is clean                 — t6
#   flat-list siblings still sync           — t7

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t2287-XXXXXX)"
    export FRAMEWORK_ROOT
    export FW_VERSION="1.6.122"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build a synthetic framework tree with policy/ and a capability-overlay subdir.
#   policy/value-drivers.yaml     (flat, sibling regression)
#   policy/bvp-scoring-rubric.md  (flat, sibling regression)
#   policy/capability-overlay/tool-set.yaml  (NEW — T-2287 subdir entry)
#   .agentic-framework/policy/   exists but capability-overlay/ subdir absent
make_synthetic_fw_with_policy_subdir() {
    local syn_fw="$TEST_TEMP_DIR/syn-fw-policy"
    mkdir -p "$syn_fw/policy/capability-overlay"
    mkdir -p "$syn_fw/.agentic-framework/policy"
    echo "weights: {D1: 9}" > "$syn_fw/policy/value-drivers.yaml"
    echo "weights: {D1: 9}" > "$syn_fw/.agentic-framework/policy/value-drivers.yaml"
    echo "# scoring rubric" > "$syn_fw/policy/bvp-scoring-rubric.md"
    echo "# scoring rubric" > "$syn_fw/.agentic-framework/policy/bvp-scoring-rubric.md"
    echo "tools: [{id: fw__task_show, class: read_only}]" > "$syn_fw/policy/capability-overlay/tool-set.yaml"
    # NOTE: deliberately no .agentic-framework/policy/capability-overlay/ subdir
    echo "$syn_fw"
}

@test "t1: _self_vendor_policy() loop includes capability-overlay/tool-set.yaml" {
    run grep -E "capability-overlay/tool-set.yaml" "$FRAMEWORK_ROOT/lib/upgrade.sh"
    [ "$status" -eq 0 ]
    # Belt-and-braces: confirm the literal is inside the helper's for-loop, not just a comment.
    run awk '/^_self_vendor_policy\(\)/,/^}/' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"capability-overlay/tool-set.yaml"* ]]
}

@test "t2: _self_vendor_policy() guards destination subdir with mkdir -p \$(dirname)" {
    run awk '/^_self_vendor_policy\(\)/,/^}/' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"mkdir -p"* ]]
    [[ "$output" == *"dirname"* ]]
}

@test "t3: real-run creates .agentic-framework/policy/capability-overlay/ from scratch" {
    syn_fw=$(make_synthetic_fw_with_policy_subdir)
    FRAMEWORK_ROOT="$syn_fw" run _self_vendor_policy false
    [ "$status" -eq 0 ]
    [ -d "$syn_fw/.agentic-framework/policy/capability-overlay" ]
    [ -f "$syn_fw/.agentic-framework/policy/capability-overlay/tool-set.yaml" ]
    diff -q "$syn_fw/policy/capability-overlay/tool-set.yaml" \
            "$syn_fw/.agentic-framework/policy/capability-overlay/tool-set.yaml"
}

@test "t4: real-run on subdir diff syncs the file and reports synced N" {
    syn_fw=$(make_synthetic_fw_with_policy_subdir)
    # Mutate vendored copy after first sync to create deliberate diff.
    FRAMEWORK_ROOT="$syn_fw" _self_vendor_policy false > /dev/null
    echo "tools: [{id: drift, class: agent_authority}]" > "$syn_fw/.agentic-framework/policy/capability-overlay/tool-set.yaml"
    FRAMEWORK_ROOT="$syn_fw" run _self_vendor_policy false
    [ "$status" -eq 0 ]
    [[ "$output" == *"synced"* ]]
    [[ "$output" == *".agentic-framework/policy/"* ]]
    diff -q "$syn_fw/policy/capability-overlay/tool-set.yaml" \
            "$syn_fw/.agentic-framework/policy/capability-overlay/tool-set.yaml"
}

@test "t5: dry-run on subdir diff reports 'would sync N file(s)' without copying" {
    syn_fw=$(make_synthetic_fw_with_policy_subdir)
    # subdir vendored copy missing entirely → at least 1 would-sync count
    FRAMEWORK_ROOT="$syn_fw" run _self_vendor_policy true
    [ "$status" -eq 0 ]
    [[ "$output" == *"would sync"* ]]
    [[ "$output" == *".agentic-framework/policy/"* ]]
    # Real file should NOT have been created (dry-run discipline)
    [ ! -f "$syn_fw/.agentic-framework/policy/capability-overlay/tool-set.yaml" ]
}

@test "t6: second dry-run after real sync is clean (no 'would sync')" {
    syn_fw=$(make_synthetic_fw_with_policy_subdir)
    FRAMEWORK_ROOT="$syn_fw" _self_vendor_policy false > /dev/null
    FRAMEWORK_ROOT="$syn_fw" run _self_vendor_policy true
    [ "$status" -eq 0 ]
    [[ "$output" != *"would sync"* ]]
}

@test "t7: flat-list sibling entries (value-drivers + bvp-rubric) still sync — sibling regression" {
    syn_fw=$(make_synthetic_fw_with_policy_subdir)
    # Mutate one flat-list entry to force a diff.
    echo "weights: {D1: 5}" > "$syn_fw/.agentic-framework/policy/value-drivers.yaml"
    FRAMEWORK_ROOT="$syn_fw" run _self_vendor_policy false
    [ "$status" -eq 0 ]
    [[ "$output" == *"synced"* ]]
    diff -q "$syn_fw/policy/value-drivers.yaml" "$syn_fw/.agentic-framework/policy/value-drivers.yaml"
    diff -q "$syn_fw/policy/bvp-scoring-rubric.md" "$syn_fw/.agentic-framework/policy/bvp-scoring-rubric.md"
}
