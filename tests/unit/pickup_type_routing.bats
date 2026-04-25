#!/usr/bin/env bats
# Unit tests for T-1465 — pickup envelope type → task workflow_type routing.
# Constrained Option A (T-1455 GO):
#   bug-report       → build
#   feature-proposal → inception
#   learning         → inception
#   pattern          → inception
#
# Strategy: stub `fw` on PATH to capture --type, source lib/pickup.sh, and
# call pickup_create_inception with crafted envelopes. We assert on the
# captured arguments — no real task is created.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP=$(mktemp -d)
    # Stub `fw` — writes the full arg list to $TMP/fw-args, prints a benign File: line.
    mkdir -p "$TMP/bin"
    cat > "$TMP/bin/fw" <<'STUB'
#!/bin/bash
echo "$@" > "$FW_STUB_ARGS"
echo "File: /dev/null"
STUB
    chmod +x "$TMP/bin/fw"
    export FW_STUB_ARGS="$TMP/fw-args"
    export PATH="$TMP/bin:$PATH"

    # shellcheck source=lib/pickup.sh
    source "$FRAMEWORK_ROOT/lib/pickup.sh"
}

teardown() {
    rm -rf "$TMP"
    unset FW_STUB_ARGS
}

write_envelope() {
    local file="$1" type="$2"
    cat > "$file" <<EOF
pickup_id: P-999
type: ${type}
source:
  project: "/tmp/test-project"
  task_id: T-1
  summary: "test envelope"
EOF
}

@test "pickup_create_inception: bug-report envelope → --type build" {
    write_envelope "$TMP/env.yaml" "bug-report"
    pickup_create_inception "$TMP/env.yaml" >/dev/null
    run cat "$FW_STUB_ARGS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"--type build"* ]]
    [[ "$output" != *"--type inception"* ]]
}

@test "pickup_create_inception: feature-proposal envelope → --type inception" {
    write_envelope "$TMP/env.yaml" "feature-proposal"
    pickup_create_inception "$TMP/env.yaml" >/dev/null
    run cat "$FW_STUB_ARGS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"--type inception"* ]]
    [[ "$output" != *"--type build"* ]]
}

@test "pickup_create_inception: learning envelope → --type inception" {
    write_envelope "$TMP/env.yaml" "learning"
    pickup_create_inception "$TMP/env.yaml" >/dev/null
    run cat "$FW_STUB_ARGS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"--type inception"* ]]
}

@test "pickup_create_inception: pattern envelope → --type inception" {
    write_envelope "$TMP/env.yaml" "pattern"
    pickup_create_inception "$TMP/env.yaml" >/dev/null
    run cat "$FW_STUB_ARGS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"--type inception"* ]]
}

@test "pickup_create_inception: tags still include the envelope type" {
    write_envelope "$TMP/env.yaml" "bug-report"
    pickup_create_inception "$TMP/env.yaml" >/dev/null
    run cat "$FW_STUB_ARGS"
    [[ "$output" == *"pickup,bug-report"* ]]
}
