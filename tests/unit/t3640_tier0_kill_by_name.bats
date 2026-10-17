#!/usr/bin/env bats
# T-3640 (055 P-006): check-tier0.sh blocked only 'pkill -9'. A worker in 055
# ran `pkill -KILL -f 'sleep|trap'` and SIGKILLed every matching process on
# the host. Kill-by-name is Tier 0 when it uses SIGKILL in any spelling, or
# when it matches by pattern (pkill -f/--full, killall -r/--regexp).
#
# Runs the real hook with PROJECT_ROOT in a tempdir: every block writes a
# pending approval, which must not land in the real .context/ (L-256).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$TEST_TEMP_DIR/.context/approvals" "$TEST_TEMP_DIR/.context/working"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-tier0.sh"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_run_hook() {
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_input':{'command': sys.argv[1]}}))" "$1")
    echo "$json" | bash "$HOOK"
}

_blocked() {
    run _run_hook "$1"
    if [ "$status" -ne 2 ]; then
        echo "expected block (2), got $status for: $1"
        return 1
    fi
    if [ -n "${2:-}" ] && ! printf '%s' "$output" | grep -q "$2"; then
        echo "block message lacks '$2' for: $1"
        printf '%s\n' "$output" | head -12
        return 1
    fi
}

_allowed() {
    run _run_hook "$1"
    if [ "$status" -ne 0 ]; then
        echo "expected allow (0), got $status for: $1"
        printf '%s\n' "$output" | head -12
        return 1
    fi
}

# ── SIGKILL by name, every spelling ──

@test "pkill: the 055 incident command is blocked" {
    _blocked "pkill -KILL -f 'sleep|trap'"
}

@test "pkill: SIGKILL spellings are blocked and named" {
    for c in "pkill -9 foo" "pkill -KILL foo" "pkill -SIGKILL foo" "pkill -kill foo" \
             "pkill -sigkill foo" "pkill -s 9 foo" "pkill -s KILL foo" "pkill -s SIGKILL foo" \
             "pkill -s9 foo" "pkill -sKILL foo" "pkill --signal 9 foo" "pkill --signal=KILL foo" \
             "pkill --signal SIGKILL foo" "pkill --sig=9 foo" "pkill -u root -9 foo" \
             "/usr/bin/pkill -KILL foo" "sudo pkill -KILL foo" "pkill '-9' foo"; do
        _blocked "$c" "SIGKILL BY NAME"
    done
}

@test "killall: SIGKILL spellings are blocked and named" {
    for c in "killall -9 foo" "killall -KILL foo" "killall -SIGKILL foo" "killall -s KILL foo" \
             "killall -s 9 foo" "killall --signal=SIGKILL foo" "killall --signal KILL foo"; do
        _blocked "$c" "SIGKILL BY NAME"
    done
}

# ── Pattern match against every process's command line ──

@test "pkill -f / --full is blocked whatever the signal, clustered too" {
    for c in "pkill -f sleep" "pkill -TERM -f sleep" "pkill --full sleep" "pkill --ful sleep" \
             "pkill -ef sleep" "pkill -fx sleep" "pkill -u me -f sleep" "pkill -f 'sleep|trap'"; do
        _blocked "$c" "PKILL -f"
    done
}

@test "killall -r / --regexp is blocked, clustered too" {
    for c in "killall -r 'sl.*p'" "killall --regexp foo" "killall --reg foo" "killall -ir foo" \
             "killall -TERM -r foo"; do
        _blocked "$c" "KILLALL -r"
    done
}

@test "each kill block names the safe alternative" {
    _blocked "pkill -KILL foo" "kill the PID"
    _blocked "pkill -f foo" "kill the PID"
    _blocked "killall -r foo" "kill the PID"
}

# ── Controls that must stay allowed ──

@test "kill by PID / process group stays allowed" {
    for c in "kill 12345" "kill -9 12345" "kill -KILL 12345" "kill -TERM -12345" "kill -s KILL 12345"; do
        _allowed "$c"
    done
}

@test "plain pkill / killall by exact name with a non-KILL signal stays allowed" {
    for c in "pkill foo" "pkill -TERM foo" "pkill -HUP foo" "pkill --signal=TERM foo" \
             "pkill -u me foo" "killall foo" "killall -TERM foo" "killall -s HUP foo"; do
        _allowed "$c"
    done
}

@test "pgrep and words that mention pkill stay allowed" {
    for c in "pgrep -f sleep" "pgrep -af 'sleep|trap'" "grep -rn pkill tests/unit" \
             "grep -n killall agents/context/check-tier0.sh" "echo 'pkill -KILL -f sleep'" \
             "git log --grep 'pkill -9'"; do
        _allowed "$c"
    done
}

@test "a kill rule in a comment does not fire" {
    _allowed "echo ok   # never run pkill -9 -f x here"
}
