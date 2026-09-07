#!/usr/bin/env bats
# T-3297 / OBS-305: the pre-push audit gate must survive cron audit pileup
# without weakening the T-2930 no-false-pass rule.
#
# Origin: structural-30m cron audits stack when a run overlaps the next trigger;
# the gate runs `--section structure` — the same section the cron holds — so
# every push contends, the "finishes within a minute or two" advice no longer
# holds, and the only documented escape was Tier 0 `git push --no-verify`.
#
# Two mechanisms under test, plus their controls:
#   1. Bounded lock wait (FW_PREPUSH_LOCK_WAIT, default 90, 0 = old behavior):
#      lock frees in-window → the gate's audit runs as today; window exhausted
#      → the same BLOCK as before.
#   2. Contention-only Tier-2 bypass (FW_PUSH_SKIP_AUDIT_ON_CONTENTION=1):
#      applies ONLY to exit 75 (audit did not run). Exit 2 (real FAILs) still
#      blocks with the env set — that control is the critical leg here.
#
# L-599 hermeticity: everything lives in a synthetic repo under a tmpdir. The
# hook under test is GENERATED INTO the fixture from agents/git/lib/hooks.sh,
# and the only lock ever held is the fixture's own .context/locks/audit.lock —
# never the live repo's.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_REPO="$(mktemp -d -t fw-t3297-XXXXXX)"
    cd "$TMP_REPO"
    git init -q
    git config user.email "t3297@local"
    git config user.name "T-3297 fixture"
    git config commit.gpgsign false

    mkdir -p agents/audit bin .context/locks .context/working
    _install_audit_stub
    _install_fw_stub

    echo "1.0.0" > VERSION
    git add -A
    git commit -q -m "T-3297: fixture init"
    REMOTE_SHA="$(git rev-parse HEAD)"

    PROJECT_ROOT="$TMP_REPO" bash "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks >/dev/null 2>&1
    [ -x .git/hooks/pre-push ]

    BRANCH="$(git rev-parse --abbrev-ref HEAD)"
    LOCK_FILE="$TMP_REPO/.context/locks/audit.lock"
    touch "$LOCK_FILE"
    HOLDER_PID=""
    export REMOTE_SHA BRANCH LOCK_FILE
}

teardown() {
    if [ -n "${HOLDER_PID:-}" ]; then
        kill "$HOLDER_PID" 2>/dev/null
        wait "$HOLDER_PID" 2>/dev/null
    fi
    cd /
    [ -n "${TMP_REPO:-}" ] && rm -rf "$TMP_REPO"
    return 0
}

# The audit stub mimics the real audit.sh lock contract (flock -n on the
# rendezvous file, exit 75 on contention, never unlink — T-3298), so the gate's
# probe and retry loop are exercised against the semantics the real audit has.
#   T3297_FORCE75=1  report contention unconditionally, lock or no lock
#                    (the shape the blind-retry bailout exists for)
#   T3297_EXIT=2     report a REF-scoped FAIL (the critical bypass control)
_install_audit_stub() {
    cat > "$TMP_REPO/agents/audit/audit.sh" <<'STUB'
#!/bin/bash
echo "=== STRUCTURE CHECKS ==="
if [ "${T3297_FORCE75:-0}" = "1" ]; then
    echo "Another audit is already running — exiting (no verdict produced)" >&2
    exit 75
fi
exec 200>"$PROJECT_ROOT/.context/locks/audit.lock"
if ! flock -n 200; then
    echo "Another audit is already running — exiting (no verdict produced)" >&2
    exit 75
fi
if [ "${T3297_EXIT:-0}" = "2" ]; then
    echo "[FAIL] a ref-scoped finding"
    echo "AUDIT-SCOPE: fails=1 ref=1 worktree=0"
    exit 2
fi
echo "AUDIT-RAN-TO-COMPLETION"
echo "AUDIT-SCOPE: fails=0 ref=0 worktree=0"
exit 0
STUB
    chmod +x "$TMP_REPO/agents/audit/audit.sh"
}

