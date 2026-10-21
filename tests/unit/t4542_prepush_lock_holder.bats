#!/usr/bin/env bats
load ../git_fence  # T-3610: git discovery must not escape a fixture into a repo above the temp dir
# T-4542: git push hung silently behind cron audits (field report, 1409-sprind).
#
# Two defects, two legs under test:
#   (a) the pre-push wait named nobody: the operator saw a hang, not "waiting on
#       pid N (audit.sh --cron ...) held 812s". Now audit.sh records the holder in
#       .context/locks/audit.lock.holder and the gate prints it at once, repeats it
#       while waiting, and names it in the BLOCK.
#   (b) back-to-back cron audits kept re-taking the lock, so the push only ever saw
#       it held. Now the waiting gate leaves .context/locks/push-waiting, and a
#       --cron audit that sees a LIVE waiter exits 75 without taking the lock.
#
# The lock is held by a FAKE cron audit (flock + holder record, as the real
# audit.sh writes it). The yield leg runs the REAL agents/audit/audit.sh.
# Hermetic: every lock and marker is the fixture's own.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_REPO="$(mktemp -d -t fw-t4542-XXXXXX)"
    cd "$TMP_REPO"
    git init -q
    git config user.email "t4542@local"
    git config user.name "T-4542 fixture"
    git config commit.gpgsign false

    mkdir -p agents/audit bin .context/locks .context/working
    _install_audit_stub
    printf '#!/bin/bash\nexit 0\n' > bin/fw
    chmod +x bin/fw

    echo "1.0.0" > VERSION
    git add -A
    git commit -q -m "T-4542: fixture init"
    REMOTE_SHA="$(git rev-parse HEAD)"

    PROJECT_ROOT="$TMP_REPO" bash "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks >/dev/null 2>&1
    [ -x .git/hooks/pre-push ]

    BRANCH="$(git rev-parse --abbrev-ref HEAD)"
    LOCK_FILE="$TMP_REPO/.context/locks/audit.lock"
    HOLDER_FILE="$TMP_REPO/.context/locks/audit.lock.holder"
    WAITING_FILE="$TMP_REPO/.context/locks/push-waiting"
    READY_FILE="$TMP_REPO/fake-cron-ready"
    touch "$LOCK_FILE"
    CRON_PID=""
    SLEEPER_PID=""
    export REMOTE_SHA BRANCH LOCK_FILE
}

teardown() {
    for p in "${CRON_PID:-}" "${SLEEPER_PID:-}"; do
        [ -n "$p" ] || continue
        pkill -P "$p" 2>/dev/null
        kill "$p" 2>/dev/null
        wait "$p" 2>/dev/null
    done
    cd /
    [ -n "${TMP_REPO:-}" ] && rm -rf "$TMP_REPO"
    return 0
}

# Same lock contract as the real audit (flock -n on the rendezvous file, exit 75).
_install_audit_stub() {
    cat > "$TMP_REPO/agents/audit/audit.sh" <<'STUB'
#!/bin/bash
exec 200>"$PROJECT_ROOT/.context/locks/audit.lock"
if ! flock -n 200; then
    echo "Another audit is already running — exiting (no verdict produced)" >&2
    exit 75
fi
echo "AUDIT-RAN-TO-COMPLETION"
echo "AUDIT-SCOPE: fails=0 ref=0 worktree=0"
exit 0
STUB
    chmod +x "$TMP_REPO/agents/audit/audit.sh"
}

# Wait for the background lock holder to write its ready file (it does so only
# AFTER it holds the lock). Never probe the lock itself: a probe takes the lock
# for a moment, and a holder that tries at that instant loses it (the flake
# this replaces). Fails at once if the holder has exited, else after ~30 s.
_wait_lock_holder_ready() {
    local i=0
    while [ ! -e "$READY_FILE" ]; do
        kill -0 "$CRON_PID" 2>/dev/null || { echo "lock holder exited before taking the lock" >&2; return 1; }
        i=$((i + 1))
        [ "$i" -gt 300 ] && { echo "lock holder not ready after 30s" >&2; return 1; }
        sleep 0.1
    done
}

# A fake cron audit: takes the lock and writes the holder record the way
# agents/audit/audit.sh does, signals ready, then sits on it for N seconds.
_fake_cron_audit_for() {
    ( exec 200>"$LOCK_FILE"
      flock -w 30 200 || exit 75
      printf 'pid=%s\nsince=%s\njob=audit.sh --cron --section structure\n' \
          "$BASHPID" "$(( $(date +%s) - 812 ))" > "$HOLDER_FILE"
      : > "$READY_FILE"
      exec sleep "$1" ) &
    CRON_PID=$!
    _wait_lock_holder_ready
}

_run_push_hook() {
    local sha; sha="$(git rev-parse HEAD)"
    run env FW_PREPUSH_LOCK_WAIT="${FW_PREPUSH_LOCK_WAIT:-3}" \
            FW_PREPUSH_LOCK_PROGRESS="${FW_PREPUSH_LOCK_PROGRESS:-1}" \
        bash -c "echo 'refs/heads/$BRANCH $sha refs/heads/$BRANCH $REMOTE_SHA' \
            | .git/hooks/pre-push origin http://localhost"
}

