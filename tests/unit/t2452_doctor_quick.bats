#!/usr/bin/env bats
# T-2452 / F6 (T-2441 dogfood) — `fw doctor --quick` project-only fast mode.
#
# `fw doctor` runs the full host+project+network check set every invocation
# (~150s — measured live during T-2452). The onboarding fix-and-rerun loop
# compounds it (3 calls timed out a 120s budget). `--quick` skips the slow
# host/network probes (mirror divergence ls-remote, litellm/ollama/watchtower
# curls) for a project-only scan. Live A/B during T-2452: quick=44s vs full=150s
# (3.4×), full mode unchanged (zero SKIP-leak).
#
# Most pins are source-level (cheap, deterministic) per the F7/T-2451 lesson:
# `fw doctor` is slow and network-coupled, so running it in unit tests is an
# anti-pattern. One behavioural pin exercises `--quick` (the fast path).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    FW_BIN="$FRAMEWORK_ROOT/bin/fw"
    [ -x "$FW_BIN" ]
}

@test "F6: do_doctor parses --quick into quick_mode" {
    run grep -E "\-\-quick\) quick_mode=1" "$FW_BIN"
    [ "$status" -eq 0 ]
}

@test "F6: _doctor_quick_skip helper is defined" {
    run grep -q "_doctor_quick_skip()" "$FW_BIN"
    [ "$status" -eq 0 ]
}

@test "F6: at least 3 host/network probe blocks are guarded by _doctor_quick_skip" {
    # Mirror divergence, litellm/ollama curls, Watchtower smoke test. Tightening
    # (guarding more) is fine; dropping below 3 means a probe lost its guard.
    n=$(grep -cE "if _doctor_quick_skip " "$FW_BIN")
    [ "$n" -ge 3 ]
}

@test "F6: --help documents the --quick flag" {
    run bash -c "$FW_BIN doctor --help 2>&1"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q -- "--quick"
    echo "$output" | grep -qi "skip the slow host/network probes"
}

@test "F6: --quick skips host/network probes and still renders the project verdict" {
    # Single --quick run (~44s, the fast path). Full `fw doctor` (~150s) is NOT
    # run here — that would re-introduce the slow/network-coupled anti-pattern.
    run bash -c "$FW_BIN doctor --quick 2>&1"
    [ "$status" -ne 2 ]
    # banner announces quick mode
    echo "$output" | grep -q "project-only mode"
    # SKIP markers prove the network probes were skipped
    echo "$output" | grep -q "Mirror divergence.*--quick"
    # the F7 project-health verdict still renders in quick mode
    echo "$output" | grep -E "Project .*project warning\(s\)"
}
