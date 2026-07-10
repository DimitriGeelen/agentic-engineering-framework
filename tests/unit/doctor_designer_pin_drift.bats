#!/usr/bin/env bats
# T-2524 (T-2521 integration hardening): fw doctor content-compares (sha256, never
# mtime) the vendored Workflow Designer build against policy/designer-pin.yaml.
# Sibling of the MCP manifest + cron registry→generated drift checks.
#
# Surface under test: bin/fw doctor designer-pin block.
# States:
#   vendored sha256 == pin sha256           → OK    — t1
#   vendored sha256 != pin sha256           → WARN  — t2
#   vendored file absent (per pin path)     → SKIP  — t3
#   pin present but missing sha256/path     → SKIP  — t4
#
# Mirrors t2290_doctor_mcp_content_check.bats: mutate the live pin in place with
# backup/restore, run full `bin/fw doctor`, grep the designer line.

load ../test_helper

setup() {
    BACKUP_PIN=$(mktemp -t fw-t2524-pin-XXXXXX.yaml)
    cp "$FRAMEWORK_ROOT/policy/designer-pin.yaml" "$BACKUP_PIN"
}

teardown() {
    [ -s "${BACKUP_PIN:-/dev/null}" ] && \
        cp "$BACKUP_PIN" "$FRAMEWORK_ROOT/policy/designer-pin.yaml"
    rm -f "${BACKUP_PIN:-}"
}

@test "t1: vendored build matches pin sha256 → OK" {
    # Default synced state (fw designer sync installed the pinned build).
    cd "$FRAMEWORK_ROOT"
    run bin/fw doctor
    [[ "$output" == *"designer vendored build matches pin"* ]]
    [[ "$output" != *"designer vendored build drifted from pin"* ]]
}

@test "t2: vendored build sha256 != pin sha256 → WARN" {
    # Bump the pin's sha256 to a bogus value without re-syncing → drift.
    python3 -c "
import yaml
p = '$FRAMEWORK_ROOT/policy/designer-pin.yaml'
d = yaml.safe_load(open(p))
d['sha256'] = '0'*64
yaml.safe_dump(d, open(p,'w'), sort_keys=False)
"
    cd "$FRAMEWORK_ROOT"
    run bin/fw doctor
    [[ "$output" == *"designer vendored build drifted from pin"* ]]
    [[ "$output" == *"fw designer sync --from"* ]]
}

@test "t3: vendored file absent per pin path → SKIP (no WARN)" {
    # Point vendored_path at a nonexistent file → not-yet-vendored SKIP branch.
    python3 -c "
import yaml
p = '$FRAMEWORK_ROOT/policy/designer-pin.yaml'
d = yaml.safe_load(open(p))
d['vendored_path'] = 'vendor/designer/does-not-exist-t2524.html'
yaml.safe_dump(d, open(p,'w'), sort_keys=False)
"
    cd "$FRAMEWORK_ROOT"
    run bin/fw doctor
    [[ "$output" == *"designer not yet vendored"* ]]
    [[ "$output" != *"designer vendored build drifted from pin"* ]]
}

@test "t4: pin missing sha256/vendored_path → SKIP" {
    python3 -c "
import yaml
p = '$FRAMEWORK_ROOT/policy/designer-pin.yaml'
d = yaml.safe_load(open(p))
d.pop('sha256', None)
yaml.safe_dump(d, open(p,'w'), sort_keys=False)
"
    cd "$FRAMEWORK_ROOT"
    run bin/fw doctor
    [[ "$output" == *"designer pin present but missing sha256/vendored_path"* ]]
}