@test "t4542 (a) wait line names the holder pid, job and age at once, repeats while waiting, and the BLOCK names it" {
    _fake_cron_audit_for 60
    FW_PREPUSH_LOCK_WAIT=4 FW_PREPUSH_LOCK_PROGRESS=1 _run_push_hook
    [ "$status" -eq 1 ]
    [[ "$output" == *"Push blocked"* ]]
    [[ "$output" == *"lock held by pid $CRON_PID (audit.sh --cron --section structure) for 81"* ]]
    [[ "$output" == *"still waiting ("* ]]
    [[ "$output" == *"Lock: held by pid $CRON_PID"* ]]
    # the wait line comes BEFORE the progress lines (printed at once, not at the end)
    local first_wait first_prog
    first_wait=$(printf '%s\n' "$output" | grep -n "Audit lock held — waiting" | head -1 | cut -d: -f1)
    first_prog=$(printf '%s\n' "$output" | grep -n "still waiting" | head -1 | cut -d: -f1)
    [ -n "$first_wait" ] && [ -n "$first_prog" ] && [ "$first_wait" -lt "$first_prog" ]
}

@test "t4542 (a2) a dead holder record is not presented as the holder" {
    printf 'pid=999999\nsince=1\njob=audit.sh --cron\n' > "$HOLDER_FILE"
    ( exec 200>"$LOCK_FILE"; flock -w 30 200 || exit 75; : > "$READY_FILE"; exec sleep 60 ) &
    CRON_PID=$!
    _wait_lock_holder_ready
    FW_PREPUSH_LOCK_WAIT=2 _run_push_hook
    [ "$status" -eq 1 ]
    [[ "$output" == *"holder unknown (recorded pid 999999 has exited)"* ]]
    [[ "$output" != *"held by pid 999999"* ]] || false
}

@test "t4542 (b) the waiting gate leaves a live push-waiting marker and removes it afterwards" {
    _fake_cron_audit_for 60
    # Watch until the push has returned (not for a fixed time: hook start-up
    # under load can eat a fixed budget). Copy only a complete record, and keep
    # looking if the marker vanished between the test and the copy.
    local push_done="$TMP_REPO/push-done"
    ( for _ in $(seq 1 600); do
          grep -q '^pid=' "$WAITING_FILE" 2>/dev/null \
              && cp "$WAITING_FILE" "$TMP_REPO/seen-marker" 2>/dev/null && exit 0
          [ -e "$push_done" ] && exit 0
          sleep 0.05
      done ) &
    local watcher=$!
    FW_PREPUSH_LOCK_WAIT=3 _run_push_hook
    : > "$push_done"
    wait "$watcher"
    [ "$status" -eq 1 ]
    grep -q '^pid=[0-9][0-9]*$' "$TMP_REPO/seen-marker"
    [ ! -e "$WAITING_FILE" ]
}

@test "t4542 (c) a --cron audit (REAL audit.sh) yields to a live push waiter: exit 75, lock not taken" {
    sleep 60 & SLEEPER_PID=$!
    printf 'pid=%s\nsince=%s\n' "$SLEEPER_PID" "$(date +%s)" > "$WAITING_FILE"
    run env PROJECT_ROOT="$TMP_REPO" timeout 60 bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" --cron --section structure
    [ "$status" -eq 75 ]
    [ ! -e "$HOLDER_FILE" ]
    # the lock is free: the cron run never took it
    flock -n "$LOCK_FILE" -c true
}

@test "t4542 (c2) control: a DEAD waiter record does not make the cron audit yield — it takes the lock and records itself" {
    printf 'pid=999999\nsince=1\n' > "$WAITING_FILE"
    PROJECT_ROOT="$TMP_REPO" bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" --cron --section structure >/dev/null 2>&1 &
    CRON_PID=$!
    local i=0
    while [ ! -s "$HOLDER_FILE" ]; do
        i=$((i + 1))
        [ "$i" -gt 300 ] && { echo "real audit never recorded a holder" >&2; false; }
        sleep 0.1
    done
    grep -q "^pid=$CRON_PID$" "$HOLDER_FILE"
    grep -q '^job=audit.sh --cron --section structure$' "$HOLDER_FILE"
    grep -q '^since=[0-9][0-9]*$' "$HOLDER_FILE"
}

@test "t4542 (c3) control: a foreground (non-cron) audit is not affected by the waiter marker" {
    sleep 60 & SLEEPER_PID=$!
    printf 'pid=%s\nsince=%s\n' "$SLEEPER_PID" "$(date +%s)" > "$WAITING_FILE"
    PROJECT_ROOT="$TMP_REPO" bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section structure >/dev/null 2>&1 &
    CRON_PID=$!
    local i=0
    while [ ! -s "$HOLDER_FILE" ]; do
        i=$((i + 1))
        [ "$i" -gt 300 ] && { echo "foreground audit yielded to the push marker" >&2; false; }
        sleep 0.1
    done
    grep -q "^pid=$CRON_PID$" "$HOLDER_FILE"
}