# The gate runs several checks before the audit. Neutralise them so a failure
# here can only be the audit gate.
_install_fw_stub() {
    cat > "$TMP_REPO/bin/fw" <<'STUB'
#!/bin/bash
exit 0
STUB
    chmod +x "$TMP_REPO/bin/fw"
}

# Hold the fixture lock with a real flock for N seconds, and do not return
# until the lock is observably held — otherwise the gate's first attempt could
# race the holder's startup and pass for the wrong reason.
_hold_lock_for() {
    flock "$LOCK_FILE" sleep "$1" &
    HOLDER_PID=$!
    local i=0
    while flock -n "$LOCK_FILE" -c true 2>/dev/null; do
        i=$((i + 1))
        [ "$i" -gt 50 ] && { echo "lock never became held" >&2; return 1; }
        sleep 0.1
    done
}

_run_push_hook() {
    local sha; sha="$(git rev-parse HEAD)"
    run env FW_PREPUSH_LOCK_WAIT="${FW_PREPUSH_LOCK_WAIT:-90}" \
            FW_PUSH_SKIP_AUDIT_ON_CONTENTION="${FW_PUSH_SKIP_AUDIT_ON_CONTENTION:-0}" \
            T3297_FORCE75="${T3297_FORCE75:-0}" \
            T3297_EXIT="${T3297_EXIT:-0}" \
        bash -c "echo 'refs/heads/$BRANCH $sha refs/heads/$BRANCH $REMOTE_SHA' \
            | .git/hooks/pre-push origin http://localhost"
}

# ── 1. bounded wait: lock frees in-window → gate audit runs, push proceeds ───

@test "t3297 (a) lock held then released in-window → gate waits, audit runs, push ALLOWED" {
    _hold_lock_for 3
    FW_PREPUSH_LOCK_WAIT=20 _run_push_hook
    [ "$status" -eq 0 ]
    [[ "$output" == *"waiting up to 20s"* ]]
    [[ "$output" == *"AUDIT-RAN-TO-COMPLETION"* ]]
    [[ "$output" != *"Push blocked"* ]]
}

# ── 2. wait exhaustion: lock held past the window → BLOCK, exactly as today ──

@test "t3297 (b) lock held past the window → push BLOCKED (no-false-pass control)" {
    _hold_lock_for 60
    FW_PREPUSH_LOCK_WAIT=3 _run_push_hook
    [ "$status" -eq 1 ]
    [[ "$output" == *"COULD NOT RUN"* ]]
    [[ "$output" == *"Push blocked"* ]]
    [[ "$output" != *"AUDIT-RAN-TO-COMPLETION"* ]]
}

@test "t3297 (b2) the block message names both new mechanisms, executable as-is (T-3299 rail)" {
    _hold_lock_for 60
    FW_PREPUSH_LOCK_WAIT=2 _run_push_hook
    [ "$status" -eq 1 ]
    [[ "$output" == *"FW_PREPUSH_LOCK_WAIT=300 git push"* ]]
    [[ "$output" == *"FW_PUSH_SKIP_AUDIT_ON_CONTENTION=1 git push"* ]]
    # and the Tier-0 last resort is still named, but as last resort
    [[ "$output" == *"--no-verify"* ]]
}

@test "t3297 (c) FW_PREPUSH_LOCK_WAIT=0 disables the wait → immediate BLOCK (old behavior)" {
    _hold_lock_for 60
    local t0 t1
    t0=$(date +%s)
    FW_PREPUSH_LOCK_WAIT=0 _run_push_hook
    t1=$(date +%s)
    [ "$status" -eq 1 ]
    [[ "$output" == *"COULD NOT RUN"* ]]
    [[ "$output" != *"waiting up to"* ]]
    [ $(( t1 - t0 )) -lt 5 ]
}

# ── 3. blind-retry bailout: 75 with no observable lock must not burn the window

