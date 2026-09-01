#!/usr/bin/env bats
# T-3243 — bin/claude-fw restart policy, driven end to end.
#
# WHY THIS SUITE EXISTS. Before it, nothing executed bin/claude-fw's main loop.
# All three defects it pins lived in the branch arithmetic of a `while true` that
# no test ever entered, and the only instrument that measured them was the JSONL
# log — which reported them faithfully in language that made them look correct
# ("max-restarts", "no-signal" both read as intended terminations). Three days of
# accurate logging, zero days of detection.
#
# HOW. A stub `claude` is placed on PATH, so `command claude` inside the wrapper
# runs it. The stub counts its invocations, optionally writes a fresh restart
# signal, and exits with a chosen code — which is enough to drive every branch of
# the loop for real, rather than reasoning about it.
#
# EVERY FIX SHIPS WITH ITS CONTROL LEG. A cap that no longer fires and a cap that
# cannot fire are the same observation; a re-arm that always happens and one that
# happens when armed are the same observation. The negative cases are the point.

setup() {
    REPO="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    # Overridable so the suite can be pointed at the PRE-FIX wrapper and shown to
    # go red. A suite that has never failed is not evidence that it can.
    WRAPPER="${FW_TEST_WRAPPER:-${REPO}/bin/claude-fw}"
    TDIR="$(mktemp -d)"
    mkdir -p "${TDIR}/.context/working" "${TDIR}/stubbin"

    git -C "$TDIR" init -q
    git -C "$TDIR" config user.email t@t.t
    git -C "$TDIR" config user.name t

    # The stub claude. STUB_SIGNAL_UNTIL controls how many runs write a fresh
    # restart signal; STUB_EXIT_CODE is the exit status the wrapper observes.
    cat > "${TDIR}/stubbin/claude" <<'STUB'
#!/bin/bash
root=$(git rev-parse --show-toplevel 2>/dev/null)
cnt="${root}/.stub-count"
n=$(cat "$cnt" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > "$cnt"
if [ "$n" -le "${STUB_SIGNAL_UNTIL:-0}" ]; then
    printf '{"session_id":"S-TEST","tokens":290000}' \
        > "${root}/.context/working/.restart-requested"
fi
exit "${STUB_EXIT_CODE:-0}"
STUB
    chmod +x "${TDIR}/stubbin/claude"

    LOG="${TDIR}/.context/working/continuous-run.jsonl"
}

teardown() { rm -rf "$TDIR"; }

# arm <true|false> — write the continuous-mode state file.
arm() { printf 'enabled: %s\ncurrent_iteration: 0\n' "$1" \
        > "${TDIR}/.context/working/.continuous-mode.yaml"; }

# run_wrapper — execute claude-fw inside the sandbox repo with a stubbed PATH.
run_wrapper() {
    cd "$TDIR" || return 1
    run env PATH="${TDIR}/stubbin:${PATH}" \
        HOME="$TDIR" \
        FW_NO_STARTUP_BANNER=1 FW_NO_TERMINATOR=1 \
        FW_MAX_RESTARTS="${MAXR:-3}" FW_RESTART_WINDOW="${WINDOW:-3600}" \
        STUB_SIGNAL_UNTIL="${SIGUNTIL:-0}" STUB_EXIT_CODE="${EXITCODE:-0}" \
        timeout 180 bash "$WRAPPER"
}

# count_events <event> <reason> — how many matching rows in the JSONL log.
count_events() {
    [ -f "$LOG" ] || { echo 0; return; }
    python3 - "$LOG" "$1" "$2" <<'PY'
import json, sys
log, ev, rs = sys.argv[1:4]
n = 0
for line in open(log, encoding="utf-8"):
    line = line.strip()
    if not line:
        continue
    try:
        d = json.loads(line)
    except Exception:
        continue
    if d.get("event") == ev and d.get("reason") == rs:
        n += 1
print(n)
PY
}

# max_restart_count — highest restart_count on any `iterate` row.
max_restart_count() {
    [ -f "$LOG" ] || { echo -1; return; }
    python3 - "$LOG" <<'PY'
import json, sys
best = -1
for line in open(sys.argv[1], encoding="utf-8"):
    line = line.strip()
    if not line:
        continue
    try:
        d = json.loads(line)
    except Exception:
        continue
    if d.get("event") == "iterate":
        best = max(best, int(d.get("restart_count", 0)))
print(best)
PY
}

# ── D1: the budget is a sliding window, not a lifetime count ────────────────

@test "D1: hours-apart restarts never exhaust the budget (window prunes them)" {
    # WINDOW=1s and the restart path's own 3s cancel pause means every restart is
    # already outside the previous one's window — the shape of a healthy run,
    # compressed. MAXR=3 with 5 restarts driven: a lifetime cap would stop at 3.
    arm false
    MAXR=3 WINDOW=1 SIGUNTIL=5 EXITCODE=0 run_wrapper

    [ "$(count_events iterate restart)" -eq 5 ]
    [ "$(count_events exit max-restarts)" -eq 0 ]
}

@test "D1 control: a genuine spin still trips the cap" {
    # Same wrapper, same stub — only the window changes. Without this leg,
    # "the cap no longer fires" cannot be distinguished from "the cap is dead".
    arm false
    MAXR=3 WINDOW=3600 SIGUNTIL=10 EXITCODE=0 run_wrapper

    [ "$(count_events exit max-restarts)" -eq 1 ]
    [ "$(count_events iterate restart)" -eq 3 ]
}

# ── D2: MAX_RESTARTS=N permits exactly N ───────────────────────────────────

@test "D2: MAX_RESTARTS=N performs N restarts, not N-1" {
    # The old guard incremented then tested -ge, so N=3 performed 2. The Nth
    # restart appearing in the log is the whole assertion.
    arm false
    MAXR=3 WINDOW=3600 SIGUNTIL=10 EXITCODE=0 run_wrapper

    [ "$(max_restart_count)" -eq 3 ]
    [ "$(count_events exit max-restarts)" -eq 1 ]
}

@test "D2: MAX_RESTARTS is read from config, not hardcoded" {
    # MAX_RESTARTS has been in FW_CONFIG_REGISTRY all along while claude-fw
    # hardcoded 5, so `fw config set MAX_RESTARTS` changed nothing. A different
    # value must now produce a different number of restarts.
    arm false
    MAXR=1 WINDOW=3600 SIGUNTIL=10 EXITCODE=0 run_wrapper

    [ "$(max_restart_count)" -eq 1 ]
    [ "$(count_events exit max-restarts)" -eq 1 ]
}

# ── D3: a clean exit does not tear down an armed run ───────────────────────

@test "D3: armed run re-arms on a clean exit with no restart signal" {
    # Two of three wrapper deaths on record are this branch, at 6h43m and 9h01m
    # after a healthy restart, both exit_code=0.
    arm true
    MAXR=2 WINDOW=3600 SIGUNTIL=0 EXITCODE=0 run_wrapper

    [ "$(count_events iterate rearm)" -eq 2 ]
    [ "$(count_events exit no-signal)" -eq 0 ]
}

@test "D3 control: a DISARMED run still exits on a clean exit" {
    # The operator's ability to quit. Must not regress.
    arm false
    MAXR=2 WINDOW=3600 SIGUNTIL=0 EXITCODE=0 run_wrapper

    [ "$(count_events exit no-signal)" -eq 1 ]
    [ "$(count_events iterate rearm)" -eq 0 ]
}

@test "D3 control: no state file at all behaves as disarmed" {
    # Absent/unreadable state must never be read as consent to keep running.
    rm -f "${TDIR}/.context/working/.continuous-mode.yaml"
    MAXR=2 WINDOW=3600 SIGUNTIL=0 EXITCODE=0 run_wrapper

    [ "$(count_events exit no-signal)" -eq 1 ]
    [ "$(count_events iterate rearm)" -eq 0 ]
}

# ── Sovereignty and runaway containment ────────────────────────────────────

@test "halt file outranks an armed run (Brake 1)" {
    arm true
    touch "${TDIR}/.context/working/.continuous-halt"
    MAXR=2 WINDOW=3600 SIGUNTIL=0 EXITCODE=0 run_wrapper

    [ "$(count_events exit halted)" -eq 1 ]
    [ "$(count_events iterate rearm)" -eq 0 ]
}

@test "re-arm cannot hot-spin: it spends the same windowed budget" {
    # A claude that exits instantly and forever is bounded by MAX_RESTARTS
    # within the window rather than looping unbounded.
    arm true
    MAXR=2 WINDOW=3600 SIGUNTIL=0 EXITCODE=0 run_wrapper

    [ "$(count_events iterate rearm)" -eq 2 ]
    [ "$(count_events exit max-restarts)" -eq 1 ]
}

@test "re-arm fires on a NON-zero exit too (a crash is not consent to stop)" {
    arm true
    MAXR=1 WINDOW=3600 SIGUNTIL=0 EXITCODE=7 run_wrapper

    [ "$(count_events iterate rearm)" -eq 1 ]
}

@test "--no-restart still short-circuits everything, armed or not" {
    arm true
    cd "$TDIR"
    run env PATH="${TDIR}/stubbin:${PATH}" HOME="$TDIR" \
        FW_NO_STARTUP_BANNER=1 FW_NO_TERMINATOR=1 \
        STUB_SIGNAL_UNTIL=0 STUB_EXIT_CODE=0 \
        timeout 60 bash "$WRAPPER" --no-restart

    [ "$(count_events exit auto-restart-disabled)" -eq 1 ]
    [ "$(count_events iterate rearm)" -eq 0 ]
}
