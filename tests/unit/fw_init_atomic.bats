#!/usr/bin/env bats
# T-2801 — fw init must leave either nothing or a working project.
#
# do_vendor's include list copies `bin` FIRST, and .framework.yaml is not written
# until ~120 lines after the vendor call. So from roughly one second into an init
# until it finishes, the target directory holds an executable
# .agentic-framework/bin/fw belonging to a framework that is not all there yet.
#
# T-2805 update: FRAMEWORK.md used to be copied eighth of twelve, inside that
# window. It is now written LAST, after every other vendor write, and the router
# tests for it — so the window is closed by an observed signal as well as by the
# declared marker this file was written for. See tests/unit/fw_vendor_completeness.bats.
#
# bin/fw-router routed on `[ -x <dir>/.agentic-framework/bin/fw ]` alone, so it
# exec'd that partial CLI, which failed "Cannot find framework installation" —
# for every verb, INCLUDING fw init. The tool could not repair the directory it
# had just created; only `rm -rf` did. Hit live 2026-08-04 in
# /opt/2345-test-install via the T-2798 --help auto-init bug (OBS-157).
#
# The fix is a marker at the project root, written before the first mutation and
# removed after the last. Tests 2 and 5 are the non-vacuity pair: without them,
# a router that refuses everything and an init that writes no marker would both
# look green.

bats_require_minimum_version 1.5.0

ROUTER() { echo "$BATS_TEST_DIRNAME/../../bin/fw-router"; }
FW()     { echo "$BATS_TEST_DIRNAME/../../bin/fw"; }
FWROOT() { (cd "$BATS_TEST_DIRNAME/../.." && pwd); }

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    # A fake vendored consumer: executable bin/fw, nothing else. This is what a
    # partial vendor looks like to the router.
    mkdir -p "$TEST_TEMP_DIR/proj/.agentic-framework/bin"
    cat > "$TEST_TEMP_DIR/proj/.agentic-framework/bin/fw" <<'STUB'
#!/bin/bash
echo "ROUTED-TO-VENDOR"
STUB
    chmod +x "$TEST_TEMP_DIR/proj/.agentic-framework/bin/fw"

    # A fake global install for the bootstrap fallback.
    mkdir -p "$TEST_TEMP_DIR/global/bin"
    cat > "$TEST_TEMP_DIR/global/bin/fw" <<'STUB'
#!/bin/bash
echo "ROUTED-TO-GLOBAL"
STUB
    chmod +x "$TEST_TEMP_DIR/global/bin/fw"
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

@test "router refuses to route into a vendor marked incomplete" {
    touch "$TEST_TEMP_DIR/proj/.fw-init-incomplete"
    cd "$TEST_TEMP_DIR/proj"
    run env FW_GLOBAL_ROOT="$TEST_TEMP_DIR/global" "$(ROUTER)"
    [ "$status" -eq 0 ]
    # The partial CLI must NOT have run.
    ! echo "$output" | grep -q 'ROUTED-TO-VENDOR'
    echo "$output" | grep -q 'ROUTED-TO-GLOBAL'
    # And the state must be named, not silently worked around. (T-2805 reworded
    # this from "unfinished init" — the same state arises from debris with no
    # init behind it at all, which the old phrasing misdescribed.)
    echo "$output" | grep -q 'incomplete framework copy'
}

@test "without the marker the router still routes into the vendor" {
    # Non-vacuity for the test above: proves the refusal is caused by the marker
    # and not by the stub being unroutable for some unrelated reason.
    #
    # T-2805 made that caveat load-bearing. The router now ALSO refuses a vendor
    # with no FRAMEWORK.md, so without the touch below this test would pass for
    # the wrong reason — the stub really would be unroutable for an unrelated
    # reason, which is precisely what it exists to rule out. Adding the sentinel
    # isolates the marker as the single variable again.
    touch "$TEST_TEMP_DIR/proj/.agentic-framework/FRAMEWORK.md"
    cd "$TEST_TEMP_DIR/proj"
    run env FW_GLOBAL_ROOT="$TEST_TEMP_DIR/global" "$(ROUTER)"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'ROUTED-TO-VENDOR'
    ! echo "$output" | grep -q 'ROUTED-TO-GLOBAL'
}

@test "incomplete vendor with no global refuses with a recovery path, not 'no framework found'" {
    touch "$TEST_TEMP_DIR/proj/.fw-init-incomplete"
    cd "$TEST_TEMP_DIR/proj"
    # 127 is the router's "no framework found" code; `run -127` asserts it and
    # keeps bats from reading it as a missing-binary accident (BW01).
    run -127 env FW_GLOBAL_ROOT="$TEST_TEMP_DIR/does-not-exist" "$(ROUTER)"
    echo "$output" | grep -q 'is incomplete'
    # The generic message would send the user off to install something they
    # already have, hiding that the fix is to finish an init that started.
    ! echo "$output" | grep -q 'no framework found'
    # A runnable way out, both directions.
    echo "$output" | grep -q 'install.sh'
    echo "$output" | grep -q 'rm -rf'
}

@test "an interrupted init is recoverable by re-running fw init" {
    # The end-to-end claim. Kill a real init mid-vendor, then let a second run
    # finish the job — the sequence that was impossible before this task.
    local proj="$TEST_TEMP_DIR/live"
    mkdir -p "$proj"

    cd "$proj"
    timeout -s KILL 1.2 "$(FW)" init "$proj" --provider claude --no-first-run >/dev/null 2>&1 || true

    # Only meaningful if the kill actually landed mid-init. On a much faster host
    # init may complete inside the window; skipping beats asserting on a state we
    # did not manage to produce.
    [ -f "$proj/.fw-init-incomplete" ] || skip "init completed within the kill window — no partial state to recover"
    [ ! -f "$proj/.framework.yaml" ]

    # This is the debris shape: routable-looking vendor, no project config.
    [ -x "$proj/.agentic-framework/bin/fw" ]

    run "$(FW)" init "$proj" --provider claude --no-first-run
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'RECOVER'

    # Recovered, not merely un-marked.
    [ ! -f "$proj/.fw-init-incomplete" ]
    [ -f "$proj/.framework.yaml" ]
    [ -f "$proj/.agentic-framework/FRAMEWORK.md" ]
}

@test "a clean init leaves no marker behind" {
    # Non-vacuity for the marker: if init never removed it, every project would
    # permanently route to the global install and test 1 would pass for the
    # wrong reason.
    local proj="$TEST_TEMP_DIR/clean"
    mkdir -p "$proj"
    cd "$proj"
    run "$(FW)" init "$proj" --provider claude --no-first-run
    [ "$status" -eq 0 ]
    [ ! -f "$proj/.fw-init-incomplete" ]
    [ -f "$proj/.framework.yaml" ]
}
