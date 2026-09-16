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
# This pins the doctor check that compares the claude-fw(s) actually on PATH
# (symlink resolved) against the checkout's bin/claude-fw: WARN on drift, OK on
# match, SKIP when not installed.
#
# T-3358 widened the check under test to scan EVERY claude-fw reachable on
# PATH, not just the first `command -v` hit (a second, stale copy further down
# PATH — or reachable only under a different PATH ordering, e.g. a systemd unit
# with no Environment=PATH= override — is exactly the mechanism T-3358 traced
# on the framework's own host). That makes these tests sensitive to whatever
# claude-fw copies happen to already exist elsewhere on the *real* host PATH,
# which is incidental state these fixtures do not control. setup_file() below
# builds one synthetic PATH directory containing every ambient executable
# EXCEPT any file named `claude-fw`, so each test's own fixture is the only
# claude-fw the check can ever see, regardless of what else is installed on
# the host running the suite.

load ../test_helper

setup_file() {
    # MUST be exported: bats runs setup_file in a separate process from the
    # tests, so a bare assignment is invisible to them. Without `export` the
    # tests see an empty CLEAN_PATH_DIR, build PATH='<fixture>:' — whose empty
    # trailing component resolves nothing — and every `bin/fw doctor` call dies
    # at exit 127 before the assertion it was meant to exercise ever runs.
    export CLEAN_PATH_DIR="$(mktemp -d)"
    local d f base old_ifs="$IFS"
    IFS=':'
    for d in $PATH; do
        IFS="$old_ifs"
        [ -d "$d" ] || continue
        for f in "$d"/*; do
            [ -e "$f" ] || [ -L "$f" ] || continue
            base="$(basename "$f")"
            [ "$base" = "claude-fw" ] && continue
            [ -e "$CLEAN_PATH_DIR/$base" ] && continue
            ln -s "$f" "$CLEAN_PATH_DIR/$base" 2>/dev/null || true
        done
        IFS=':'
    done
    IFS="$old_ifs"
}

teardown_file() {
    [ -n "${CLEAN_PATH_DIR:-}" ] && rm -rf "$CLEAN_PATH_DIR"
}

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    mkdir -p "$TEST_TEMP_DIR/bin"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Run `fw doctor --quick` with claude-fw resolution controlled entirely by the
# fixture — CLEAN_PATH_DIR guarantees no ambient claude-fw leaks in.
run_doctor_with_path() {
    local extra_path="$1"
    run bash -c "cd '$FRAMEWORK_ROOT' && CLAUDECODE=1 PATH='${extra_path}:${CLEAN_PATH_DIR}' PROJECT_ROOT='$FRAMEWORK_ROOT' bin/fw doctor --quick 2>&1"
}

@test "T-2501: on-PATH claude-fw DIFFERS from repo → drift WARN" {
    # A claude-fw on PATH whose content differs from the repo source.
    printf '#!/bin/bash\n# stale wrapper, no supervision export\n' > "$TEST_TEMP_DIR/bin/claude-fw"
    chmod +x "$TEST_TEMP_DIR/bin/claude-fw"
    run_doctor_with_path "$TEST_TEMP_DIR/bin"
    [[ "$output" == *"Installed claude-fw drifted from repo source"* ]]
    [[ "$output" == *"Refresh:"* ]]
}

@test "T-2501: on-PATH claude-fw MATCHES repo → OK, no drift WARN" {
    # An exact copy of the repo wrapper → must report OK.
    cp "$FRAMEWORK_ROOT/bin/claude-fw" "$TEST_TEMP_DIR/bin/claude-fw"
    chmod +x "$TEST_TEMP_DIR/bin/claude-fw"
    run_doctor_with_path "$TEST_TEMP_DIR/bin"
    [[ "$output" == *"Installed claude-fw matches repo source"* ]]
    [[ "$output" != *"Installed claude-fw drifted from repo source"* ]]
}

@test "T-2501: claude-fw NOT on PATH → SKIP (no false alarm)" {
    # Fixture dir stays empty; CLEAN_PATH_DIR has no claude-fw either.
    run_doctor_with_path ""
    [[ "$output" == *"claude-fw not on PATH"* ]]
    [[ "$output" != *"Installed claude-fw drifted from repo source"* ]]
}

@test "T-3358: TWO stale copies on PATH → both reported, not just the first" {
    # Simulates the traced fleet mechanism: an interactive shell resolves a
    # current copy first, but a second, stale copy sits further down PATH and
    # is what a differently-configured PATH (e.g. a systemd unit) would
    # actually execute. The old single-hit check reported OK here.
    mkdir -p "$TEST_TEMP_DIR/second"
    cp "$FRAMEWORK_ROOT/bin/claude-fw" "$TEST_TEMP_DIR/bin/claude-fw"
    chmod +x "$TEST_TEMP_DIR/bin/claude-fw"
    printf '#!/bin/bash\n# stale wrapper, no supervision export\n' > "$TEST_TEMP_DIR/second/claude-fw"
    chmod +x "$TEST_TEMP_DIR/second/claude-fw"
    run_doctor_with_path "$TEST_TEMP_DIR/bin:$TEST_TEMP_DIR/second"
    [[ "$output" == *"Installed claude-fw drifted from repo source"* ]]
    [[ "$output" == *"$TEST_TEMP_DIR/second/claude-fw"* ]]
}