@test "t3297 (d) audit reports 75 but the probe sees the lock free → gate gives up fast, still BLOCKS" {
    # The shape a vendored audit resolving a different CONTEXT_DIR would produce.
    # Also the reason the pre-existing t3126 exit-75 legs don't stall for 90s.
    local t0 t1
    t0=$(date +%s)
    T3297_FORCE75=1 FW_PREPUSH_LOCK_WAIT=30 _run_push_hook
    t1=$(date +%s)
    [ "$status" -eq 1 ]
    [[ "$output" == *"COULD NOT RUN"* ]]
    [ $(( t1 - t0 )) -lt 15 ]
}

# ── 4. Tier-2 contention-only bypass ─────────────────────────────────────────

@test "t3297 (e) exit 75 + FW_PUSH_SKIP_AUDIT_ON_CONTENTION=1 → push ALLOWED and Tier-2 logged" {
    _hold_lock_for 60
    FW_PREPUSH_LOCK_WAIT=0 FW_PUSH_SKIP_AUDIT_ON_CONTENTION=1 _run_push_hook
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING"* ]]
    [[ "$output" == *"COULD NOT RUN"* ]]
    local log="$TMP_REPO/.context/working/.gate-bypass-log.yaml"
    [ -f "$log" ]
    grep -q "FW_PUSH_SKIP_AUDIT_ON_CONTENTION=1" "$log"
    grep -q "pre-push audit gate (T-3297)" "$log"
}

@test "t3297 (f) exit 2 + FW_PUSH_SKIP_AUDIT_ON_CONTENTION=1 → push still BLOCKED (critical control)" {
    # The bypass is contention-only. A real FAIL verdict must block whatever
    # the env says — otherwise the env var is a false-pass switch one typo wide.
    T3297_EXIT=2 FW_PUSH_SKIP_AUDIT_ON_CONTENTION=1 _run_push_hook
    [ "$status" -eq 1 ]
    [[ "$output" == *"audit has FAILURES"* ]]
    # and no bypass entry was written for it
    if [ -f "$TMP_REPO/.context/working/.gate-bypass-log.yaml" ]; then
        ! grep -q "FW_PUSH_SKIP_AUDIT_ON_CONTENTION" "$TMP_REPO/.context/working/.gate-bypass-log.yaml"
    fi
}

@test "t3297 (g) exit 75 WITHOUT the env → still BLOCKED (bypass is opt-in, not default)" {
    _hold_lock_for 60
    FW_PREPUSH_LOCK_WAIT=0 _run_push_hook
    [ "$status" -eq 1 ]
    [[ "$output" == *"Push blocked"* ]]
}

# ── 5. non-contended paths are untouched ─────────────────────────────────────

@test "t3297 (h) uncontended clean audit → push allowed with no wait chatter" {
    _run_push_hook
    [ "$status" -eq 0 ]
    [[ "$output" == *"AUDIT-RAN-TO-COMPLETION"* ]]
    [[ "$output" != *"waiting up to"* ]]
}

# ── 6. source pins ───────────────────────────────────────────────────────────

@test "t3297 (i) the default window is 90s and lives in the hook source" {
    grep -q 'FW_PREPUSH_LOCK_WAIT:-90' "$FRAMEWORK_ROOT/agents/git/lib/hooks.sh"
}

@test "t3297 (j) the bypass check lives INSIDE the exit-75 branch only" {
    # Structural pin for the critical control: the env is consulted exactly once,
    # and that consultation sits inside `if [ $audit_exit -eq 75 ]`. If a later
    # edit hoists it out, (f) would catch the behavior — this names the cause.
    local n
    n=$(grep -c 'FW_PUSH_SKIP_AUDIT_ON_CONTENTION:-0' "$FRAMEWORK_ROOT/agents/git/lib/hooks.sh")
    [ "$n" -eq 1 ]
    awk '/^if \[ \$audit_exit -eq 75 \]; then$/,/^fi$/' \
        "$FRAMEWORK_ROOT/agents/git/lib/hooks.sh" \
        | head -40 | grep -q 'FW_PUSH_SKIP_AUDIT_ON_CONTENTION'
}
