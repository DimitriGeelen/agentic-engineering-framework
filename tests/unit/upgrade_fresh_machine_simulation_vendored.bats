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

# ─────────────────────────────────────────────────────────────────────────────
# T-3689 — the full sidecar from INSIDE a vendored consumer (832 T-980: every
# vendored consumer was deaf, and nothing had ever been run from inside one).
# Hooks, cron seed, the live process (supervisor + watcher tick + receiver)
# and the e2e verb, all through the consumer's own .agentic-framework copy.
# The live e2e itself needs a hub and a dispatched worker, so here it must
# refuse at preflight with a named reason — never a traceback from a module
# the vendored copy lacks.
# ─────────────────────────────────────────────────────────────────────────────

# Sidecar processes outlive the test's rm -rf; stop them first, then sweep.
teardown() {
    if [ -n "${T3689_PROJ:-}" ] && [ -x "$T3689_PROJ/.agentic-framework/bin/fw" ]; then
        (cd "$T3689_PROJ" && env -i PATH="/usr/bin:/bin" HOME="$TEST_TEMP_DIR/home" \
            "$T3689_PROJ/.agentic-framework/bin/fw" sidecar stop >/dev/null 2>&1) || true
    fi
    [ -n "${TEST_TEMP_DIR:-}" ] && pkill -f "$TEST_TEMP_DIR/" 2>/dev/null || true
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_t3689_run() {  # no termlink on PATH, scratch HOME (host sidecar registry untouched)
    (cd "$T3689_PROJ" && env -i PATH="/usr/bin:/bin" HOME="$TEST_TEMP_DIR/home" \
        CLAUDE_PROJECT_DIR="$T3689_PROJ" "$@")
}

_t3689_alive_vendored() {  # <pidfile> — pid alive AND running the consumer's vendored code
    local pid; pid="$(tr -dc 0-9 2>/dev/null < "$1")"
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null \
        && tr '\0' ' ' < "/proc/$pid/cmdline" | grep -q "$T3689_PROJ/.agentic-framework/lib/sidecar/"
}

@test "T-3689: vendored consumer gets the full sidecar — hooks, cron, process, tick, e2e verb" {
    if PATH="/usr/bin:/bin" command -v termlink >/dev/null 2>&1; then
        skip "termlink in /usr/bin or /bin — cannot hide it to pin the e2e preflight refusal"
    fi
    T3689_PROJ="$TEST_TEMP_DIR/vproj-full-sidecar"
    make_vendored_consumer "$T3689_PROJ"
    local settings="$T3689_PROJ/.claude/settings.json" h
    local launcher='${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw'

    # 1. hooks: every sidecar hook wired through the consumer's own launcher.
    for h in sidecar-autostart sidecar-inbox sidecar-receiver-adapter sidecar-receiver-ready; do
        grep -qF "\"$launcher hook $h\"" "$settings" || { echo "missing hook $h"; cat "$settings"; false; }
    done
    [ "$(grep -cF "$launcher hook sidecar-autostart" "$settings")" -eq 2 ]  # startup + resume

    # 2. cron: the sweep job is seeded into the consumer's registry.
    grep -q "^- id: sidecar-sweep-5m" "$T3689_PROJ/.context/cron-registry.yaml"

    # 3. every hook executes from inside the consumer without error.
    for h in sidecar-inbox sidecar-receiver-adapter sidecar-receiver-ready sidecar-autostart; do
        run _t3689_run "$T3689_PROJ/.agentic-framework/bin/fw" hook "$h" <<< '{}'
        [ "$status" -eq 0 ] || { echo "hook $h rc=$status: $output"; false; }
        [[ "$output" != *Traceback* ]] || { echo "hook $h: $output"; false; }
    done

    # 4. process + tick: autostart brought up supervisor, watcher and receiver,
    #    all running the consumer's vendored code, state under the project's .context.
    local sd="$T3689_PROJ/.context/sidecar" i
    for i in $(seq 1 120); do  # up to 60 s: autostart is detached, and slow under suite load
        _t3689_alive_vendored "$sd/watcher/watcher.pid" && _t3689_alive_vendored "$sd/receiver.pid" && break
        sleep 0.5
    done
    _t3689_alive_vendored "$sd/watcher/supervisor.pid" || { ls -la "$sd" "$sd/watcher"; cat "$sd/watcher/"*.log 2>/dev/null; false; }
    _t3689_alive_vendored "$sd/watcher/watcher.pid"    || { cat "$sd/watcher/"*.log 2>/dev/null; false; }
    _t3689_alive_vendored "$sd/receiver.pid"           || { ls -la "$sd"; false; }
    tr '\0' ' ' < "/proc/$(tr -dc 0-9 < "$sd/watcher/watcher.pid")/cmdline" | grep -q -- "--tick"
    [ ! -d "$T3689_PROJ/.agentic-framework/.context/sidecar" ]

    # 5. e2e verb: reaches the vendored CLI, refuses at preflight with a reason.
    run _t3689_run "$T3689_PROJ/.agentic-framework/bin/fw" sidecar e2e --task T-001
    [ "$status" -eq 2 ] || { echo "e2e rc=$status: $output"; false; }
    [[ "$output" == *"e2e: preflight refused — termlink binary not on PATH"* ]] || { echo "$output"; false; }
    [[ "$output" != *Traceback* ]] || { echo "$output"; false; }
}
