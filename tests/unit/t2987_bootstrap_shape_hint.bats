#!/usr/bin/env bats
# T-2987: the task gate advertises an unblock command it then blocks when redirected.
#
# Reported from a fresh consumer project: focus pointed at a completed T-001, the gate
# blocked, and its message said to run `fw work-on T-XXX`. The agent ran exactly that —
# with the output redirected — and got the byte-identical message back. Nothing in it
# said the redirect was the cause, so the agent retyped and looped.
#
# The exemption at check-active-task.sh:194/:227 is guarded by has_bash_write_pattern,
# which classifies the WHOLE command line while the exemption is about ONE command in
# it. A `>` anywhere — on an unrelated chained command, or just capturing the bootstrap
# command's own output — voids it for the bootstrap command too.
#
# The guard is deliberate (:213-222 argues for failing toward blocking; L-547/T-2834
# says a fast-path exemption must classify the whole command) and is NOT relaxed. So
# this file pins BOTH directions, and the second matters more than the first:
#
#   1. the block now explains the shape, so the loop terminates
#   2. the redirected form STILL exits 2 — this was a message fix, not a permission fix
#
# If a later change makes test "still blocked" fail, the exemption has been widened and
# `fw work-on X > .claude/settings.json` is likely admitted. That is the regression to
# fear here, not a missing hint.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
    [ -f "$HOOK" ] || skip "check-active-task.sh not found"

    SB="$(mktemp -d)"
    mkdir -p "$SB/.context/working" "$SB/.tasks/active" "$SB/.tasks/completed"
    echo "framework_version: test" > "$SB/.framework.yaml"

    # The reported state: focus points at a task that has already completed.
    echo "current_task: T-001" > "$SB/.context/working/focus.yaml"
    printf -- '---\nid: T-001\nstatus: work-completed\n---\n' > "$SB/.tasks/completed/T-001-done.md"
    printf -- '---\nid: T-016\nstatus: started-work\n---\n' > "$SB/.tasks/active/T-016-live.md"
}

teardown() {
    rm -rf "$SB" 2>/dev/null
}

# Runs the hook as Claude Code does: JSON on stdin, CLAUDECODE=1 for agent control.
# Sets $status and $out.
_gate() {
    local payload
    payload=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1")
    set +e
    out=$(printf '%s' "$payload" | PROJECT_ROOT="$SB" CLAUDECODE=1 bash "$HOOK" 2>&1 >/dev/null)
    status=$?
    set -e
}

# --- the shapes that already worked must keep working ---

@test "T-2987: a bare bootstrap command is allowed" {
    _gate 'fw work-on T-016'
    [ "$status" -eq 0 ]
}

@test "T-2987: bare 'fw context focus' is allowed" {
    _gate 'fw context focus T-016'
    [ "$status" -eq 0 ]
}

@test "T-2987: bootstrap chained WITHOUT a write pattern is allowed" {
    # Chaining is not the trigger — the write pattern is. Pinned so a future fix
    # aimed at redirects does not quietly ban `&&` as collateral.
    _gate 'fw work-on T-016 && fw doctor'
    [ "$status" -eq 0 ]
}

# --- the permission boundary: unchanged ---

@test "T-2987: the redirected bootstrap command is STILL blocked" {
    # The load-bearing assertion. This is a message fix; if this ever passes with
    # exit 0 the exemption has been widened and arbitrary writes ride in on it.
    _gate 'fw work-on T-016 > /tmp/t2987.out 2>&1'
    [ "$status" -eq 2 ]
}

@test "T-2987: bootstrap chained with an unrelated redirect is still blocked" {
    _gate 'fw context focus T-016 | grep .; fw doctor > /tmp/t2987.fd'
    [ "$status" -eq 2 ]
}

# --- the fix: the block now explains the shape ---

@test "T-2987: the block names the redirect as the reason, not just the task" {
    _gate 'fw work-on T-016 > /tmp/t2987.out 2>&1'
    [ "$status" -eq 2 ]
    echo "$out" | grep -q "already contains that bootstrap command"
    echo "$out" | grep -qi "redirect"
}

@test "T-2987: the block says to run the bootstrap command bare and alone" {
    # Without this the agent has a diagnosis and no remedy, which is where the
    # original loop lived.
    _gate 'fw work-on T-016 > /tmp/t2987.out 2>&1'
    echo "$out" | grep -qi "bare and alone\|BARE and alone"
}

@test "T-2987: the hint does NOT fire for a command with no bootstrap verb" {
    # A plain blocked command must not be told to re-run a bootstrap command it
    # never contained — that would be a new wrong-remedy loop of its own.
    _gate 'echo hi > /tmp/t2987.plain'
    [ "$status" -eq 2 ]
    ! echo "$out" | grep -q "already contains that bootstrap command"
}

@test "T-2987: the hint does NOT fire for a bootstrap verb with no write pattern" {
    # Nothing to explain — that shape is allowed, so it never reaches a block.
    _gate 'fw work-on T-016'
    ! echo "$out" | grep -q "already contains that bootstrap command"
}

# --- the blank that hid the cause ---

@test "T-2987: a Bash block shows the command, not an empty 'Attempting to modify:'" {
    # FILE_PATH is populated only for Write/Edit, so every Bash block rendered
    # "Attempting to modify:" with nothing after it — hiding the one datum that
    # makes a stray redirect visible.
    _gate 'fw work-on T-016 > /tmp/t2987.out 2>&1'
    echo "$out" | grep -q "Blocked command:"
    echo "$out" | grep -q "fw work-on T-016"
    ! echo "$out" | grep -qE "Attempting to modify:[[:space:]]*$"
}

@test "T-2987: a Write block still names the file path" {
    # The other half of _blocked_subject: Write/Edit keeps its original wording.
    payload=$(python3 -c 'import json; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"/opt/x/src/thing.py"}}))')
    set +e
    out=$(printf '%s' "$payload" | PROJECT_ROOT="$SB" CLAUDECODE=1 bash "$HOOK" 2>&1 >/dev/null)
    status=$?
    set -e
    [ "$status" -eq 2 ]
    echo "$out" | grep -q "Attempting to modify: /opt/x/src/thing.py"
}

# --- every site that advertises the remedy must carry the caveat ---

@test "T-2987: no block site advertises a bootstrap command without the shape hint" {
    # The defect was six sites naming a remedy and none naming its precondition.
    # Enumerate rather than trust: count sites whose message contains a bootstrap
    # command, and require a hint call in the same block.
    #
    # Heuristic but honest — it fails loudly when a NEW block site is added that
    # advertises `work-on` and forgets the hint, which is the recurrence path.
    advertise=$(grep -cE '_fw_cmd\) (work-on|context focus|task create)' "$HOOK")
    hints=$(grep -c '_bootstrap_shape_hint "\${BASH_CMD' "$HOOK")
    [ "$hints" -ge 5 ]
    [ "$advertise" -ge "$hints" ]
}

@test "T-2987: no block site still renders the dangling FILE_PATH field" {
    run grep -n 'Attempting to modify: \$FILE_PATH' "$HOOK"
    [ "$status" -ne 0 ]
}
