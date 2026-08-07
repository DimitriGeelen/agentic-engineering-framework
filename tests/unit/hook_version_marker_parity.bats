#!/usr/bin/env bats
# T-2852 — install-hooks must compare the installed commit-msg hook's
# `# VERSION=` marker against the TEMPLATE's version, not against the git
# agent's own version.
#
# Those were different variables holding different quantities (template 1.11,
# agent 1.6). The equality could never hold, so the "Hooks already installed"
# short-circuit was unreachable and every install-hooks call rewrote all four
# hooks while announcing a downgrade that nothing had actually computed.
#
# agents/git/git.sh already carried a comment telling the reader to keep the two
# in sync. It was correct, and it drifted anyway. Hence a test.

setup_file() {
    FW_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FW_ROOT
    HOOKS_LIB="$FW_ROOT/agents/git/lib/hooks.sh"
    export HOOKS_LIB
}

setup() {
    FX="$(mktemp -d)"
    # Its own repo — the enclosing dir may itself be inside one (on this host
    # /tmp has been, T-2850).
    git -C "$FX" init -q
    git -C "$FX" config user.email "t2852@localhost"
    git -C "$FX" config user.name "T-2852 fixture"

    # install-hooks resolves the hooks directory from PROJECT_ROOT, NOT from cwd
    # (agents/git/lib/common.sh:29-36). The first draft of this suite only cd'd
    # into the fixture, so every run targeted the FRAMEWORK repo's own hooks —
    # it read /opt/999-…/.git/hooks/commit-msg, reported "already installed",
    # and the negative control was one existing file away from sed-ing the live
    # repo's commit-msg hook. Green about the wrong object, destructively
    # (T-2718/T-2725 family).
    export PROJECT_ROOT="$FX"
}

teardown() {
    [ -n "${FX:-}" ] && [ -d "$FX" ] && rm -rf "$FX"
    return 0
}

# The version literal actually baked into the commit-msg heredoc.
_template_marker() {
    local start
    start="$(grep -n 'cat > "\$commit_msg_hook"' "$HOOKS_LIB" | head -1 | cut -d: -f1)"
    [ -n "$start" ] || return 1
    tail -n +"$start" "$HOOKS_LIB" | grep -m1 '^# VERSION=' | cut -d= -f2
}

@test "the commit-msg template carries a version marker at all" {
    # Anti-vacuity anchor: every parity assertion below compares two strings.
    # If the extractor silently returned empty, "" = "" would pass and the
    # suite would be green about nothing.
    run _template_marker
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" =~ ^[0-9]+\.[0-9]+$ ]]
}

@test "COMMIT_MSG_HOOK_VERSION equals the template's own marker" {
    local declared marker
    declared="$(grep -m1 '^COMMIT_MSG_HOOK_VERSION=' "$HOOKS_LIB" | cut -d'"' -f2)"
    marker="$(_template_marker)"
    [ -n "$declared" ]
    [ "$declared" = "$marker" ]
}

@test "the comparison does NOT use the git agent's \$VERSION" {
    # The specific regression: hooks.sh comparing against git.sh's VERSION.
    run grep -n 'existing_version" = "\$VERSION"' "$HOOKS_LIB"
    [ "$status" -ne 0 ]
}

@test "the fixture is isolated — hooks land in it, not in the framework repo" {
    # Anti-vacuity anchor for the two tests below. If PROJECT_ROOT were ignored,
    # they would silently measure the framework's own hooks and pass for reasons
    # unrelated to the fix.
    local before after
    before="$(md5sum "$FW_ROOT/.git/hooks/commit-msg" 2>/dev/null | cut -d' ' -f1)"
    run bash "$FW_ROOT/agents/git/git.sh" install-hooks
    [ "$status" -eq 0 ]
    [ -f "$FX/.git/hooks/commit-msg" ]
    after="$(md5sum "$FW_ROOT/.git/hooks/commit-msg" 2>/dev/null | cut -d' ' -f1)"
    [ "$before" = "$after" ]
}

@test "install-hooks short-circuits on the second run (fast path is REACHABLE)" {
    # The load-bearing test. This is what was broken: the branch existed and
    # could never be taken.
    run bash "$FW_ROOT/agents/git/git.sh" install-hooks
    [ "$status" -eq 0 ]
    [ -f "$FX/.git/hooks/commit-msg" ]

    run bash "$FW_ROOT/agents/git/git.sh" install-hooks
    [ "$status" -eq 0 ]
    [[ "$output" == *"already installed"* ]]
}

@test "NEGATIVE CONTROL: a mismatched installed marker does NOT short-circuit" {
    # Without this, hard-coding the fast path to always fire would satisfy the
    # test above while disabling the staleness detection PL-078 depends on.
    run bash "$FW_ROOT/agents/git/git.sh" install-hooks
    [ "$status" -eq 0 ]

    # Age the installed hook's marker.
    sed -i 's/^# VERSION=.*/# VERSION=0.1/' "$FX/.git/hooks/commit-msg"

    run bash "$FW_ROOT/agents/git/git.sh" install-hooks
    [ "$status" -eq 0 ]
    [[ "$output" != *"already installed"* ]]
    [[ "$output" == *"differs"* ]]

    # And it must have actually rewritten the hook, not merely said so.
    run grep -c '^# VERSION=0.1' "$FX/.git/hooks/commit-msg"
    [ "$output" = "0" ]
}

@test "the reinstall message does not claim a direction it never computed" {
    # 'Updating hooks from version 1.11 to 1.6' reads as a downgrade. Nothing in
    # this file compares ordering, so that wording asserted more than the code knew.
    run grep -q 'Updating hooks from version' "$HOOKS_LIB"
    [ "$status" -ne 0 ]
}
