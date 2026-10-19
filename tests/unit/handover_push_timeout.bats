#!/usr/bin/env bats
# T-1277 — handover.sh wraps `git push` with `timeout` so an unreachable
# remote (e.g. onedev VPN down) cannot stall the auto-handover hook for
# hours. Default bound 15s, override via FW_HANDOVER_PUSH_TIMEOUT.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export FRAMEWORK_ROOT
    export NO_COLOR=1
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ---- Source-level invariants ----

@test "handover.sh wraps git push with timeout (T-1277)" {
    grep -q 'timeout "\$_push_timeout" git -C "\$PROJECT_ROOT" push' "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}

@test "handover.sh reads FW_HANDOVER_PUSH_TIMEOUT (T-1277)" {
    grep -q 'FW_HANDOVER_PUSH_TIMEOUT' "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}

@test "handover.sh distinguishes timeout (exit 124) from other failures" {
    # T-3063 reworded the 124 branch ('timed out after' -> 'was KILLED at'); T-4385
    # follows the wording, the invariant is the dedicated 124 branch and its message.
    grep -q 'was KILLED at' "$FRAMEWORK_ROOT/agents/handover/handover.sh"
    grep -q '_exit.*-eq 124' "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}

@test "checkpoint.sh wraps auto-handover invocation in timeout (T-1277 belt-and-braces)" {
    # T-4385: checkpoint.sh now names the interpreter (`timeout N bash handover.sh`).
    grep -qE 'timeout "\$_ah_total_timeout" (bash )?"\$FRAMEWORK_ROOT/agents/handover/handover.sh"' "$FRAMEWORK_ROOT/agents/context/checkpoint.sh"
}

@test "checkpoint.sh reads FW_HANDOVER_TOTAL_TIMEOUT" {
    grep -q 'FW_HANDOVER_TOTAL_TIMEOUT' "$FRAMEWORK_ROOT/agents/context/checkpoint.sh"
}

# ---- Behavioural: push to deadhost finishes within bound ----

@test "push to unreachable remote times out within bound (real timeout cmd)" {
    # 192.0.2.0/24 is RFC 5737 TEST-NET-1 — guaranteed non-routable.
    # Without the timeout, this would block until git's HTTPS transport
    # retry cycle gives up (minutes-to-hours).
    cd "$TEST_TEMP_DIR"
    git init -q
    git config user.email "t1277@test.local"
    git config user.name "T-1277 test"
    git -c commit.gpgsign=false commit --allow-empty -m "init" -q
    git remote add deadremote "https://192.0.2.1/dead.git"

    local start end elapsed
    start=$(date +%s)
    # Mirror the wrap pattern used in handover.sh.
    timeout 5 git push deadremote HEAD 2>&1 || true
    end=$(date +%s)
    elapsed=$((end - start))

    # Must not exceed 5s + small slack; classic stall would run minutes.
    [ "$elapsed" -le 8 ]
}

# ---- Default value sanity ----

# "default push timeout is 60s when env var unset" was deleted by T-4385: T-3450
# replaced the static default with a per-push derivation on purpose, and
# t3450_push_timeout_derivation.bats ("derives the default via
# fw_handover_push_timeout_default when unset", "the old static 300 default is
# gone") pins the replacement behaviour.

@test "default total timeout is 60s when env var unset" {
    grep -q '${FW_HANDOVER_TOTAL_TIMEOUT:-60}' "$FRAMEWORK_ROOT/agents/context/checkpoint.sh"
}
