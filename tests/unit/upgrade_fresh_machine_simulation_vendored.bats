#!/usr/bin/env bats
# T-1635 / T-2793 / T-3671: fresh-machine simulation, fw-init-vendored consumers.
#
# Split from upgrade_fresh_machine_simulation.bats (T-3747): each test here builds
# a consumer with a real `fw init` (~60s), and together they pushed the single
# file past the unit runner's 900s per-file cap under full-suite load. Same
# scrubbed-env guard, same §Consumer-Facing Command Hygiene obligation: keep green.

load ../test_helper
load ../fresh_machine_helper

# ─────────────────────────────────────────────────────────────────────────────
# T-2793 — total isolation: the version a consumer reports, and whether it works
# at all without a global install.
#
# These use `fw init` (the real do_vendor path a consumer is actually built by)
# rather than make_fresh_consumer's git clone, because the two produce different
# artefacts: a clone carries .git, so _derive_version answers from git describe;
# a vendored copy has none, so VERSION is the only statement of which framework
# is running — which is exactly what T-2793 makes load-bearing.
# ─────────────────────────────────────────────────────────────────────────────

@test "T-2793: vendored consumer agrees with itself about its version" {
    local proj="$TEST_TEMP_DIR/vproj"
    make_vendored_consumer "$proj"
    [ -x "$proj/.agentic-framework/bin/fw" ]

    local reported pinned vfile
    reported="$(fresh_run "$proj" --version | head -1 | sed 's/^fw v//')"
    pinned="$(grep -m1 '^version:' "$proj/.framework.yaml" | awk '{print $2}')"
    vfile="$(tr -d '\n' < "$proj/.agentic-framework/VERSION")"

    # Non-empty first: three empty strings compare equal, and an equality test
    # that passes on nothing is the vacuous-pass class this suite exists to catch.
    [ -n "$reported" ]; [ -n "$pinned" ]; [ -n "$vfile" ]
    [[ "$reported" =~ ^[0-9]+\.[0-9]+\. ]]

    # The split brain printed two true lines that disagreed. Three sources, one
    # answer, or the consumer cannot say what it is running.
    [ "$reported" = "$pinned" ] || { echo "fw --version=$reported .framework.yaml=$pinned"; false; }
    [ "$reported" = "$vfile" ]  || { echo "fw --version=$reported VERSION=$vfile";  false; }
}

@test "T-2793: the router reaches the consumer's own CLI with no global install" {
    local proj="$TEST_TEMP_DIR/vproj2"
    make_vendored_consumer "$proj"
    mkdir -p "$TEST_TEMP_DIR/home2/.local/bin"
    cp "$FRAMEWORK_ROOT/bin/fw-router" "$TEST_TEMP_DIR/home2/.local/bin/fw"
    chmod +x "$TEST_TEMP_DIR/home2/.local/bin/fw"
    # HOME has NO .agentic-framework — `rm -rf ~/.agentic-framework` is what
    # fw doctor already recommends, and it must not break any vendored project.
    [ ! -d "$TEST_TEMP_DIR/home2/.agentic-framework" ]

    # Deep subdirectory, so the walk-up is doing real work.
    mkdir -p "$proj/src/nested"
    run bash -c "cd '$proj/src/nested' && env -i \
        PATH='$TEST_TEMP_DIR/home2/.local/bin:/usr/local/bin:/usr/bin:/bin' \
        HOME='$TEST_TEMP_DIR/home2' fw --version"
    [ "$status" -eq 0 ]
    local vfile
    vfile="$(tr -d '\n' < "$proj/.agentic-framework/VERSION")"
    [[ "$output" == *"$vfile"* ]] || { echo "expected $vfile, got: $output"; false; }
    # And it must be THIS project's framework, not something found elsewhere.
    [[ "$output" == *"$proj/.agentic-framework"* ]]
}

@test "T-2793: the router ignores a STALE global install when the project has its own" {
    # Dual to the "absent" case above: here $HOME/.agentic-framework EXISTS
    # but is a different (older/mismatched) version. The walk-up finds the
    # project's own vendored copy first and must never fall through to the
    # global one, stale or not.
    local proj="$TEST_TEMP_DIR/vproj3"
    make_vendored_consumer "$proj"
    mkdir -p "$TEST_TEMP_DIR/home3/.local/bin"
    cp "$FRAMEWORK_ROOT/bin/fw-router" "$TEST_TEMP_DIR/home3/.local/bin/fw"
    chmod +x "$TEST_TEMP_DIR/home3/.local/bin/fw"

    # A stale global install: same shape as a vendored project, deliberately
    # stamped with a VERSION that cannot collide with the real one.
    mkdir -p "$TEST_TEMP_DIR/home3/.agentic-framework/bin"
    cp "$FRAMEWORK_ROOT/bin/fw-router" "$TEST_TEMP_DIR/home3/.agentic-framework/bin/fw-router"
    printf '0.0.1-stale\n' > "$TEST_TEMP_DIR/home3/.agentic-framework/VERSION"
    cat > "$TEST_TEMP_DIR/home3/.agentic-framework/bin/fw" <<'SCRIPT'
#!/bin/bash
echo "fw v0.0.1-stale (WRONG — this is the stale global install, not the project's)"
exit 0
SCRIPT
    chmod +x "$TEST_TEMP_DIR/home3/.agentic-framework/bin/fw"

    mkdir -p "$proj/src/nested"
    run bash -c "cd '$proj/src/nested' && env -i \
        PATH='$TEST_TEMP_DIR/home3/.local/bin:/usr/local/bin:/usr/bin:/bin' \
        HOME='$TEST_TEMP_DIR/home3' fw --version"
    [ "$status" -eq 0 ]
    local vfile
    vfile="$(tr -d '\n' < "$proj/.agentic-framework/VERSION")"
    [[ "$output" == *"$vfile"* ]] || { echo "expected $vfile, got: $output"; false; }
    [[ "$output" != *"stale"* ]] || { echo "router fell through to the stale global install: $output"; false; }
    [[ "$output" == *"$proj/.agentic-framework"* ]]
}

@test "T-3671: vendored consumer's sidecar whoami names the project, never .agentic-framework" {
    local proj="$TEST_TEMP_DIR/vproj-sidecar"
    make_vendored_consumer "$proj"
    local out
    # FW_SIDECAR_HUB_ID stands in for `termlink hub fingerprint` so this runs offline.
    out="$(cd "$proj" && env -i PATH="/usr/local/bin:/usr/bin:/bin" HOME="$TEST_TEMP_DIR/home" \
        FW_SIDECAR_HUB_ID=testhub "$proj/.agentic-framework/bin/fw" sidecar whoami 2>&1)" || { echo "$out"; false; }
    echo "$out" | grep -q "inbox:testhub/vproj-sidecar" || { echo "$out"; false; }
    if echo "$out" | grep -q "\.agentic-framework"; then echo "$out"; false; fi
    [ ! -d "$proj/.agentic-framework/.context/sidecar" ]
}
