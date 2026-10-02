#!/usr/bin/env bats
# T-3744: every site in update-task.sh that archives a task (TASK_FILE="$DEST")
# must null the horizon within a few lines of the move. The end-of-script
# ARCHIVED-HORIZON INVARIANT (T-3235) is unreachable when a caller's timeout
# kills the script after the move — Watchtower's decide (30 s) did exactly that
# on T-3723, T-3631 and T-3726.

SCRIPT="${BATS_TEST_DIRNAME}/../../agents/task-create/update-task.sh"

@test "every archive move site nulls the horizon immediately" {
    run python3 - "$SCRIPT" <<'EOF'
import sys
lines = open(sys.argv[1]).read().splitlines()
sites = [i for i, l in enumerate(lines) if l.strip() == 'TASK_FILE="$DEST"']
assert sites, "no archive move sites found"
bad = [i + 1 for i in sites
       if not any('horizon: null' in l for l in lines[i:i + 6])]
print(f"sites={len(sites)} bad={bad}")
sys.exit(1 if bad else 0)
EOF
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "end-of-script invariant is still present as a backstop" {
    grep -q "ARCHIVED-HORIZON INVARIANT" "$SCRIPT"
}
