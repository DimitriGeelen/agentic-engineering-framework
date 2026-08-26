#!/usr/bin/env bats
# T-3166 (arc-012 S2) — the budget auto-restart must FREE context, not restore it.
#
# The tests below execute the decision block lifted out of bin/claude-fw itself
# rather than a copy of it, so editing the wrapper moves these assertions. A test
# written against a transcribed snippet would stay green against a wrapper that
# had stopped honouring the variable entirely.

setup() {
    SRC="${BATS_TEST_DIRNAME}/../../bin/claude-fw"
}

# Lift the CLAUDE_ARGS decision out of the real wrapper: find the FW_RESTART_MODE
# `if` whose body actually assigns CLAUDE_ARGS, and print that block.
extract_decision() {
    python3 - "$SRC" <<'PY'
import sys
lines = open(sys.argv[1]).read().split('\n')
for start, line in enumerate(lines):
    if not line.strip().startswith('if [ "${FW_RESTART_MODE'):
        continue
    depth = 0
    for end in range(start, len(lines)):
        s = lines[end].strip()
        if s.startswith('if '):
            depth += 1
        elif s == 'fi':
            depth -= 1
            if depth == 0:
                break
    block = lines[start:end + 1]
    if any('CLAUDE_ARGS' in b for b in block):
        print('\n'.join(b.strip() for b in block))
        raise SystemExit(0)
raise SystemExit("no FW_RESTART_MODE block assigning CLAUDE_ARGS found")
PY
}

run_decision() {
    local decision
    decision="$(extract_decision)"
    [ -n "$decision" ] || return 1
    bash -c "CLAUDE_ARGS=(); ${decision}; printf 'ARGS=[%s]' \"\${CLAUDE_ARGS[*]}\""
}

@test "the decision block can be lifted from bin/claude-fw at all" {
    run extract_decision
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'CLAUDE_ARGS'
}

@test "default is a FRESH session — no -c, so the restart actually frees context" {
    run run_decision
    [ "$status" -eq 0 ]
    [ "$output" = "ARGS=[]" ]
}

@test "FW_RESTART_MODE=continue restores -c — the control leg" {
    # Without this the previous test passes against a wrapper that ignores the
    # variable and never sets -c under any condition.
    export FW_RESTART_MODE=continue
    run run_decision
    [ "$status" -eq 0 ]
    [ "$output" = "ARGS=[-c]" ]
}

@test "an unrecognised FW_RESTART_MODE value falls back to fresh, not to -c" {
    export FW_RESTART_MODE=banana
    run run_decision
    [ "$output" = "ARGS=[]" ]
}

@test "the restart path still writes the .auto-restart-pending sentinel" {
    # post-compact-resume.sh gates its SessionStart source=startup branch on this
    # file. Dropping it silently disables directive injection on every restart.
    grep -q 'auto-restart-pending' "$SRC"
    grep -q 'restart_sentinel' "$SRC"
}

@test "the banner names both restart modes" {
    grep -q 'Restart mode: fresh' "$SRC"
    grep -q 'Restart mode: continue' "$SRC"
}

@test "wrapper parses" {
    bash -n "$SRC"
}
