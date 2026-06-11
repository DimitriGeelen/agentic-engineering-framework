#!/usr/bin/env bats
# T-2338 (arc-011 M1 §2) — harness yield-point spike.
#
# Pins `agents/dispatch/yield-point.sh check <target>` behaviour:
#   - no flag → write allowed (exit 0)
#   - matching refuse-write: rule → refused (exit 1 + stderr reason)
#   - non-matching rule → allowed (exit 0)
#   - stale flag (>5min old) → ignored with WARN, write allowed
#   - malformed flag content → fail-open (write allowed)

load ../test_helper

YIELD="$BATS_TEST_DIRNAME/../../agents/dispatch/yield-point.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export FW_YIELD_FLAG="$TEST_TEMP_DIR/.dispatch-flag"
    export FW_YIELD_STALE_SECS=300
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "no flag — write allowed, exit 0" {
    run "$YIELD" check /tmp/somefile.md
    [ "$status" -eq 0 ]
}

@test "matching refuse-write rule — refused, exit 1 + stderr names the path" {
    echo "refuse-write:/tmp/SHARED.md" > "$FW_YIELD_FLAG"
    run "$YIELD" check /tmp/SHARED.md
    [ "$status" -eq 1 ]
    [[ "$output" == *"refusing write"* ]]
    [[ "$output" == *"/tmp/SHARED.md"* ]]
}

@test "non-matching rule — write to different path allowed" {
    echo "refuse-write:/tmp/SHARED.md" > "$FW_YIELD_FLAG"
    run "$YIELD" check /tmp/OTHER.md
    [ "$status" -eq 0 ]
}

@test "stale flag (>5min old) — ignored with WARN, write allowed" {
    echo "refuse-write:/tmp/SHARED.md" > "$FW_YIELD_FLAG"
    # Force mtime to 10 minutes ago
    touch -d "10 minutes ago" "$FW_YIELD_FLAG" 2>/dev/null || touch -t "$(date -d '10 minutes ago' '+%Y%m%d%H%M.%S' 2>/dev/null || date -v-10M '+%Y%m%d%H%M.%S')" "$FW_YIELD_FLAG"
    run "$YIELD" check /tmp/SHARED.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"stale"* ]]
}

@test "malformed flag (no refuse-write: lines) — fail-open, write allowed" {
    cat > "$FW_YIELD_FLAG" <<'EOF'
this is not a recognized directive
unknown-rule:something
EOF
    run "$YIELD" check /tmp/SHARED.md
    [ "$status" -eq 0 ]
}

@test "multi-line flag — second rule matches, refused" {
    cat > "$FW_YIELD_FLAG" <<'EOF'
# comment line
refuse-write:/tmp/OTHER.md
refuse-write:/tmp/SHARED.md
EOF
    run "$YIELD" check /tmp/SHARED.md
    [ "$status" -eq 1 ]
    [[ "$output" == *"refusing write"* ]]
}

@test "usage error — missing target" {
    run "$YIELD" check
    [ "$status" -eq 64 ]
    [[ "$output" == *"usage"* ]]
}

@test "--help prints usage" {
    run "$YIELD" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"check"* ]]
    [[ "$output" == *"refuse-write"* ]]
}

@test "comment-only flag — fail-open, write allowed" {
    cat > "$FW_YIELD_FLAG" <<'EOF'
# this flag has only comments
# orchestrator wrote header but no rules yet
EOF
    run "$YIELD" check /tmp/SHARED.md
    [ "$status" -eq 0 ]
}
