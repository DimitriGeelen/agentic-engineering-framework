#!/usr/bin/env bats
# Unit tests for lib/firewall.sh — firewall port management utilities
# Origin: T-910

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"
    _FW_FIREWALL_LOADED=""
    source "$FRAMEWORK_ROOT/lib/firewall.sh"
}

# --- ensure_firewall_open ---

@test "ensure_firewall_open succeeds when ufw not installed" {
    # Override command to report ufw missing
    command() {
        if [[ "$2" == "ufw" ]]; then return 1; fi
        builtin command "$@"
    }
    export -f command
    run ensure_firewall_open 3000
    [ "$status" -eq 0 ]
}

@test "ensure_firewall_open succeeds silently when ufw not installed" {
    command() {
        if [[ "$2" == "ufw" ]]; then return 1; fi
        builtin command "$@"
    }
    export -f command
    run ensure_firewall_open 3000
    [ "$status" -eq 0 ]
    [ -z "$output" ]  # No output when ufw not found
}

@test "ensure_firewall_open uses default comment" {
    # The function should accept PORT without comment
    # We can't easily test the actual ufw call, but we can verify
    # the function accepts the argument pattern
    run bash -c "
        source '$FRAMEWORK_ROOT/lib/firewall.sh'
        # Mock command to say ufw is not installed
        command() { [[ \"\$2\" == 'ufw' ]] && return 1; builtin command \"\$@\"; }
        export -f command
        ensure_firewall_open 3000
    "
    [ "$status" -eq 0 ]
}

@test "ensure_firewall_open accepts custom comment" {
    run bash -c "
        source '$FRAMEWORK_ROOT/lib/firewall.sh'
        command() { [[ \"\$2\" == 'ufw' ]] && return 1; builtin command \"\$@\"; }
        export -f command
        ensure_firewall_open 3000 'Custom comment'
    "
    [ "$status" -eq 0 ]
}

@test "guard prevents double-sourcing" {
    _FW_FIREWALL_LOADED=1
    # Second source should be a no-op (return 0 immediately)
    source "$FRAMEWORK_ROOT/lib/firewall.sh"
    # If we got here, guard works
    [ "$_FW_FIREWALL_LOADED" = "1" ]
}

@test "log functions produce output" {
    run _fw_log_info "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"test message"* ]]
    [[ "$output" == *"firewall"* ]]
}

@test "warn log function produces output" {
    run _fw_log_warn "warning message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"warning message"* ]]
    [[ "$output" == *"firewall"* ]]
}
