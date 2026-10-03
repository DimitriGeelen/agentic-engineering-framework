#!/usr/bin/env bats
# T-3750: fw upgrade back-fills the minted project_id (T-3534) on a consumer
# initialised before it existed, preserves an existing one, and a dry-run
# writes nothing. Fixture shape follows upgrade_fresh_machine_simulation.bats
# (T-3636 test): vendored consumer, file:// upstream, scrubbed env.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t3750-XXXXXX)"
    export FRAMEWORK_ROOT
    UPSTREAM="$TEST_TEMP_DIR/upstream.git"
    git clone --quiet --bare --shared "$FRAMEWORK_ROOT" "$UPSTREAM" 2>/dev/null
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_consumer() {
    local proj="$1" extra="${2:-}"
    "$FRAMEWORK_ROOT/bin/fw" vendor --target "$proj" --source "$FRAMEWORK_ROOT" >/dev/null
    cat > "$proj/.framework.yaml" <<YAML
project_name: $(basename "$proj")
version: $(tr -d '\n' < "$proj/.agentic-framework/VERSION")
provider: claude
upstream_repo: file://$UPSTREAM
$extra
YAML
    mkdir -p "$proj/.tasks/active" "$proj/.tasks/completed" "$proj/.context/project"
    printf -- '---\nid: T-001\ntags: [onboarding]\n---\n' > "$proj/.tasks/completed/T-001-done.md"
}

_upgrade() {
    local proj="$1"; shift
    env -i PATH="/usr/local/bin:/usr/bin:/bin" HOME="$TEST_TEMP_DIR/home" \
        "$proj/.agentic-framework/bin/fw" upgrade "$proj" "$@"
}

@test "upgrade mints a project_id when none is recorded" {
    local proj="$TEST_TEMP_DIR/legacy"
    _consumer "$proj"
    run grep -q '^project_id:' "$proj/.framework.yaml"
    [ "$status" -ne 0 ]
    run _upgrade "$proj"
    [ "$status" -eq 0 ] || { echo "$output" | tail -20; false; }
    grep -qE '^project_id: pid-[0-9a-f]{16}$' "$proj/.framework.yaml" \
        || { echo "$output" | grep -iE "identity|project_id|step|═|──" | head -40; cat "$proj/.framework.yaml"; false; }
    [ "$(grep -c '^project_id:' "$proj/.framework.yaml")" -eq 1 ]
    [[ "$output" == *"MINTED"*"project_id"* ]]
}

@test "upgrade preserves an existing project_id byte-for-byte" {
    local proj="$TEST_TEMP_DIR/registered"
    _consumer "$proj" "project_id: pid-0123456789abcdef"
    run _upgrade "$proj"
    [ "$status" -eq 0 ] || { echo "$output" | tail -20; false; }
    [ "$(grep '^project_id:' "$proj/.framework.yaml")" = "project_id: pid-0123456789abcdef" ]
    [ "$(grep -c '^project_id:' "$proj/.framework.yaml")" -eq 1 ]
}

@test "upgrade --dry-run writes no project_id" {
    local proj="$TEST_TEMP_DIR/dry"
    _consumer "$proj"
    run _upgrade "$proj" --dry-run
    [ "$status" -eq 0 ] || { echo "$output" | tail -20; false; }
    ! grep -q '^project_id:' "$proj/.framework.yaml"
}
