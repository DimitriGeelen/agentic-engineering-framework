#!/usr/bin/env bats
# T-4806 — an operator disarm is not a termination, and a stale termination does
# not brake a session that was never part of a continuous run.
#
# Origin (1409 dauerlauf-1, F1): `fw continuous disarm` wrote last_terminated_reason
# ('disarmed by operator at …'), and bin/claude-fw refused every budget auto-restart
# on a non-empty last_terminated_reason whether or not continuous mode was armed.
# 1409 had no budget restart for 17 days; its ledger shows continuous-terminated 11x.
#
# Driven end to end with a stub `claude` on PATH (same harness as t3243). Every
# "restart proceeds" leg is paired with a "restart refused" CONTROL, so a brake
# that was simply removed cannot pass this suite.

# T-3747: no always-on sidecar under a fixture.
export CLAUDE_FW_NO_SIDECAR=1

setup() {
    REPO="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    WRAPPER="${FW_TEST_WRAPPER:-${REPO}/bin/claude-fw}"
    FW="$REPO/bin/fw"
    TDIR="$(mktemp -d)"
    mkdir -p "${TDIR}/.context/working" "${TDIR}/stubbin"
    git -C "$TDIR" init -q
    git -C "$TDIR" config user.email t@t.t
    git -C "$TDIR" config user.name t
    STATE="${TDIR}/.context/working/.continuous-mode.yaml"
    LOG="${TDIR}/.context/working/continuous-run.jsonl"

    # Stub claude. Run 1 writes a fresh restart signal. STUB_TERMINATE=1 makes run 1
    # also record a termination the way the injector does (disarm + reason in one
    # write, T-3167); STUB_RESUMED=1 additionally stamps last_resumed_at = now, the
    # mark the injector leaves when it processed an armed iteration during this run.
    cat > "${TDIR}/stubbin/claude" <<'STUB'
#!/bin/bash
root=$(git rev-parse --show-toplevel 2>/dev/null)
cnt="${root}/.stub-count"
n=$(cat "$cnt" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > "$cnt"
if [ "$n" -eq 1 ]; then
    st="${root}/.context/working/.continuous-mode.yaml"
    if [ "${STUB_TERMINATE:-0}" = "1" ]; then
        {
            echo "enabled: false"
            echo "current_iteration: 2"
            echo "last_terminated_reason: 'tier ceiling exceeded: T-900 blast-radius 5 > tier_ceiling 1'"
            [ "${STUB_RESUMED:-0}" = "1" ] && echo "last_resumed_at: '$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
        } > "$st"
    fi
    printf '{"session_id":"S-TEST","tokens":290000}' \
        > "${root}/.context/working/.restart-requested"
fi
exit 0
STUB
    chmod +x "${TDIR}/stubbin/claude"
}

teardown() { rm -rf "$TDIR"; }

run_wrapper() {
    cd "$TDIR" || return 1
    run env PATH="${TDIR}/stubbin:${PATH}" HOME="$TDIR" \
        FW_NO_STARTUP_BANNER=1 FW_NO_TERMINATOR=1 \
        FW_MAX_RESTARTS=3 FW_RESTART_WINDOW=3600 \
        timeout 180 bash "$WRAPPER"
}

count_events() {
    [ -f "$LOG" ] || { echo 0; return; }
    python3 - "$LOG" "$1" "$2" <<'PY'
import json, sys
log, ev, rs = sys.argv[1:4]
n = 0
for line in open(log, encoding="utf-8"):
    try:
        d = json.loads(line)
    except Exception:
        continue
    if d.get("event") == ev and d.get("reason") == rs:
        n += 1
print(n)
PY
}

field() { python3 -c "import yaml,sys; print((yaml.safe_load(open('$STATE')) or {}).get('$1'))"; }

# ── The reported bug ───────────────────────────────────────────────────────

@test "legacy disarm-written reason no longer refuses a budget restart (1409 F1)" {
    printf "enabled: false\ncurrent_iteration: 0\nlast_terminated_reason: 'disarmed by operator at 2026-10-10T08:00:00Z'\n" > "$STATE"
    run_wrapper
    [ "$(count_events exit continuous-terminated)" -eq 0 ]
    [ "$(count_events iterate restart)" -eq 1 ]
    [[ "$output" != *"Continuous run was TERMINATED"* ]]
}

@test "a stale real termination from an earlier run does not brake a non-continuous session" {
    printf "enabled: false\ncurrent_iteration: 2\nlast_resumed_at: '2026-10-01T00:00:00Z'\nlast_terminated_reason: 'max_iterations 3 reached'\n" > "$STATE"
    run_wrapper
    [ "$(count_events exit continuous-terminated)" -eq 0 ]
    [ "$(count_events iterate restart)" -eq 1 ]
}

# ── CONTROLS: a real bound on a run that was armed still stops the loop ─────

@test "CONTROL: run armed at launch and terminated during it is refused" {
    printf "enabled: true\ncurrent_iteration: 1\nmax_iterations: 10\nlast_terminated_reason: ''\n" > "$STATE"
    STUB_TERMINATE=1 run_wrapper_term
    [ "$(count_events exit continuous-terminated)" -eq 1 ]
    [ "$(count_events iterate restart)" -eq 0 ]
    [[ "$output" == *"Continuous run was TERMINATED"* ]]
}

@test "CONTROL: run armed DURING the session (last_resumed_at in this run) is refused" {
    printf "enabled: false\ncurrent_iteration: 0\n" > "$STATE"
    STUB_TERMINATE=1 STUB_RESUMED=1 run_wrapper_term
    [ "$(count_events exit continuous-terminated)" -eq 1 ]
    [ "$(count_events iterate restart)" -eq 0 ]
}

@test "CONTROL: a non-armed run whose state shows no in-run resume is not refused" {
    # Same stub write as the leg above minus last_resumed_at: the termination did
    # not come from this run, so the plain budget restart proceeds.
    printf "enabled: false\ncurrent_iteration: 0\n" > "$STATE"
    STUB_TERMINATE=1 run_wrapper_term
    [ "$(count_events exit continuous-terminated)" -eq 0 ]
    [ "$(count_events iterate restart)" -eq 1 ]
}

@test "a refusal is pushed through fw_notify (not silent when unattended)" {
    mkdir -p "${TDIR}/disp/alerts"
    touch "${TDIR}/disp/alerts/__init__.py"
    cat > "${TDIR}/disp/alerts/alert_dispatcher.py" <<PY
def dispatch_alert(trigger, title, message, context=None):
    with open("${TDIR}/notified", "a") as f:
        f.write(trigger + "|" + title + "|" + message + "\n")
    return True
PY
    printf "enabled: true\ncurrent_iteration: 1\nlast_terminated_reason: ''\n" > "$STATE"
    NTFY_ENABLED=true SKILLS_DISPATCHER="${TDIR}/disp/alerts/alert_dispatcher.py" \
        STUB_TERMINATE=1 run_wrapper_term
    [ "$(count_events exit continuous-terminated)" -eq 1 ]
    for _ in $(seq 1 50); do [ -s "${TDIR}/notified" ] && break; sleep 0.1; done
    grep -q "tier ceiling exceeded" "${TDIR}/notified"
}

run_wrapper_term() {
    cd "$TDIR" || return 1
    run env PATH="${TDIR}/stubbin:${PATH}" HOME="$TDIR" \
        FW_NO_STARTUP_BANNER=1 FW_NO_TERMINATOR=1 \
        FW_MAX_RESTARTS=3 FW_RESTART_WINDOW=3600 \
        STUB_TERMINATE="${STUB_TERMINATE:-0}" STUB_RESUMED="${STUB_RESUMED:-0}" \
        NTFY_ENABLED="${NTFY_ENABLED:-}" SKILLS_DISPATCHER="${SKILLS_DISPATCHER:-/nonexistent}" \
        timeout 180 bash "$WRAPPER"
}

# ── fw continuous disarm records a disarm, not a death ─────────────────────

@test "disarm writes disarmed_at + disarmed_reason and no last_terminated_reason" {
    SB="$BATS_TEST_TMPDIR/sb"; mkdir -p "$SB/.context/working" "$SB/.tasks/active"; touch "$SB/.framework.yaml"
    STATE="$SB/.context/working/.continuous-mode.yaml"
    env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3 --directive "t4806" >/dev/null
    run env PROJECT_ROOT="$SB" "$FW" continuous disarm --reason "pinned by t4806"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pinned by t4806"* ]]
    [ "$(field enabled)" = "False" ]
    [ "$(field disarmed_reason)" = "pinned by t4806" ]
    [ "$(field disarmed_at)" != "None" ]
    [ "$(field last_terminated_reason)" = "None" ] || [ "$(field last_terminated_reason)" = "" ]
}

@test "default disarm reason is recorded; re-arm clears the disarm fields" {
    SB="$BATS_TEST_TMPDIR/sb"; mkdir -p "$SB/.context/working" "$SB/.tasks/active"; touch "$SB/.framework.yaml"
    STATE="$SB/.context/working/.continuous-mode.yaml"
    env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3 --directive "t4806" >/dev/null
    env PROJECT_ROOT="$SB" "$FW" continuous disarm >/dev/null
    [[ "$(field disarmed_reason)" == "disarmed by operator"* ]]
    env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3 --directive "t4806" >/dev/null
    [ "$(field disarmed_at)" = "None" ]
    [ "$(field disarmed_reason)" = "None" ]
}

@test "status shows the disarm separately from a recorded termination" {
    SB="$BATS_TEST_TMPDIR/sb"; mkdir -p "$SB/.context/working" "$SB/.tasks/active"; touch "$SB/.framework.yaml"
    env PROJECT_ROOT="$SB" "$FW" continuous arm --hours 2 --iterations 3 --directive "t4806" >/dev/null
    env PROJECT_ROOT="$SB" "$FW" continuous disarm --reason "pinned by t4806" >/dev/null
    run env PROJECT_ROOT="$SB" "$FW" continuous status
    [[ "$output" == *"Disarmed by operator"*"pinned by t4806"* ]]
    [[ "$output" != *"stored last_terminated_reason"* ]] || false
}
