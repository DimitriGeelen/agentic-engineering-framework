#!/usr/bin/env bats
# T-2501: on-PATH claude-fw drift detection in `fw doctor`.
#
# RCA: the operator launched `claude-fw` and got an UNSUPERVISED session because
# the installed wrapper (`~/.local/bin/claude-fw` → host git clone
# `~/.agentic-framework/bin/claude-fw`) was stale — behind origin/master, missing
# the FW_CLAUDE_FW_SUPERVISED export (T-2499). The T-2499 supervision check caught
# the SYMPTOM (session unsupervised) but nothing pointed at the CAUSE (stale
# on-PATH wrapper): claude-fw is excluded from the audit self-vendor find-filter,
# CTL-019 checks existence only, and `fw vendor self` skips it.
#
# This pins the new doctor check that compares the claude-fw actually on PATH
# (symlink resolved) against the checkout's bin/claude-fw: WARN on drift, OK on
# match, SKIP when not installed.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    mkdir -p "$TEST_TEMP_DIR/bin"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Run `fw doctor --quick` with claude-fw resolution controlled via PATH.
run_doctor_with_path() {
    local extra_path="$1"
    run bash -c "cd '$FRAMEWORK_ROOT' && CLAUDECODE=1 PATH='${extra_path}' PROJECT_ROOT='$FRAMEWORK_ROOT' bin/fw doctor --quick 2>&1"
}

@test "T-2501: on-PATH claude-fw DIFFERS from repo → drift WARN" {
    # A claude-fw on PATH whose content differs from the repo source.
    printf '#!/bin/bash\n# stale wrapper, no supervision export\n' > "$TEST_TEMP_DIR/bin/claude-fw"
    chmod +x "$TEST_TEMP_DIR/bin/claude-fw"
    run_doctor_with_path "$TEST_TEMP_DIR/bin:$PATH"
    [[ "$output" == *"Installed claude-fw drifted from repo source"* ]]
    [[ "$output" == *"Refresh:"* ]]
}

@test "T-2501: on-PATH claude-fw MATCHES repo → OK, no drift WARN" {
    # An exact copy of the repo wrapper → must report OK.
    cp "$FRAMEWORK_ROOT/bin/claude-fw" "$TEST_TEMP_DIR/bin/claude-fw"
    chmod +x "$TEST_TEMP_DIR/bin/claude-fw"
    run_doctor_with_path "$TEST_TEMP_DIR/bin:$PATH"
    [[ "$output" == *"Installed claude-fw matches repo source"* ]]
    [[ "$output" != *"Installed claude-fw drifted from repo source"* ]]
}

@test "T-2501: claude-fw NOT on PATH → SKIP (no false alarm)" {
    # Minimal PATH with coreutils only — no claude-fw anywhere.
    run_doctor_with_path "/usr/bin:/bin"
    [[ "$output" == *"claude-fw not on PATH"* ]]
    [[ "$output" != *"Installed claude-fw drifted from repo source"* ]]
}
