#!/usr/bin/env bats
# T-2719 (arc-016) — the README's five-minute walkthrough, run as the BY-HAND
# persona: a person at a terminal with no AI agent attached.
#
# WHY A SEPARATE PERSONA. The framework's headline property is "nothing gets
# done without a task", and it is enforced by TWO different mechanisms with
# different reach:
#
#   Write/Edit/Bash gate  -> .claude/settings.json PreToolUse hook
#                            fires ONLY for an AI agent's tool calls
#   commit-msg gate       -> .git/hooks/commit-msg
#                            fires for ANYONE who runs git commit
#
# An agent-assisted walkthrough exercises both and passes. A person exercises
# only the second. So a README step that says "try to edit without a task — the
# gate refuses" is TRUE when an agent reads it and FALSE when a human does, and
# the agent-assisted test cannot see the difference. Measured 2026-08-05 against
# published bytes: `echo x > src.txt` returned RC=0 and created the file.
#
# That is the arc's whole thesis, so it gets its own scenario rather than an
# assertion bolted onto the agent path.
#
# COMMANDS ARE EXTRACTED FROM README.md, NOT RETYPED HERE. A copy of the steps
# would keep passing after the document drifts away from it — which is the same
# false-green shape the walkthrough itself had.
#
# NO NETWORK. Step 1 of the README is a curl|bash install; this suite builds the
# equivalent project state with the local `fw init` instead. Making the network
# a dependency of a routine test run turns every offline or rate-limited host
# into a red suite (the reason T-2814's bootstrap tests take FW_INSTALL_URL).
# The published-bytes path is covered separately by
# tests/unit/router_bootstraps_bare_init.bats.

bats_require_minimum_version 1.5.0

setup() {
    FW_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    README="$FW_ROOT/README.md"
    # No guard_project_root call here (T-2788): this file never assigns
    # PROJECT_ROOT, and builds every fixture path on $BATS_TEST_TMPDIR, which
    # bats guarantees. Calling the guard without `load ../test_helper` is the
    # exact 127 that T-2788 swept out of 7 other call sites.
    PROJ="$BATS_TEST_TMPDIR/my-project"
}

# The fenced bash block under the "See it work in five minutes" heading.
five_minute_block() {
    awk '/^## See it work in five minutes/{f=1} f&&/^```bash/{c=1;next} c&&/^```/{exit} c' "$README"
}

@test "the five-minute block is extractable and has the documented steps" {
    # Non-vacuity for every test below: if the heading or fence is renamed the
    # extractor returns empty, and an empty haystack silently satisfies every
    # "does not claim X" assertion in this file.
    run five_minute_block
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    echo "$output" | grep -q 'install.sh'
    echo "$output" | grep -q 'fw work-on'
    echo "$output" | grep -q 'fw audit'
}

@test "no step promises the by-hand reader a gate that cannot fire for them" {
    # The PreToolUse gate refuses an EDIT. A person's editor and shell are not
    # routed through it. A step that tells them to try editing and expect a
    # refusal documents an outcome they will never see.
    run five_minute_block
    [ "$status" -eq 0 ]

    # Find any step that pairs "edit"/"write" with a refusal claim.
    local bad
    bad=$(echo "$output" | grep -inE '^#.*(edit|write).*(gate refuses|refuses|BLOCKED)' || true)
    if [ -n "$bad" ]; then
        {
            echo "A five-minute step promises an edit-time refusal:"
            echo "    $bad"
            echo ""
            echo "The edit-time gate is a Claude Code PreToolUse hook. A person"
            echo "following this walkthrough at a terminal is not routed through"
            echo "it, so the step reads as a lie to the persona it is written for."
            echo "Use the commit-msg gate instead — it is git-level and fires for"
            echo "everyone — or name the persona the claim applies to."
        } >&2
        return 1
    fi
}

@test "the by-hand persona: a plain shell edit is NOT refused" {
    # Pins reality rather than the wish. If this ever starts failing, the
    # framework has grown a gate that reaches a human's shell, and the README
    # may then legitimately claim an edit-time refusal — at which point the
    # previous test's rule should be revisited, not silenced.
    mkdir -p "$PROJ"   # fw init requires the target to exist (OBS-171)
    "$FW_ROOT/bin/fw" init "$PROJ" >/dev/null 2>&1
    # No `|| skip` here: a skip renders as ok in TAP, so an environment problem
    # would read identically to a passing assertion. If init cannot run, this
    # file must go RED and say so.
    [ -d "$PROJ/.tasks" ] || fail "fw init did not produce a project at $PROJ"
    run bash -c "cd '$PROJ' && echo 'some change' > src.txt"
    [ "$status" -eq 0 ]
    [ -f "$PROJ/src.txt" ]
}

@test "the by-hand persona: the commit gate DOES refuse, and names a live remedy" {
    mkdir -p "$PROJ"   # fw init requires the target to exist (OBS-171)
    "$FW_ROOT/bin/fw" init "$PROJ" >/dev/null 2>&1
    # No `|| skip` here: a skip renders as ok in TAP, so an environment problem
    # would read identically to a passing assertion. If init cannot run, this
    # file must go RED and say so.
    [ -d "$PROJ/.tasks" ] || fail "fw init did not produce a project at $PROJ"
    cd "$PROJ" || return 1
    git init -q . 2>/dev/null || true
    git config user.email t@example.com
    git config user.name "Test Operator"
    cp "$FW_ROOT/.git/hooks/commit-msg" .git/hooks/commit-msg 2>/dev/null || \
        skip "no commit-msg hook available to install"
    chmod +x .git/hooks/commit-msg

    echo change > f.txt
    git add -A >/dev/null 2>&1
    run git commit -m "no task reference here"
    [ "$status" -eq 1 ]
    [[ "$output" == *"No task reference found"* ]]

    # T-2816: the remedy must resolve HERE, not in the framework repo.
    [[ "$output" != *"./agents/task-create/create-task.sh"* ]] || \
        fail "refusal names a framework-repo-only path: $output"
}
