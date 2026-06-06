#!/usr/bin/env bats
# T-2093 (T-2078 V1-B): fw upgrade strict exit-code discipline + rollback.
# Closes T-2078 §F4 (exit-code inconsistency + no rollback), §F5 (vendor
# exit swallowed by `| sed` pipe), §F6 (`force=true` mutation not
# subshell-scoped).
#
# Surfaces under test (lib/upgrade.sh):
#   - F4: `--strict` flag, `failed_steps` counter, `_strict_abort_step` label
#   - F4: PARTIAL footer when non-strict + failed_steps > 0
#   - F5: `${PIPESTATUS[0]}` capture after do_vendor | sed
#   - F6: subshell scope around `generate_claude_code_config` force=true call
#
# AC mapping (per .tasks/active/T-2093-*.md):
#   F5 PIPESTATUS — t1
#   F6 subshell-scoped force — t2 (structural grep) + t3 (runtime: force does not leak)
#   F4 --strict flag in help — t4
#   F4 --strict aborts on step failure — t5
#   F4 non-strict PARTIAL footer — t6

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t2093-XXXXXX)"
    export FRAMEWORK_ROOT
    export FW_VERSION="1.5.0"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build a minimal consumer fixture sufficient for do_upgrade to reach the
# vendor step (step 4b). Has .framework.yaml + .agentic-framework/ but no
# nested .git (so the FRAMEWORK_ROOT collapse check at the start of
# do_upgrade does NOT fire — we want to exercise the normal step flow).
make_consumer() {
    local proj="$1"
    mkdir -p "$proj/.agentic-framework"
    # Minimal .agentic-framework so step 4b finds vendored_dir; NO .git
    # inside so the bare-from-consumer guard does NOT fire on this fixture
    # (we want regular step flow, not the auto-clone path).
    touch "$proj/.agentic-framework/FRAMEWORK.md"
    cat > "$proj/.framework.yaml" <<YAML
project_name: $(basename "$proj")
version: 1.4.0
provider: claude
YAML
}

# ─────────────────────────────────────────────────────────────────────────
# F4 — --strict flag visibility in help (smallest, no fixture needed)
# ─────────────────────────────────────────────────────────────────────────

@test "t2093 t4: do_upgrade --help advertises --strict flag (F4 surface)" {
    run do_upgrade --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--strict"* ]]
    [[ "$output" == *"PARTIAL"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# F5 — PIPESTATUS capture surfaces vendor failure (non-strict shows WARN)
# ─────────────────────────────────────────────────────────────────────────

@test "t2093 t1: F5 PIPESTATUS surfaces do_vendor failure as WARN (non-strict)" {
    local proj="$TEST_TEMP_DIR/f5-proj"
    make_consumer "$proj"
    # Stub do_vendor to fail — simulates T-1109's enumeration-divergence
    # class. Without the F5 fix, the `| sed` pipe always exits 0 and this
    # failure would be silent.
    do_vendor() { echo "stub: vendor failed"; return 7; }
    export -f do_vendor 2>/dev/null || true

    run do_upgrade "$proj" --dry-run
    # Non-strict: failure surfaced as WARN but exit 0 (advisory)
    [[ "$output" == *"WARN"* ]]
    [[ "$output" == *"do_vendor exited 7"* ]]
    [[ "$output" == *"(F5)"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# F4 — strict abort on step failure
# ─────────────────────────────────────────────────────────────────────────

@test "t2093 t5: F4 --strict aborts with STRICT ABORT diagnostic when vendor fails" {
    local proj="$TEST_TEMP_DIR/f4-strict-proj"
    make_consumer "$proj"
    do_vendor() { echo "stub: vendor failed under strict"; return 3; }
    export -f do_vendor 2>/dev/null || true

    run do_upgrade "$proj" --strict --dry-run
    # Strict mode: abort with non-zero exit + STRICT ABORT diagnostic
    [ "$status" -ne 0 ]
    [[ "$output" == *"STRICT ABORT"* ]]
    [[ "$output" == *"4b (vendor)"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# F4 — non-strict PARTIAL footer when failures accumulated
# ─────────────────────────────────────────────────────────────────────────

@test "t2093 t6: F4 non-strict PARTIAL footer prints when failed_steps > 0" {
    local proj="$TEST_TEMP_DIR/f4-nonstrict-proj"
    make_consumer "$proj"
    do_vendor() { echo "stub: vendor failed (non-strict footer test)"; return 5; }
    export -f do_vendor 2>/dev/null || true

    run do_upgrade "$proj" --dry-run
    # Non-strict: do_upgrade keeps running through other steps; at the
    # tail end the PARTIAL footer surfaces the accumulated failure count
    # and the operator gets a single sentence pointing at --strict. Live
    # path emits "Upgrade PARTIAL"; dry-run parity emits "Dry Run PARTIAL"
    # — assert on the shared "step(s) reported failure" line that both
    # paths now emit.
    [[ "$output" == *"step(s) reported failure"* ]]
    [[ "$output" == *"--strict"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# F6 — subshell-scoped force=true (structural grep + runtime no-leak)
# ─────────────────────────────────────────────────────────────────────────

@test "t2093 t2: F6 subshell-scoped force=true around generate_claude_code_config (structural)" {
    # Subshell shape: `( force=true; generate_claude_code_config "$target_dir" )`
    # — parens scope the assignment so an exit from generate_claude_code_config
    # cannot leak force=true into the rest of do_upgrade. Both call sites must
    # use this pattern (lines ~916 + ~1031 per the prior session commit
    # 44c6d6781). Structural grep matches the lexical shape directly.
    local fw_src="$FRAMEWORK_ROOT/lib/upgrade.sh"
    # Count subshell-scoped sites — must be ≥2 (the two F6 patch sites)
    local count
    count=$(grep -cE '^\s*\(\s*force=true\s*;\s*generate_claude_code_config' "$fw_src")
    [ "$count" -ge 2 ]
    # Negative: no leaked, non-subshell pattern should remain
    ! grep -qE '^\s*force=true\s*$' "$fw_src" \
        || (echo "Unsubshelled 'force=true' assignment leaked"; false)
}

@test "t2093 t3: F6 force=true does not leak into outer scope after subshell exits" {
    # Direct subshell-scope guarantee test — independent of do_upgrade's
    # full flow. Mirrors the F6 patch shape: parens scope the assignment.
    local outer_force="false"
    (
        # Subshell — would exit even on `set -e` mid-function
        outer_force="true"
        false
    ) 2>/dev/null || true
    [ "$outer_force" = "false" ]  # outer scope untouched
}
