#!/usr/bin/env bats
# T-3425 (OBS-461) — the sidecar's read verbs and TermLink's channel reads are
# on the task gate's read-only allowlist; their write forms are not.
#
# Origin: right after a task close nulled focus, with the only focusable
# task partial-complete, `bin/fw sidecar inbox --peek` was refused by
# check-active-task.sh — a session could not see whether a peer consult was
# waiting for it. Each accepted and each refused form is pinned here so the
# read/write split cannot drift silently in either direction.

load ../test_helper

setup() {
    # The shared teardown rm -rf's TEST_TEMP_DIR and FAILS the test when it is
    # unset — every suite loading test_helper must set it (see t3096).
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    # shellcheck source=/dev/null
    source "$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"
}

# ── accepted reads ───────────────────────────────────────────────────────────

@test "t3425: fw sidecar whoami is a read (bin/fw, bare fw, vendored)" {
    run is_bash_safe_command "bin/fw sidecar whoami"; [ "$status" -eq 0 ]
    run is_bash_safe_command "fw sidecar whoami --json"; [ "$status" -eq 0 ]
    run is_bash_safe_command ".agentic-framework/bin/fw sidecar whoami"; [ "$status" -eq 0 ]
}

@test "t3425: fw sidecar inbox --peek is a read, with or without --json" {
    run is_bash_safe_command "bin/fw sidecar inbox --peek"; [ "$status" -eq 0 ]
    run is_bash_safe_command "bin/fw sidecar inbox --peek --json"; [ "$status" -eq 0 ]
    run is_bash_safe_command "bin/fw sidecar inbox --json --peek"; [ "$status" -eq 0 ]
}

@test "t3425: fw sidecar status is a read (reads our own files, never the hub)" {
    run is_bash_safe_command "bin/fw sidecar status"; [ "$status" -eq 0 ]
    run is_bash_safe_command "bin/fw sidecar status --json"; [ "$status" -eq 0 ]
}

@test "t3425: termlink channel subscribe / cv-keys / ack-status are reads" {
    run is_bash_safe_command "termlink channel subscribe sidecar:me --json --cursor 0 --limit 50"; [ "$status" -eq 0 ]
    run is_bash_safe_command "termlink channel cv-keys sidecar:me --json"; [ "$status" -eq 0 ]
    run is_bash_safe_command "termlink channel ack-status sidecar:me"; [ "$status" -eq 0 ]
    run is_bash_safe_command "termlink list"; [ "$status" -eq 0 ]
}

# ── refused writes (the other half of the contract) ──────────────────────────

@test "t3425: fw sidecar inbox WITHOUT --peek advances the cursor and stays gated" {
    run is_bash_safe_command "bin/fw sidecar inbox"; [ "$status" -ne 0 ]
    run is_bash_safe_command "bin/fw sidecar inbox --json"; [ "$status" -ne 0 ]
}

@test "t3425: fw sidecar status --probe calls the hub and stays gated" {
    run is_bash_safe_command "bin/fw sidecar status --probe"; [ "$status" -ne 0 ]
}

@test "t3425: fw sidecar send / sweep / e2e write and stay gated" {
    run is_bash_safe_command "bin/fw sidecar send --to x --body hi"; [ "$status" -ne 0 ]
    run is_bash_safe_command "bin/fw sidecar sweep"; [ "$status" -ne 0 ]
    run is_bash_safe_command "bin/fw sidecar e2e --task T-1"; [ "$status" -ne 0 ]
}

@test "t3425: termlink channel post / ack / create stay gated" {
    run is_bash_safe_command "termlink channel post sidecar:me hello"; [ "$status" -ne 0 ]
    run is_bash_safe_command "termlink channel ack sidecar:me"; [ "$status" -ne 0 ]
    run is_bash_safe_command "termlink channel create sidecar:me"; [ "$status" -ne 0 ]
}
