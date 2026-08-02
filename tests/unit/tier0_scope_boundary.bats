#!/usr/bin/env bats
# T-2742: Tier 0 inspects the command STRING only — characterization test.
#
# This is not a test of desired behaviour. It pins the gate's actual reach so
# that the claim written in check-tier0.sh's header, CLAUDE.md §Enforcement
# Tiers and FRAMEWORK.md is falsifiable rather than folklore. If anyone later
# extends Tier 0 to inspect script contents, the ALLOWED tests below go red and
# force those three documents to change in the same commit.
#
# The boundary: check-tier0.sh reads `tool_input.command` from the PreToolUse
# JSON and matches that string. It never opens a file the command refers to.
# So `bash ./build.sh` is opaque no matter what build.sh does.
#
# Origin: 832 lost a working tree to exactly this shape — a mutated build script
# ran `rm -rf "$OUT"` with the variable pointing at their repo root (their G-018,
# high). Verified independently against our own hook source as OBS-138.
#
# Why every "allowed" assertion here is paired with a positive control: an
# `exit 0` from this harness is indistinguishable between "the gate deliberately
# does not cover this" and "the harness cannot observe a block at all". The
# control proves the bucket can fill before any test reports it empty — the
# discipline that caught weak tests in T-2738 and in 832's parallel work.
#
# HOW FAR THE FALSIFIABILITY CLAIM ACTUALLY REACHES — measured, not asserted.
# The BOUNDARY tests were driven against a hook temporarily patched to splice
# referenced file contents into the match string (simulated extended coverage):
#
#   test 3 (bash <script>)      → went RED   ✔ genuinely pins the boundary
#   test 4 (<script> direct)    → went RED   ✔ genuinely pins the boundary
#   test 5 (python3 <script>)   → stayed green — the Python body carries no
#                                 `rm -` keyword, so the bash-centric pre-filter
#                                 never fires even when the file IS read
#   test 6 (make -C <dir>)      → stayed green — no argument is a file path, so
#                                 nothing gets read in the first place
#
# So tests 3 and 4 are the ones that would force a doc update if coverage were
# extended. Tests 5 and 6 are documentary: they record today's behaviour for
# interpreters the current pattern set could not match regardless. Stated
# explicitly so nobody reads eight greens as eight guarantees.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$TEST_TEMP_DIR/.context/approvals" "$TEST_TEMP_DIR/.context/working"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-tier0.sh"
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "${TEST_TEMP_DIR:?}"
}

_run_hook() {
    local cmd="$1"
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_input':{'command': sys.argv[1]}}))" "$cmd")
    echo "$json" | bash "$HOOK"
}

# A script whose CONTENTS are unambiguously Tier 0. Never executed by these
# tests — only ever passed to the hook by name.
#
# The delete is written UNQUOTED and literal on purpose. An earlier version of
# this fixture used 832's real shape, `OUT="/"` then `rm -rf "$OUT"`, and the
# negative control below could not make a single BOUNDARY test go red with it.
# Reason: the hook's strip_quotes() blanks every quoted string before matching,
# so `rm -rf "$OUT"` reduces to `rm -rf ""` and matches nothing. With that
# fixture the tests passed whether or not the hook read the file — they pinned
# nothing. The literal form is what makes the boundary falsifiable.
#
# Worth keeping in view for anyone who later tries to close this gap: reading
# script contents into the match string would NOT have caught 832's incident
# either, for exactly that reason. Any real fix has to reason about variable
# values, not text — which is why extending coverage here is its own design
# problem and not a patch.
_make_destructive_script() {
    local path="$TEST_TEMP_DIR/build.sh"
    cat > "$path" <<'SCRIPT'
#!/bin/bash
rm -rf /
SCRIPT
    chmod +x "$path"
    printf '%s' "$path"
}

# ── Positive controls: the harness CAN observe a block ───────────────────────
# Without these, every "allowed" result below would be unfalsifiable.

@test "T-2742 CONTROL: the same rm -rf typed inline IS blocked" {
    run _run_hook 'rm -rf /'
    [ "$status" -eq 2 ]
}

@test "T-2742 CONTROL: a destructive command is blocked even with the script path present" {
    # Proves it is the STRING that matters, not the presence of a file path:
    # identical script argument, but the delete is spelled out in the command.
    local script
    script="$(_make_destructive_script)"
    run _run_hook "rm -rf $script /"
    [ "$status" -eq 2 ]
}

# ── The boundary itself ──────────────────────────────────────────────────────

@test "T-2742 BOUNDARY: invoking a script whose contents are Tier 0 is NOT blocked" {
    local script
    script="$(_make_destructive_script)"
    # Premise: the script really does contain a Tier 0 operation. Without this
    # the test could pass against an empty file and assert nothing.
    grep -q 'rm -rf' "$script"

    run _run_hook "bash $script"
    [ "$status" -eq 0 ]
}

@test "T-2742 BOUNDARY: executing the script directly is NOT blocked" {
    local script
    script="$(_make_destructive_script)"
    grep -q 'rm -rf' "$script"

    run _run_hook "$script"
    [ "$status" -eq 0 ]
}

@test "T-2742 BOUNDARY: other interpreters are equally opaque" {
    local script="$TEST_TEMP_DIR/deploy.py"
    printf '%s\n' 'import shutil; shutil.rmtree("/")' > "$script"

    run _run_hook "python3 $script"
    [ "$status" -eq 0 ]
}

@test "T-2742 BOUNDARY: make recipes are not inspected" {
    printf 'clean:\n\trm -rf /\n' > "$TEST_TEMP_DIR/Makefile"

    run _run_hook "make -C $TEST_TEMP_DIR clean"
    [ "$status" -eq 0 ]
}

# ── The documentation this test pins must actually say so ────────────────────
# Keeps the three documents and this test from drifting apart silently: if the
# boundary text is deleted, the characterization tests above would still pass
# while the claim they exist to support had vanished.

@test "T-2742: the hook header documents the boundary it is pinned to" {
    run grep -q "SCOPE BOUNDARY" "$FRAMEWORK_ROOT/agents/context/check-tier0.sh"
    [ "$status" -eq 0 ]
    run grep -q "never opens" "$FRAMEWORK_ROOT/agents/context/check-tier0.sh"
    [ "$status" -eq 0 ]
}

@test "T-2742: CLAUDE.md and FRAMEWORK.md both state the boundary" {
    run grep -q "Tier 0 sees the command string" "$FRAMEWORK_ROOT/CLAUDE.md"
    [ "$status" -eq 0 ]
    run grep -q "Tier 0 inspects the command string only" "$FRAMEWORK_ROOT/FRAMEWORK.md"
    [ "$status" -eq 0 ]
}
