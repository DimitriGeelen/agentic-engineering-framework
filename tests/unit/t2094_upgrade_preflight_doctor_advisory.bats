#!/usr/bin/env bats
# T-2094 (T-2078 V1-C): fw upgrade pre-flight tooling check (F8) +
# post-upgrade fw doctor advisory (F10).
#
# Surfaces under test (lib/upgrade.sh):
#   - F8 pre-flight loop at top of do_upgrade (after arg parse)
#       names python3 git diff sed mktemp; missing tool returns 1 with
#       "ERROR: required tool missing: <cmd>" on stderr; aborts BEFORE
#       any file mutation / do_vendor call.
#   - F10 advisory helper `_t2094_emit_doctor_advisory <target_dir>` runs
#       fw doctor with PROJECT_ROOT="$target_dir" and emits a "Post-upgrade
#       health check (advisory):" header above the captured output. Non-
#       blocking: doctor non-zero exit DOES NOT propagate.
#
# AC mapping (per .tasks/active/T-2094-*.md):
#   F8 structural loop names 5 tools  — t1 + t2
#   F8 missing-tool aborts pre-mutation — t3
#   F8 happy path proceeds past pre-flight — t4
#   F10 advisory invoked on live success — t5
#   F10 dry-run skips advisory (structural) — t6
#   F10 doctor non-blocking — t7
#   F10 PROJECT_ROOT="$target_dir" — t8

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t2094-XXXXXX)"
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
# vendor step (step 4b). Mirrors t2093's helper.
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

# Build a stub PATH dir that has all 5 required tools (symlinks to system
# binaries) except the one named in $1. Caller exports PATH=$stub_dir
# (no system PATH appended) to deny lookup of the omitted tool.
make_stub_path_missing() {
    local omit="$1"
    local stub_dir="$TEST_TEMP_DIR/stub-path"
    mkdir -p "$stub_dir"
    # bats itself needs bash + a few common tools; bats setup() already ran
    # under the real PATH. Symlink everything the test body might touch.
    local sys_paths=(/usr/local/bin /usr/bin /bin)
    local needed=(python3 git diff sed mktemp bash awk grep cat head env rm mkdir chmod touch ls)
    for tool in "${needed[@]}"; do
        [ "$tool" = "$omit" ] && continue
        for sp in "${sys_paths[@]}"; do
            if [ -x "$sp/$tool" ]; then
                ln -sf "$sp/$tool" "$stub_dir/$tool"
                break
            fi
        done
    done
    echo "$stub_dir"
}

# ─────────────────────────────────────────────────────────────────────────
# F8 — structural: pre-flight loop names all 5 required tools
# ─────────────────────────────────────────────────────────────────────────

@test "t2094 t1: F8 pre-flight loop names all 5 required tools" {
    local fw_src="$FRAMEWORK_ROOT/lib/upgrade.sh"
    grep -qE 'T-2094 F8.*pre-flight' "$fw_src"
    # The for-list must contain all 5 names on a single line (the exact
    # loop shape per T-2078 §F8 spec).
    grep -qE 'for _t2094_required in python3 git diff sed mktemp' "$fw_src"
}

@test "t2094 t2: F8 emits 'required tool missing' diagnostic shape" {
    local fw_src="$FRAMEWORK_ROOT/lib/upgrade.sh"
    grep -qE 'required tool missing' "$fw_src"
}

# ─────────────────────────────────────────────────────────────────────────
# F8 — runtime: missing tool aborts BEFORE any do_vendor call
# ─────────────────────────────────────────────────────────────────────────

