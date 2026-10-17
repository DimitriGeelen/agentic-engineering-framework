#!/usr/bin/env bats
# T-4280 (T-3640 follow-up): the pkill -f / killall -r cluster rules read a
# signal name as a flag cluster, so `killall -term foo` (contains r) and
# `pkill -sigprof foo` (contains f) were blocked as pattern kills. A signal
# option is parsed as a signal first; every T-3640 block case still blocks.
#
# Runs the real hook with PROJECT_ROOT in a tempdir (L-256).

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

_expect() {
    run _run_hook "$2"
    if [ "$status" -ne "$1" ]; then
        echo "expected $1, got $status for: $2"
        printf '%s\n' "$output" | head -8
        return 1
    fi
}

@test "signal names are not read as -f/-r clusters" {
    for c in "killall -TERM foo" "killall -term foo" "killall -SIGTERM foo" "killall -sigterm foo" \
             "killall -ALRM foo" "killall -vtalrm foo" "killall -pwr foo" "killall -urg foo" \
             "killall -s TERM foo" "killall --signal TERM foo" \
             "pkill -HUP foo" "pkill -hup foo" "pkill -sigprof foo" "pkill -PROF foo" \
             "pkill -prof foo" "pkill -fpe foo" "pkill -xfsz foo" "pkill -stkflt foo" \
             "pkill --signal=TERM foo" "pkill --signal TERM foo" "pkill -TERM -x foo"; do
        _expect 0 "$c"
    done
}

@test "T-3640 block cases still block" {
    for c in "pkill -9 foo" "pkill -KILL foo" "pkill -SIGKILL foo" "pkill -s 9 foo" \
             "pkill --signal=KILL foo" "pkill -f foo" "pkill --full foo" "pkill -ef x" \
             "pkill -TERM -f foo" "pkill -HUP -ef foo" "killall -r 'x.*'" "killall --regexp x" \
             "killall -KILL x" "killall -TERM -r x" "killall -er x"; do
        _expect 2 "$c"
    done
}

@test "a cluster that only starts like a signal name still blocks" {
    for c in "pkill -termf foo" "pkill -proff foo" "killall -termr foo" "killall -hupr foo"; do
        _expect 2 "$c"
    done
}
