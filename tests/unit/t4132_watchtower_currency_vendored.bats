#!/usr/bin/env bats
# T-4132 — the Watchtower currency check was blind in a vendored consumer.
#
# lib/watchtower-staleness.sh defaulted the scan to $PROJECT_ROOT/web and
# returned early when it was missing. A consumer has no web/ at its root (the
# code is in .agentic-framework/web, where the server cd's to), so doctor,
# audit and `fw watchtower current` all said "current" while the process
# predated the upgraded files (832 field finding, their T-1139).

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    . "$FRAMEWORK_ROOT/lib/watchtower-staleness.sh"
    unset FW_WATCHTOWER_WEB_DIR
    CONSUMER="$BATS_TEST_TMPDIR/consumer"
    mkdir -p "$CONSUMER/.agentic-framework/web/templates" "$CONSUMER/.context/working"
    sleep 60 & LIVE_PID=$!
}

teardown() {
    [ -n "${LIVE_PID:-}" ] && kill "$LIVE_PID" 2>/dev/null
    return 0
}

_age() { touch -d "@$1" "$2"; }

@test "t4132: web dir resolves to FRAMEWORK_ROOT/web, not PROJECT_ROOT/web" {
    FRAMEWORK_ROOT="$CONSUMER/.agentic-framework" PROJECT_ROOT="$CONSUMER" run watchtower_web_dir
    [ "$output" = "$CONSUMER/.agentic-framework/web" ]
}

@test "t4132: framework-repo layout unchanged (FRAMEWORK_ROOT == PROJECT_ROOT)" {
    FRAMEWORK_ROOT="$CONSUMER" PROJECT_ROOT="$CONSUMER" run watchtower_web_dir
    [ "$output" = "$CONSUMER/web" ]
}

@test "t4132: vendored consumer — template newer than the process is detected" {
    _age "$(( $(date +%s) + 60 ))" "$CONSUMER/.agentic-framework/web/templates/x.html"
    export FRAMEWORK_ROOT="$CONSUMER/.agentic-framework" PROJECT_ROOT="$CONSUMER"
    run watchtower_stale_sources "$LIVE_PID"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "templates/x.html"
}

@test "t4132: vendored consumer — files older than the process read as current" {
    _age 1000000000 "$CONSUMER/.agentic-framework/web/templates/x.html"
    export FRAMEWORK_ROOT="$CONSUMER/.agentic-framework" PROJECT_ROOT="$CONSUMER"
    run watchtower_stale_sources "$LIVE_PID"
    [ "$status" -eq 1 ]
}

@test "t4132: missing web dir is 'cannot tell' (rc 2), never current" {
    run watchtower_stale_sources "$LIVE_PID" "$BATS_TEST_TMPDIR/nope"
    [ "$status" -eq 2 ]
}

@test "t4132: fw watchtower current — running pid + missing web dir fails, naming it" {
    echo "$LIVE_PID" > "$CONSUMER/.context/working/watchtower.pid"
    PROJECT_ROOT="$CONSUMER" FW_WATCHTOWER_WEB_DIR="$BATS_TEST_TMPDIR/nope" \
        run "$FRAMEWORK_ROOT/bin/watchtower.sh" current
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "CANNOT TELL"
}

@test "t4132: fw watchtower current — no Watchtower running still exits 0 (headless rule)" {
    PROJECT_ROOT="$CONSUMER" FW_WATCHTOWER_WEB_DIR="$BATS_TEST_TMPDIR/nope" \
        run "$FRAMEWORK_ROOT/bin/watchtower.sh" current
    [ "$status" -eq 0 ]
}

@test "t4132: fw watchtower current — stale vendored web is reported with the real dir" {
    echo "$LIVE_PID" > "$CONSUMER/.context/working/watchtower.pid"
    _age "$(( $(date +%s) + 60 ))" "$CONSUMER/.agentic-framework/web/templates/x.html"
    PROJECT_ROOT="$CONSUMER" FW_WATCHTOWER_WEB_DIR="$CONSUMER/.agentic-framework/web" \
        run "$FRAMEWORK_ROOT/bin/watchtower.sh" current
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "STALE"
    echo "$output" | grep -q ".agentic-framework/web"
}

@test "t4132: callers use watchtower_web_dir, none hard-code PROJECT_ROOT/web" {
    for f in bin/fw bin/watchtower.sh agents/audit/audit.sh; do
        grep -q 'watchtower_web_dir' "$FRAMEWORK_ROOT/$f"
        if grep -q 'watchtower_stale_sources[^)]*PROJECT_ROOT/web' "$FRAMEWORK_ROOT/$f"; then false; fi
    done
}

@test "t4132: fw upgrade prints the restart notice after the vendor step" {
    grep -q 'predates the upgraded web/ files' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    grep -q 'watchtower restart' "$FRAMEWORK_ROOT/lib/upgrade.sh"
}
