#!/usr/bin/env bats
# T-1912 — fw upgrade runtime-side downgrade guard (closes the half-fix
# from T-1839).
#
# Background: T-1839 added a guard at step 9 (.framework.yaml pin
# rewrite) that refused ahead→behind direction. But step 4b's do_vendor
# (lib/upgrade.sh:~620) had already copied framework runtime files over
# the consumer's newer runtime BEFORE the step 9 guard fired. Result:
# split-brain (runtime files older, pin newer). Worked example:
# 2026-05-18 dimitri-mint-dev consumer at v1.6.260 against framework at
# v1.6.225.
#
# T-1912 adds a pre-step-1 precheck that mirrors the step-9 logic but
# fires BEFORE any mutation. These tests pin:
#   - Source-level: REFUSED message at the precheck site (no mutation
#     should have happened).
#   - Behavioural: do_upgrade refuses when consumer > framework with no
#     side-effects on .agentic-framework/.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-runtime-guard-XXXXXX)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export FW_VERSION="1.6.225"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build a minimal "fresh consumer" with a NEWER pinned version than the
# framework's $FW_VERSION. The body of do_upgrade should refuse before
# any mutation reaches step 4b.
make_ahead_consumer() {
    local proj="$1"
    local ver="$2"
    mkdir -p "$proj/.agentic-framework/lib"
    cat > "$proj/.framework.yaml" <<YAML
project_name: $(basename "$proj")
version: $ver
provider: claude
YAML
    # Marker file inside .agentic-framework/ — if vendor step ran, this
    # file's mtime would change (do_vendor cp). The precheck must fire
    # BEFORE that copy happens.
    echo "MARKER" > "$proj/.agentic-framework/lib/marker.sh"
    chmod +w "$proj/.agentic-framework/lib/marker.sh"
}

# ── Source-level pins ──

@test "T-1912: lib/upgrade.sh contains the T-1912 precheck marker" {
    run grep -q 'T-1912: pre-step-1 version-ahead precheck' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    [ "$status" -eq 0 ]
}

@test "T-1912: precheck REFUSED message names runtime + split-brain" {
    run grep -q 'split-brain state (T-1912 class)' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    [ "$status" -eq 0 ]
}

@test "T-1912: precheck honours --force-downgrade escape hatch" {
    # The guard block must reference force_downgrade. grep -A 15 captures
    # the entire if-block.
    run grep -A 15 'T-1912: pre-step-1' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"force_downgrade"* ]]
}

@test "T-1912: precheck appears BEFORE the executable step-1 banner in source order" {
    # The executable step-1 banner is the [1/10] echo (not the help text
    # listing at line ~167, which is inside the --help handler).
    local precheck_line
    precheck_line=$(grep -n 'T-1912: pre-step-1' "$FRAMEWORK_ROOT/lib/upgrade.sh" | head -1 | cut -d: -f1)
    local step1_line
    step1_line=$(grep -n '\[1/10\] CLAUDE.md governance' "$FRAMEWORK_ROOT/lib/upgrade.sh" | head -1 | cut -d: -f1)
    [ -n "$precheck_line" ]
    [ -n "$step1_line" ]
    [ "$precheck_line" -lt "$step1_line" ]
}

# ── Behavioural pins ──

@test "T-1912: do_upgrade refuses when consumer version is AHEAD of framework" {
    local proj="$TEST_TEMP_DIR/consumer"
    make_ahead_consumer "$proj" "1.6.260"
    run do_upgrade "$proj"
    [ "$status" -ne 0 ]
    [[ "$output" == *"REFUSED"* ]] || [[ "$output" == *"AHEAD"* ]]
}

@test "T-1912: refusal at precheck leaves runtime files untouched" {
    local proj="$TEST_TEMP_DIR/consumer"
    make_ahead_consumer "$proj" "1.6.260"
    local marker_before
    marker_before=$(cat "$proj/.agentic-framework/lib/marker.sh")
    run do_upgrade "$proj"
    [ "$status" -ne 0 ]
    local marker_after
    marker_after=$(cat "$proj/.agentic-framework/lib/marker.sh")
    [ "$marker_before" = "$marker_after" ]
}

@test "T-1912: --force-downgrade bypasses the precheck (and proceeds to step 1)" {
    local proj="$TEST_TEMP_DIR/consumer"
    make_ahead_consumer "$proj" "1.6.260"
    # With --force-downgrade the precheck must NOT fire — output should
    # NOT contain REFUSED at the T-1912 line (it may still fail later
    # for other reasons in this stub consumer; we only assert the
    # precheck didn't block).
    run do_upgrade "$proj" --force-downgrade --dry-run
    # The T-1912 precheck specifically mentions "T-1912 class" — that
    # phrase should NOT appear when force_downgrade is set.
    [[ "$output" != *"T-1912 class"* ]]
}

@test "T-1912: precheck does NOT fire when consumer version is BEHIND framework (normal upgrade direction)" {
    local proj="$TEST_TEMP_DIR/consumer"
    make_ahead_consumer "$proj" "1.6.100"  # behind FW_VERSION=1.6.225
    run do_upgrade "$proj" --dry-run
    # Behind direction should NOT trigger the T-1912 REFUSED block (it
    # may fail elsewhere for stub-consumer reasons, but the precheck
    # phrase must not appear).
    [[ "$output" != *"T-1912 class"* ]]
}

@test "T-1912: precheck does NOT fire when consumer version equals framework version" {
    local proj="$TEST_TEMP_DIR/consumer"
    make_ahead_consumer "$proj" "1.6.225"  # equal to FW_VERSION
    run do_upgrade "$proj" --dry-run
    [[ "$output" != *"T-1912 class"* ]]
}

@test "T-1912: precheck does NOT fire when consumer has no pinned version" {
    local proj="$TEST_TEMP_DIR/consumer"
    mkdir -p "$proj/.agentic-framework/lib"
    cat > "$proj/.framework.yaml" <<YAML
project_name: $(basename "$proj")
provider: claude
YAML
    run do_upgrade "$proj" --dry-run
    [[ "$output" != *"T-1912 class"* ]]
}
