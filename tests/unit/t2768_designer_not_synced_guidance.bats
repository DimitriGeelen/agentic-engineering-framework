#!/usr/bin/env bats
# T-2768 (T-2757 IW-4): the designer not-synced guidance must name a SOURCE for the
# build and state the LAN precondition of the fetch path. It used to say only
# "832 must deliver the build, then: fw designer sync --from <file>" — a dead end.

setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO/agents/designer/designer.sh"
    ROOT="$(mktemp -d)"
    mkdir -p "$ROOT/policy"
    unset FRAMEWORK_ROOT
    export FW_DESIGNER_PIN_FILE="$ROOT/policy/designer-pin.yaml"
    cat > "$ROOT/policy/designer-pin.yaml" <<EOF
version: "9.9.9"
sha256: "0000000000000000000000000000000000000000000000000000000000000000"
bytes: 22
source_origin: "ssh://git@lan-host.example:6611/workflow-designer"
vendored_path: "vendor/designer/fixture.html"
EOF
}

teardown() { rm -rf "$ROOT"; }

_assert_guidance() {
    [[ "$output" == *"fw designer install"* ]]
    [[ "$output" == *"fw designer sync --from-tag"* ]]
    [[ "$output" == *"ssh://git@lan-host.example:6611/workflow-designer"* ]]
    [[ "$output" == *"LAN"* ]]
    [[ "$output" == *"reachable from this host"* ]]
    [[ "$output" == *"fw designer sync --from <file>"* ]]
}

@test "status (not synced) names every source and the LAN precondition" {
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"NOT SYNCED"* ]]
    _assert_guidance
}

@test "path (not synced) exits 1 with the same guidance on stderr" {
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" path
    [ "$status" -eq 1 ]
    _assert_guidance
}

@test "guidance survives a pin without source_origin (names the gap, not blank)" {
    sed -i '/^source_origin:/d' "$ROOT/policy/designer-pin.yaml"
    run env PROJECT_ROOT="$ROOT" bash "$SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"source_origin unset"* ]]
}
