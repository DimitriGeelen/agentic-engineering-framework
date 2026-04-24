#!/bin/bash
# Stub test for agents/context/stop-guard.sh (T-1211)
#
# Exercises 3 scenarios:
#   A. stop_counter below threshold (5) → no nudge
#   B. stop_counter at threshold (15), tool_counter=0, no focus → nudge fired
#   C. stop_counter at threshold (15), tool_counter>0 → no nudge (productive)
#
# Runs in an isolated sandbox (overrides PROJECT_ROOT); does NOT pollute real
# `.context/working/`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HANDLER="$SCRIPT_DIR/../stop-guard.sh"

test -x "$HANDLER" || { echo "FAIL: handler not executable: $HANDLER"; exit 1; }

run_case() {
    local case_name="$1"
    local init_stop_counter="$2"
    local init_next_nudge="$3"
    local tool_counter="$4"
    local focus_task="$5"
    local expect_nudge="$6"

    local sandbox
    sandbox=$(mktemp -d)
    mkdir -p "$sandbox/.context/working"
    [ -n "$init_stop_counter" ] && echo "$init_stop_counter" > "$sandbox/.context/working/.stop-counter"
    [ -n "$init_next_nudge" ] && echo "$init_next_nudge" > "$sandbox/.context/working/.stop-next-nudge-at"
    echo "$tool_counter" > "$sandbox/.context/working/.tool-counter"
    if [ -n "$focus_task" ]; then
        cat > "$sandbox/.context/working/focus.yaml" <<EOF
current_task: $focus_task
EOF
    else
        cat > "$sandbox/.context/working/focus.yaml" <<EOF
current_task: null
EOF
    fi

    local stderr_file="$sandbox/stderr.log"
    local payload='{"stop_hook_active":true,"session_id":"stub","transcript_path":"/nonexistent"}'

    echo "$payload" | PROJECT_ROOT="$sandbox" "$HANDLER" 2> "$stderr_file"
    local rc=$?

    if [ "$rc" -ne 0 ]; then
        echo "FAIL [$case_name]: handler exited non-zero ($rc)"
        rm -rf "$sandbox"; exit 1
    fi

    local saw_nudge=0
    grep -q "stop-guard" "$stderr_file" && saw_nudge=1

    if [ "$expect_nudge" = "yes" ] && [ "$saw_nudge" = 0 ]; then
        echo "FAIL [$case_name]: expected nudge, none emitted"
        cat "$stderr_file"; rm -rf "$sandbox"; exit 1
    fi
    if [ "$expect_nudge" = "no" ] && [ "$saw_nudge" = 1 ]; then
        echo "FAIL [$case_name]: nudge emitted when none expected"
        cat "$stderr_file"; rm -rf "$sandbox"; exit 1
    fi

    echo "  Case $case_name PASS (expect_nudge=$expect_nudge, saw_nudge=$saw_nudge)"
    rm -rf "$sandbox"
}

# Case A: below threshold — counter was 4, increments to 5, next_nudge=15
run_case A 4 15 0 "" no

# Case B: at threshold — counter was 14, increments to 15, next_nudge=15,
#         tool_counter=0, no focus → NUDGE
run_case B 14 15 0 "" yes

# Case C: at threshold but productive — counter was 14, increments to 15,
#         tool_counter=42 → no nudge
run_case C 14 15 42 "" no

# Case D: at threshold but governed — counter was 14, increments to 15,
#         tool_counter=0 BUT focus has a task → no nudge
run_case D 14 15 0 "T-999" no

echo "All stop-guard stub tests PASS"
