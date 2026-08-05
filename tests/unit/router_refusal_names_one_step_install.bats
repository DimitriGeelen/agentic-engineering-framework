#!/usr/bin/env bats
# T-2810 — the router's refusals must name a command that still exists.
#
# Since T-2800/T-2809 (D-377 total isolation) install.sh puts framework bytes in
# the TARGET PROJECT and never in $HOME. Two of the router's three refusals still
# told the operator to run the bare installer and then `fw init` — two steps that
# no longer connect, because step one now installs no framework for step two to
# vendor. On a fresh machine that advice is a dead end: `fw init` in a bare
# directory is exactly the command that just failed.
#
# Hit live 2026-08-05: STEP 2 of the operator's onboarding prompt (bare installer)
# followed by STEP 3 (`fw init` in a new directory) → "fw: no framework found",
# exit 127, and a message pointing back at the same two steps.
#
# The third refusal (routing loop) is correctly BARE — it re-syncs the PATH router
# itself, with no project in scope. Test 5 pins that distinction so a future sweep
# doesn't "fix" it into taking a target directory it has no business having.

bats_require_minimum_version 1.5.0

setup() {
    ROUTER="$BATS_TEST_DIRNAME/../../bin/fw-router"
    FAKE_HOME="$BATS_TEST_TMPDIR/home"      # no .agentic-framework => no global
    mkdir -p "$FAKE_HOME"
    BARE="$BATS_TEST_TMPDIR/bare"
    mkdir -p "$BARE"
}

# Run the router with no global install reachable. FW_GLOBAL_ROOT is the router's
# own override (bin/fw-router:99), so this does not depend on $HOME semantics.
run_router_in() {
    # -127 is asserted here rather than tolerated: it is the router's documented
    # "no framework found" code, and it also silences bats' BW01 warning.
    run -127 env HOME="$FAKE_HOME" FW_GLOBAL_ROOT="$FAKE_HOME/.agentic-framework" \
        bash -c "cd '$1' && '$ROUTER' init"
}

@test "no-framework refusal names the one-step installer with this directory" {
    run_router_in "$BARE"
    [[ "$output" == *"bash -s --"* ]] || fail "refusal does not name the one-step form: $output"
    [[ "$output" == *"$BARE"* ]] || fail "refusal does not name the target directory: $output"
}

@test "no-framework refusal keeps exit code 127" {
    # bin/fw-router:43 documents 127 as "no framework found". A message fix must
    # not change routing semantics — 126 means something else entirely.
    run_router_in "$BARE"
    [ "$status" -eq 127 ]
}

@test "incomplete-copy refusal names the one-step installer with the project dir" {
    # Fixture matches bin/fw-router:96 — an executable vendored bin/fw with no
    # FRAMEWORK.md is the interrupted-init state.
    local proj="$BATS_TEST_TMPDIR/partial"
    mkdir -p "$proj/.agentic-framework/bin"
    printf '#!/bin/sh\n' > "$proj/.agentic-framework/bin/fw"
    chmod +x "$proj/.agentic-framework/bin/fw"

    run_router_in "$proj"
    [ "$status" -eq 127 ]
    [[ "$output" == *"bash -s --"* ]] || fail "incomplete-copy refusal does not name the one-step form: $output"
    [[ "$output" == *"$proj"* ]] || fail "incomplete-copy refusal does not name the project dir: $output"
}

@test "no refusal pairs a bare installer run with a following fw init" {
    # Whole-file grep, not a re-read of the two sites this task changed: the third
    # occurrence (routing loop) was found only because the check was file-wide.
    # The dead pattern is a bare `| bash` line with `fw init` as a separate step.
    run grep -nE '\| bash"? \\$' "$ROUTER"
    if [ "$status" -eq 0 ]; then
        # A bare `| bash` is allowed ONLY where no `fw init` follow-up is suggested.
        run grep -cE "then: *cd .* && fw init|run 'fw init' here" "$ROUTER"
        [ "$output" -eq 0 ] || fail "a refusal still chains bare-install + separate fw init"
    fi
}

@test "the routing-loop refusal keeps its bare installer line" {
    # Non-vacuity for the test above: deleting every `| bash` line would satisfy
    # it while destroying the one message that is correctly bare. The routing-loop
    # case refreshes the PATH router only — there is no project to target.
    run grep -A 4 'routing loop' "$ROUTER"
    [ "$status" -eq 0 ]
    [[ "$output" != *"bash -s --"* ]] || fail "routing-loop fix must not take a target dir"
}
