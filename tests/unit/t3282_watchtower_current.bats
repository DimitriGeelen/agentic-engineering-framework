#!/usr/bin/env bats
# T-3282 (G-104) — `fw watchtower current`: the close-time gate for the class
# T-2938 detected but could not prevent.
#
# Second occurrence of the stale-server class: the G-102 stderr sanitizer
# (T-3280, commit 122655001) was on disk, unit-green, [REVIEW]-approved — and
# never live, because the serving process started six days and 201 commits
# earlier. The T-2938 detector existed the whole time, in `fw doctor`, which
# nothing ran. This verb puts the same predicate where a web/-touching task's
# ## Verification block can run it mechanically (CLAUDE.md §Web-touching tasks),
# and the audit gains the same check on its unprompted surfaces.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    WT="$FRAMEWORK_ROOT/bin/watchtower.sh"
    # Fixture project: watchtower.sh reads $PROJECT_ROOT for the pid triple and
    # $PROJECT_ROOT/web for the staleness scan (lib/paths.sh honours the env).
    export PROJECT_ROOT="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/web"
    PID_FILE="$PROJECT_ROOT/.context/working/watchtower.pid"
}

teardown() {
    [ -n "${LIVE_PID:-}" ] && kill "$LIVE_PID" 2>/dev/null
    return 0
}

_spawn() {
    sleep 60 &
    LIVE_PID=$!
    echo "$LIVE_PID" > "$PID_FILE"
}

_age() { touch -d "@$1" "$2"; }
_now() { date +%s; }

# ── absent server: safe inside any ## Verification block ─────────────────────

@test "t3282: no pid file exits 0 — headless hosts must pass" {
    run "$WT" current
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "no Watchtower running"
}

@test "t3282: dead pid exits 0 — a stopped server cannot be stale" {
    echo 999999999 > "$PID_FILE"
    run "$WT" current
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "no Watchtower running"
}

# ── the two live verdicts ────────────────────────────────────────────────────

@test "t3282: current process exits 0 and says so" {
    _spawn
    _age 1000000000 "$PROJECT_ROOT/web/app.py"
    run "$WT" current
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "newer than every file"
}

@test "t3282: stale process exits 1, names the file and the remedy" {
    # The live-incident shape: the sanitizer landed after the server started.
    _spawn
    _age 1000000000 "$PROJECT_ROOT/web/app.py"
    mkdir -p "$PROJECT_ROOT/web/blueprints"
    _age "$(( $(_now) + 60 ))" "$PROJECT_ROOT/web/blueprints/inception.py"
    run "$WT" current
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "STALE"
    echo "$output" | grep -q "blueprints/inception.py"
    echo "$output" | grep -q "watchtower restart"
}

# ── wiring: predicate reachable from the surfaces that must run it ───────────

@test "t3282: the audit calls the predicate — detection is deployed, not just wired" {
    # The whole RCA of the second incident: the T-2938 predicate was correct
    # and invoked only by an on-demand surface. Pin the unprompted call site.
    grep -q 'watchtower_stale_sources' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    grep -q 'watchtower-staleness.sh' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
}

@test "t3282: the audit WARN names the restart remedy" {
    grep -q 'Watchtower serving stale code' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    grep -A3 'Watchtower serving stale code' "$FRAMEWORK_ROOT/agents/audit/audit.sh" \
        | grep -q 'watchtower restart'
}

@test "t3282: CLAUDE.md carries the web-touching Verification rule" {
    grep -q 'bin/fw watchtower current' "$FRAMEWORK_ROOT/CLAUDE.md"
}

@test "t3282: help discovers the verb" {
    run "$WT" --help
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "current"
}