@test "t2094 t3: F8 missing tool aborts pre-mutation with diagnostic" {
    local proj="$TEST_TEMP_DIR/f8-missing-proj"
    make_consumer "$proj"
    # Trip-wire: if do_vendor IS reached, fail loudly so the test exposes
    # the gap (F8 pre-flight ran AFTER mutation rather than before).
    do_vendor() { echo "TRIP-WIRE: do_vendor reached despite missing tool" >&2; return 99; }
    export -f do_vendor 2>/dev/null || true

    local stub_path
    stub_path=$(make_stub_path_missing mktemp)
    local orig_path="$PATH"
    # Use ONLY the stub dir — mktemp is omitted, all other tools symlinked.
    PATH="$stub_path" run do_upgrade "$proj" --dry-run
    PATH="$orig_path"

    [ "$status" -ne 0 ]
    [[ "$output" == *"required tool missing: mktemp"* ]]
    [[ "$output" == *"Aborting before any file mutation"* ]]
    # Trip-wire negative: do_vendor MUST NOT have been called.
    [[ "$output" != *"TRIP-WIRE: do_vendor reached"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# F8 — happy path: all tools present, pre-flight does not regress flow
# ─────────────────────────────────────────────────────────────────────────

@test "t2094 t4: F8 happy path reaches step-1 (banner) with all tools present" {
    local proj="$TEST_TEMP_DIR/f8-happy-proj"
    make_consumer "$proj"
    # Stub do_vendor to fail at step 4b so the test exits quickly without
    # running the full 10-step flow. The pre-flight pass condition is
    # observable from the step-1 banner appearing before do_vendor's stub
    # message — meaning pre-flight didn't block.
    do_vendor() { echo "stub: do_vendor invoked AFTER pre-flight passed"; return 5; }
    export -f do_vendor 2>/dev/null || true

    run do_upgrade "$proj" --dry-run
    # Pre-flight did NOT emit the missing-tool diagnostic
    [[ "$output" != *"required tool missing"* ]]
    # do_vendor stub was invoked → pre-flight passed and flow advanced
    [[ "$output" == *"do_vendor invoked AFTER pre-flight passed"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# F10 — advisory helper: PASS path
# ─────────────────────────────────────────────────────────────────────────

@test "t2094 t5: F10 advisory header + PASS line when stub fw doctor returns 0" {
    local proj="$TEST_TEMP_DIR/f10-pass-proj"
    make_consumer "$proj"
    # Stub FRAMEWORK_ROOT/bin/fw — the helper invokes "$FRAMEWORK_ROOT/bin/fw"
    # doctor; we redirect that to a controlled exit code.
    local stub_fw_root="$TEST_TEMP_DIR/stub-fw"
    mkdir -p "$stub_fw_root/bin" "$stub_fw_root/lib"
    cat > "$stub_fw_root/bin/fw" <<'STUB'
#!/usr/bin/env bash
if [ "$1" = "doctor" ]; then
    echo "stub doctor: OK"
    echo "  Cron registry in sync"
    exit 0
fi
exit 0
STUB
    chmod +x "$stub_fw_root/bin/fw"
    # Provide a stub colors.sh for the helper's BOLD/GREEN/etc. references.
    : > "$stub_fw_root/lib/colors.sh"
    local saved_fw_root="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$stub_fw_root"
    run _t2094_emit_doctor_advisory "$proj"
    FRAMEWORK_ROOT="$saved_fw_root"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Post-upgrade health check (advisory):"* ]]
    [[ "$output" == *"stub doctor: OK"* ]]
    [[ "$output" == *"PASS"* ]] || [[ "$output" == *"doctor PASS"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# F10 — advisory helper: non-zero path, non-blocking
# ─────────────────────────────────────────────────────────────────────────

@test "t2094 t6: F10 doctor non-zero exit surfaces advisory but helper still returns 0" {
    local proj="$TEST_TEMP_DIR/f10-fail-proj"
    make_consumer "$proj"
    local stub_fw_root="$TEST_TEMP_DIR/stub-fw-fail"
    mkdir -p "$stub_fw_root/bin"
    cat > "$stub_fw_root/bin/fw" <<'STUB'
#!/usr/bin/env bash
if [ "$1" = "doctor" ]; then
    echo "stub doctor: FAIL signal" >&2
    exit 3
fi
exit 0
STUB
    chmod +x "$stub_fw_root/bin/fw"
    local saved_fw_root="$FRAMEWORK_ROOT"
    FRAMEWORK_ROOT="$stub_fw_root"
    run _t2094_emit_doctor_advisory "$proj"
    FRAMEWORK_ROOT="$saved_fw_root"

    # Non-blocking: helper itself returns 0 regardless of doctor's exit.
    [ "$status" -eq 0 ]
    [[ "$output" == *"Post-upgrade health check (advisory):"* ]]
    [[ "$output" == *"doctor exited 3"* ]]
    [[ "$output" == *"doctor exit code does not affect upgrade success"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# F10 — structural: PROJECT_ROOT="$target_dir" adjacency
# ─────────────────────────────────────────────────────────────────────────

@test "t2094 t7: F10 helper runs fw doctor with PROJECT_ROOT=target_dir" {
    local fw_src="$FRAMEWORK_ROOT/lib/upgrade.sh"
    # Single line in the helper that runs doctor in the consumer's PROJECT_ROOT.
    grep -qE 'PROJECT_ROOT="\$target_dir".*"\$FRAMEWORK_ROOT/bin/fw" doctor' "$fw_src"
}

# ─────────────────────────────────────────────────────────────────────────
# F10 — structural: dry-run path does NOT call the helper
# ─────────────────────────────────────────────────────────────────────────

@test "t2094 t8: F10 advisory helper is only called inside the changes>0 non-dry-run branch" {
    local fw_src="$FRAMEWORK_ROOT/lib/upgrade.sh"
    # Count call sites — there must be exactly ONE call site, and it must
    # be inside the "Next steps" block (which is itself inside the else
    # branch of `if [ "$dry_run" = true ]` and gated on `changes > 0`).
    local call_count
    call_count=$(grep -cE '^\s+_t2094_emit_doctor_advisory ' "$fw_src")
    [ "$call_count" -eq 1 ]
    # Use sed to extract the line number of the call, then walk backwards
    # confirming we're inside the changes>0 block. We assert structurally
    # that the call appears AFTER `if [ "$changes" -gt 0 ]; then`.
    local call_ln next_steps_ln
    call_ln=$(grep -nE '^\s+_t2094_emit_doctor_advisory ' "$fw_src" | head -1 | cut -d: -f1)
    next_steps_ln=$(grep -nE 'if \[ "\$changes" -gt 0 \]; then$' "$fw_src" | tail -1 | cut -d: -f1)
    [ -n "$call_ln" ] && [ -n "$next_steps_ln" ]
    [ "$call_ln" -gt "$next_steps_ln" ]
}
