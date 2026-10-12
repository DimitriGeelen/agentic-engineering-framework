#!/usr/bin/env bats
# T-4114: check-project-boundary Pattern 3 matched `tee\s+(/path)` only, so any
# option between `tee` and the path walked past it — `echo x | tee -a /etc/fstab`
# exited 0 (the read-side Pattern 4 allowlists /etc/, so nothing else caught it).
# Same gap for a second path (`tee /tmp/ok /etc/x`): only the first was checked.
# And the bash pre-filter (`tee\s+/`) let `tee -a /srv/x` skip analysis entirely.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
    [ -x "$HOOK" ]
    export PROJECT_ROOT="$FRAMEWORK_ROOT"
}

run_hook() {
    local payload
    payload=$(python3 -c "
import json, sys
print(json.dumps({'tool_name': 'Bash', 'tool_input': {'command': sys.argv[1]}}))
" "$1")
    echo "$payload" | bash "$HOOK"
}

blocks() {
    run run_hook "$1"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "File write to"
}

allows() {
    run run_hook "$1"
    [ "$status" -eq 0 ]
}

# ── control: the shape the old regex already caught ──
@test "control: tee /etc/fstab (no options) blocks" {
    blocks 'echo x | tee /etc/fstab'
}

# ── bypasses (exit 0 on the pre-fix hook) ──
@test "tee -a /etc/fstab blocks" {
    blocks 'echo x | tee -a /etc/fstab'
}

@test "tee --append /etc/fstab blocks" {
    blocks 'echo x | tee --append /etc/fstab'
}

@test "tee -ai /etc/fstab blocks" {
    blocks 'echo x | tee -ai /etc/fstab'
}

@test "tee -a -p /etc/fstab blocks" {
    blocks 'echo x | tee -a -p /etc/fstab'
}

@test "tee --output-error=warn /etc/fstab blocks" {
    blocks 'echo x | tee --output-error=warn /etc/fstab'
}

@test "tee -- /etc/fstab blocks" {
    blocks 'echo x | tee -- /etc/fstab'
}

@test "tee with several paths: an outside second path blocks" {
    blocks 'echo x | tee /tmp/t4114-ok /etc/fstab'
}

@test "tee -a with several paths: an outside third path blocks" {
    blocks 'echo x | tee -a /tmp/t4114-a /tmp/t4114-b /etc/fstab'
}

@test "sudo tee -a /etc/fstab blocks" {
    blocks 'echo x | sudo tee -a /etc/fstab'
}

@test "/usr/bin/tee -a /etc/fstab blocks" {
    blocks 'echo x | /usr/bin/tee -a /etc/fstab'
}

@test "tee -a to a path outside the pre-filter's dir list (/srv) blocks" {
    blocks 'echo x | tee -a /srv/t4114'
}

# ── allowed targets stay allowed ──
@test "tee -a /tmp path allowed" {
    allows 'echo x | tee -a /tmp/t4114-out'
}

@test "tee -a in-project path allowed" {
    allows "echo x | tee -a $FRAMEWORK_ROOT/.context/working/t4114-out"
}

@test "tee -a /tmp and in-project paths together allowed" {
    allows "echo x | tee -a /tmp/t4114-out $FRAMEWORK_ROOT/.context/working/t4114-out"
}

@test "tee with relative path allowed" {
    allows 'echo x | tee -a out.log'
}

@test "tee path list stops at the next segment" {
    allows 'echo x | tee -a /tmp/t4114-out && ls /usr/share'
}
