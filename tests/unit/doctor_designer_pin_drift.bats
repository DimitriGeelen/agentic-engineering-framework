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
# HERMETIC (T-2547): the pin drift check honors FW_DESIGNER_PIN_FILE. Each test points
# it at a TEMP COPY of the pin and mutates only that copy — the live tracked
# policy/designer-pin.yaml is NEVER written. This is interrupt-safe: a run killed
# mid-test (timeout / pkill / agent teardown) leaves the working tree clean, because
# nothing ever wrote the real file. (Origin: the pre-T-2547 version mutated the live
# pin in place + restored in teardown; interrupted runs corrupted the working copy —
# hit live twice during the T-2546 0.3.0 re-pin.) vendored_path still resolves against
# PROJECT_ROOT, so the real vendored build is used regardless of which pin is read.

load ../test_helper

setup() {
    PIN_TMP=$(mktemp -t fw-t2524-pin-XXXXXX.yaml)
    cp "$FRAMEWORK_ROOT/policy/designer-pin.yaml" "$PIN_TMP"
    export FW_DESIGNER_PIN_FILE="$PIN_TMP"
}

teardown() {
    rm -f "${PIN_TMP:-}"
    unset FW_DESIGNER_PIN_FILE
}

@test "t1: vendored build matches pin sha256 → OK" {
    # Temp pin is a verbatim copy of the live (synced) pin → vendored build matches.
    cd "$FRAMEWORK_ROOT"
    run bin/fw doctor
    [[ "$output" == *"designer vendored build matches pin"* ]]
    [[ "$output" != *"designer vendored build drifted from pin"* ]]
}

@test "t2: vendored build sha256 != pin sha256 → WARN" {
    # Bump the TEMP pin's sha256 to a bogus value without re-syncing → drift.
    python3 -c "
import yaml
p = '$PIN_TMP'
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
    # Point the TEMP pin's vendored_path at a nonexistent file → not-yet-vendored SKIP.
    python3 -c "
import yaml
p = '$PIN_TMP'
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
p = '$PIN_TMP'
d = yaml.safe_load(open(p))
d.pop('sha256', None)
yaml.safe_dump(d, open(p,'w'), sort_keys=False)
"
    cd "$FRAMEWORK_ROOT"
    run bin/fw doctor
    [[ "$output" == *"designer pin present but missing sha256/vendored_path"* ]]
}

@test "t5: live pin is never mutated (hermetic guard) → working tree clean" {
    # Regression guard for T-2547: run a mutating case, then assert the live tracked
    # pin is byte-identical to HEAD (the test wrote only the temp copy).
    python3 -c "
import yaml
p = '$PIN_TMP'
d = yaml.safe_load(open(p))
d['sha256'] = '0'*64
yaml.safe_dump(d, open(p,'w'), sort_keys=False)
"
    cd "$FRAMEWORK_ROOT"
    run bin/fw doctor
    run git diff --quiet -- policy/designer-pin.yaml
    [ "$status" -eq 0 ]
}
