#!/usr/bin/env bats
# T-5398: `fw designer status` checks that the validator refusal mapping names the
# pinned validator. T-5390 re-pinned 0.47.0 -> 0.48.1 without the mapping edit and every
# pickup check stayed green; test_t5189 went red later, at an unrelated close.
# Hermetic: a throwaway project root with its own pin, build and mapping.

setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO/agents/designer/designer.sh"
    ROOT="$(mktemp -d)"
    unset FRAMEWORK_ROOT
    mkdir -p "$ROOT/policy" "$ROOT/vendor/designer" "$ROOT/docs/research/executable-workflow/contracts/v2"
    export FW_DESIGNER_PIN_FILE="$ROOT/policy/designer-pin.yaml"
    printf 'BUILD' > "$ROOT/vendor/designer/build.html"
    SHA="$(sha256sum "$ROOT/vendor/designer/build.html" | cut -d' ' -f1)"
    printf 'version: "9.9.9"\nsha256: "%s"\nbytes: 5\nvendored_path: vendor/designer/build.html\n' "$SHA" > "$FW_DESIGNER_PIN_FILE"
    printf 'v' > "$ROOT/vendor/designer/validate-workflow-9.9.9.py"
    MAP="$ROOT/docs/research/executable-workflow/contracts/v2/validator-refusal-mapping.yaml"
}

teardown() { rm -rf "$ROOT"; }

_map() {
    printf 'sources:\n  validator:\n    path: %s\n    version: %s\n    sha256: x\nreason_codes: {}\n' "$1" "$2" > "$MAP"
}

@test "status passes when the mapping names the pinned validator" {
    _map vendor/designer/validate-workflow-9.9.9.py 9.9.9
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"names validator 9.9.9"* ]]
}

@test "status fails and names the file when the mapping names an older validator" {
    _map vendor/designer/validate-workflow-9.9.8.py 9.9.8
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" status
    [ "$status" -eq 1 ]
    [[ "$output" == *"STALE"* ]]
    [[ "$output" == *"validator-refusal-mapping.yaml"* ]]
}

@test "status fails when the mapping's version matches but its file is gone" {
    _map vendor/designer/validate-workflow-missing.py 9.9.9
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" status
    [ "$status" -eq 1 ]
}

@test "status is silent about the mapping where none exists (consumer projects)" {
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" != *"refusal map"* ]]
}
