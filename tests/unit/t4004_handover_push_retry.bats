#!/usr/bin/env bats
# T-4004 (1409 Ask 7b) — the budget-critical auto-handover commits, then pushes; when the
# push waits on the audit lock past the outer timeout (FW_HANDOVER_TOTAL_TIMEOUT), T-3942
# already books the run by its landed commit and writes the restart signal. What was left:
# the handover commit stayed unpushed ("run 'fw push'"). The push is now retried detached.
#
# Drives the real `checkpoint.sh auto-handover` in a fake framework root whose handover.sh
# commits LATEST.md and then hangs as a lock-waiting push would.

load ../git_fence

setup() {
    REAL="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    T="$(mktemp -d)"
    FAKE="$T/fw"
    mkdir -p "$FAKE/agents/handover" "$FAKE/bin"
    ln -s "$REAL/lib" "$FAKE/lib"
    ln -s "$REAL/agents/context" "$FAKE/agents/context"
    cat > "$FAKE/agents/handover/handover.sh" <<'SH'
#!/bin/bash
cd "$PROJECT_ROOT" || exit 9
echo "handover $(date +%s)" > .context/handovers/LATEST.md
git add .context/handovers/LATEST.md && git commit -qm "Session handover" -- .context/handovers/LATEST.md
[ "${FAKE_PUSH:-ok}" = hang ] && sleep 30
exit 0
SH
    PUSHED="$T/pushed"
    printf '#!/bin/bash\necho "$*" >> %q\n' "$PUSHED" > "$FAKE/bin/fw"
    chmod +x "$FAKE/bin/fw" "$FAKE/agents/handover/handover.sh"
    ROOT="$T/proj"
    mkdir -p "$ROOT/.context/handovers" "$ROOT/.context/working"
    git -C "$ROOT" init -q && git -C "$ROOT" config user.email t@t && git -C "$ROOT" config user.name t
    echo "session_id: S-TEST-4004" > "$ROOT/.context/working/session.yaml"
}

teardown() { rm -rf "$T"; }

_auto() {
    run env PROJECT_ROOT="$ROOT" CONTEXT_DIR="$ROOT/.context" FW_BIN="$FAKE/bin/fw" \
        FW_HANDOVER_TOTAL_TIMEOUT=3 FAKE_PUSH="$1" \
        bash "$FAKE/agents/context/checkpoint.sh" auto-handover 999999
}

_wait_for() { local i; for i in $(seq 1 40); do [ -s "$1" ] && return 0; sleep 0.25; done; return 1; }

@test "T-4004: commit landed, push cut off by the timeout -> generated, restart signal, push retried detached" {
    _auto hang
    grep -q "Handover generated .*landed; push did not finish .*retrying detached" "$ROOT/.context/working/.compact-log"
    ! grep -q "Handover FAILED" "$ROOT/.context/working/.compact-log" || false
    [ -f "$ROOT/.context/working/.restart-requested" ]
    _wait_for "$PUSHED"
    grep -q "^push$" "$PUSHED"
    _wait_for "$ROOT/.context/working/.handover-push-retry.log"
    grep -q "retrying handover push" "$ROOT/.context/working/.handover-push-retry.log"
}

@test "T-4004/control: a handover whose push finished in time does not retry" {
    _auto ok
    grep -q "Handover generated" "$ROOT/.context/working/.compact-log"
    sleep 1
    [ ! -s "$PUSHED" ]
    [ ! -f "$ROOT/.context/working/.handover-push-retry.log" ]
}
