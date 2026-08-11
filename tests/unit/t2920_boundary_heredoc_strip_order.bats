#!/usr/bin/env bats
# T-2920 — the project-boundary hook must not read a heredoc BODY as a command.
#
# Found live: a rail message to 832 was refused as "a command targeting another
# project" because the message TEXT contained `cd <path>` as prose describing
# our own Copy-Pasteable Commands rule, inside a `<<'EOF'` heredoc.
#
# The hook already carried both defences — _strip_quoted (T-1361) and
# _strip_heredocs (T-1702) — but in an order where the first voids the second:
# _strip_quoted blanks the quoted marker in `<<'EOF'`, leaving `<<'   '`, and
# _strip_heredocs matches `(\w+)`, which cannot match spaces. So the QUOTED
# heredoc form's body was never stripped.
#
# The both-forms axis below is the load-bearing part. T-1702's own examples use
# the BARE form, so its tests could not have caught this — and L-294 *mandates*
# the quoted form, because the bare form command-substitutes $(...). Following
# our own learning was what triggered the false block.
#
# Every leg drives the real hook end-to-end. Both directions in one suite: a
# "fix" that simply stops blocking passes the first four legs and fails the
# last four, so it cannot ship.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
}

# Drive the hook with <command>. Returns 0 = allowed, 2 = blocked.
hook() {
    local json
    json=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1")
    output=$(printf '%s' "$json" | bash "$HOOK" 2>&1)
    return $?
}

assert_allowed() {
    if hook "$1"; then return 0; fi
    echo "expected ALLOWED, got blocked:" >&2
    echo "$output" >&2
    return 1
}

assert_blocked() {
    if hook "$1"; then
        echo "expected BLOCKED, got allowed: $1" >&2
        return 1
    fi
    return 0
}

# ── The false blocks (the defect) ─────────────────────────────────────────────

@test "t2920: QUOTED heredoc body mentioning cd to another path is allowed" {
    # The origin case, near-verbatim. This is the leg that was red.
    assert_allowed "$(printf 'cat > /tmp/msg.md <<'"'"'EOF'"'"'\nOur rule mandates cd /opt/other-project && bin/fw handover\nEOF\n')"
}

@test "t2920: BARE heredoc body mentioning cd to another path is allowed" {
    # T-1702 already covered this form; it must stay covered after the reorder.
    assert_allowed "$(printf 'cat > /tmp/msg.md <<EOF\nOur rule mandates cd /opt/other-project && bin/fw handover\nEOF\n')"
}

@test "t2920: a heredoc body naming another project's path is allowed" {
    assert_allowed "$(printf 'cat > /tmp/msg.md <<'"'"'EOF'"'"'\nWe never read /opt/832-Workflow-designer directly.\nEOF\n')"
}

@test "t2920: quoted prose mentioning cd to another path is allowed" {
    # T-1361's case — must survive the reorder.
    assert_allowed "echo 'see cd /opt/other-project in the docs'"
}

# ── The real blocks (the gate's actual job) ───────────────────────────────────
# T-559 is a hard boundary: 832's working tree must never be reachable from this
# session. If any of these four flip to allowed, the fix is worthless.

@test "t2920: a REAL cd to another project still blocks" {
    assert_blocked "cd /opt/832-Workflow-designer && rm -rf build"
}

@test "t2920: a REAL read of another framework root still blocks (T-1702/G-065)" {
    assert_blocked "du -sh /root/.agentic-framework"
}

@test "t2920: a real cd AFTER a heredoc still blocks" {
    # The stripper must remove the heredoc body and nothing else — a real
    # command following the terminator is still command text.
    assert_blocked "$(printf 'cat > /tmp/msg.md <<'"'"'EOF'"'"'\nharmless prose\nEOF\ncd /opt/832-Workflow-designer\n')"
}

@test "t2920: a real write outside the project still blocks" {
    assert_blocked "echo x > /opt/other-project/file.txt"
}

# ── Ordering pinned explicitly ────────────────────────────────────────────────

@test "t2920: heredoc stripping precedes quote stripping in the hook source" {
    # The behavioural legs above are the real guard; this one names the cause so
    # a future edit that reorders them fails with the reason attached rather
    # than as four mysterious red legs.
    hpos=$(grep -n '^command = _strip_heredocs(command)' "$HOOK" | cut -d: -f1)
    qpos=$(grep -n '^command = _strip_quoted(command)' "$HOOK" | cut -d: -f1)
    [ -n "$hpos" ]
    [ -n "$qpos" ]
    [ "$hpos" -lt "$qpos" ]
}
