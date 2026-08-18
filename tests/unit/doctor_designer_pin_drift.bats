#!/usr/bin/env bats
# T-2524 (T-2521 integration hardening): fw doctor content-compares (sha256, never
# mtime) the vendored Workflow Designer build against policy/designer-pin.yaml.
# Sibling of the MCP manifest + cron registry→generated drift checks.
#
# Surface under test: bin/fw doctor designer-pin block.
# States:
#   vendored sha256 == pin sha256           → OK    — t1
#   vendored sha256 != pin sha256           → WARN  — t2
#   vendored file absent (per pin path)     → WARN  — t3 (was SKIP until T-3064)
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

@test "t3: vendored file absent per pin path → WARN (T-3064)" {
    # Point the TEMP pin's vendored_path at a nonexistent file → pinned-but-absent.
    #
    # This test asserted SKIP until T-3064. That was the defect, not the contract: a
    # pin naming a build the project does not have is actionable, and SKIP reads as
    # "not applicable here" — so the serious state was quieter than mere pin drift.
    # The pin's presence is the project saying it wants the designer; absence of the
    # artifact is therefore a finding, not an exemption.
    python3 -c "
import yaml
p = '$PIN_TMP'
d = yaml.safe_load(open(p))
d['vendored_path'] = 'vendor/designer/does-not-exist-t2524.html'
yaml.safe_dump(d, open(p,'w'), sort_keys=False)
"
    cd "$FRAMEWORK_ROOT"
    run bin/fw doctor
    [[ "$output" == *"designer pinned but not vendored"* ]]
    # The verdict word on THAT line, not merely somewhere in the output. The whole
    # point of T-3064 is which of SKIP/WARN this line carries, so the assertion has
    # to be line-scoped: `$output == *WARN*designer pinned*` passes against a SKIP,
    # because some earlier check in a ~40-line doctor run has almost always already
    # printed a WARN. Verified by mutation — that weaker form let the SKIP mutant live.
    local vline
    vline=$(printf '%s\n' "$output" | sed 's/\x1b\[[0-9;]*m//g' | grep "designer pinned but not vendored")
    [[ "$vline" == *"WARN"* ]]
    [[ "$vline" != *"SKIP"* ]]
    [[ "$output" != *"designer not yet vendored"* ]]
    # Actionable: name the intake verb, since the operator reaching this line has a
    # pin and no artifact and needs to know which command closes that gap.
    [[ "$output" == *"fw designer sync --from-tag"* ]]
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
