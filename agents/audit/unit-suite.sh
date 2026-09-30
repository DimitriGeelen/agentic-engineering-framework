#!/usr/bin/env bash
# agents/audit/unit-suite.sh — T-3302: scheduled tests/unit corpus run.
#
# Nothing ran tests/unit on a schedule: the daily audit's invariant-suite line
# covers tests/lint ONLY, so unit reds sat invisible until an adjacent run
# tripped over them (two found by accident on 2026-09-06 — OBS-359/OBS-360).
# This runner executes both legs of the unit corpus nightly and writes a
# machine-readable report that `fw audit` surfaces (check_unit_suite_report).
#
# Locking (A1): the runner takes its OWN overlap lock and skips (logged,
# exit 0) when it is already held. It must NEVER take the audit lock
# (.context/locks/audit.lock): tests/unit contains suites that spawn
# `audit.sh --section structure`, so a runner holding the audit lock would
# deadlock-starve the very suites it is running.
#
# Env overrides (used by tests/unit/t3302_unit_suite_schedule.bats to stay
# hermetic — the real corpus is NEVER run from the test):
#   FW_UNIT_SUITE_DIR         corpus dir      (default: <framework>/tests/unit)
#   FW_UNIT_SUITE_REPORT_DIR  report dir      (default: .context/audits/unit-suite)
#   FW_UNIT_SUITE_LOCK        lock file       (default: .context/locks/unit-suite.lock)
#   FW_UNIT_SUITE_TIMEOUT     total seconds   (default: 7200)
#   FW_UNIT_SUITE_PY_RESERVE  seconds reserved for the pytest leg (default: 1800)
#   FW_UNIT_SUITE_JOBS        files run concurrently (default: nproc/2, max 12)
#   FW_UNIT_SUITE_FILE_TIMEOUT per-file seconds cap (default: 900)
#
# Per-file execution (T-3602, OBS-587). The run used to be ONE `bats tests/unit`
# process under one 5400s cap. It hit the cap on every nightly from 2026-09-08
# (23/23), and a killed process says nothing about which file ate the time or
# which files it never reached. Now every file is its own job in a parallel
# pool, with its own timeout, and the report records per file: duration,
# completed / timed out / never reached. One pathological file costs its own
# cap, not the corpus, and it is NAMED in the report instead of silently
# swallowing the tail of the run. Each leg's deadline still bounds the pool:
# a job that would start past it is recorded as not run, never skipped silently.
#
# Budget split (T-3359). The two legs run sequentially against one wall-clock
# window, so leg 1 overrunning used to starve leg 2 down to the 1-second floor of
# _remaining(). Measured: four consecutive nightlies (2026-09-08..11) recorded
# `pytest: files: 201, tests: 0, exit: 124` — 2706 collected tests handed a
# 1-second budget, reported as a leg with zero failures. The reserve carves leg
# 2's share out of leg 1's cap up front, so starvation is not reachable.
#
# Exit: 0 clean (or skipped on held lock), 1 test failures, 2 leg could not run.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"

SUITE_DIR="${FW_UNIT_SUITE_DIR:-$FRAMEWORK_ROOT/tests/unit}"
REPORT_DIR="${FW_UNIT_SUITE_REPORT_DIR:-$PROJECT_ROOT/.context/audits/unit-suite}"
LOCK_FILE="${FW_UNIT_SUITE_LOCK:-$PROJECT_ROOT/.context/locks/unit-suite.lock}"
TOTAL_TIMEOUT="${FW_UNIT_SUITE_TIMEOUT:-7200}"
PY_RESERVE="${FW_UNIT_SUITE_PY_RESERVE:-1800}"
# Degenerate configs must not invert the split: never reserve the whole window.
if [ "$PY_RESERVE" -ge "$TOTAL_TIMEOUT" ]; then
    PY_RESERVE=$(( TOTAL_TIMEOUT / 2 ))
fi
[ "$PY_RESERVE" -lt 1 ] && PY_RESERVE=1

mkdir -p "$REPORT_DIR" "$(dirname "$LOCK_FILE")"
RUN_LOG="$REPORT_DIR/runs.log"

# ── Overlap lock: skip-if-held, logged, exit 0 ──────────────────────────────
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "$(date -u +%FT%TZ) SKIP lock-held $LOCK_FILE" >> "$RUN_LOG"
    echo "unit-suite: overlap lock held ($LOCK_FILE) — another run in progress; skipping"
    exit 0
fi

STARTED="$(date -u +%FT%TZ)"
START_EPOCH="$(date +%s)"
echo "$STARTED START suite=$SUITE_DIR timeout=${TOTAL_TIMEOUT}s" >> "$RUN_LOG"

_remaining() {
    local _left=$(( TOTAL_TIMEOUT - ( $(date +%s) - START_EPOCH ) ))
    [ "$_left" -lt 1 ] && _left=1
    echo "$_left"
}

# Leg 1's cap: the window MINUS the reserve held back for leg 2. This is the
# whole fix — leg 1 is never handed a budget it could spend on leg 2's behalf.
_remaining_reserved() {
    local _left=$(( TOTAL_TIMEOUT - PY_RESERVE - ( $(date +%s) - START_EPOCH ) ))
    [ "$_left" -lt 1 ] && _left=1
    echo "$_left"
}

JOBS="${FW_UNIT_SUITE_JOBS:-}"
if [ -z "$JOBS" ]; then
    JOBS=$(( $(nproc 2>/dev/null || echo 2) / 2 ))
    [ "$JOBS" -gt 12 ] && JOBS=12
fi
[ "$JOBS" -lt 1 ] && JOBS=1
FILE_TIMEOUT="${FW_UNIT_SUITE_FILE_TIMEOUT:-900}"
[ "$FILE_TIMEOUT" -lt 1 ] && FILE_TIMEOUT=1

BATS_BUDGET=0 PY_BUDGET=0
RESULTS="$(mktemp -d)"
mkdir -p "$RESULTS/bats" "$RESULTS/pytest"
trap 'rm -rf "$RESULTS"' EXIT

# _run_one <leg> <deadline-epoch> <file> — one pool job. Writes
# $RESULTS/<leg>/<basename>.out (tool output) and .meta, one line:
#   <status> <rc> <seconds>   status: done | file-timeout | run-ceiling | not-run
# "file-timeout" = killed by the per-file cap; "run-ceiling" = killed because
# the leg's deadline arrived first. Both are named in the report.
_run_one() {
    local leg="$1" deadline="$2" file="$3"
    local base out meta now left cap t0 rc st
    base="$(basename "$file")"
    out="$RESULTS/$leg/$base.out"; meta="$RESULTS/$leg/$base.meta"
    now=$(date +%s); left=$(( deadline - now ))
    if [ "$left" -lt 1 ]; then
        echo "not-run 0 0" > "$meta"; return 0
    fi
    cap="$FILE_TIMEOUT"; [ "$left" -lt "$cap" ] && cap="$left"
    t0=$(date +%s); rc=0
    if [ "$leg" = bats ]; then
        ( cd "$FRAMEWORK_ROOT" && timeout -k 10 "$cap" bats --tap "$file" ) \
            < /dev/null > "$out" 2>&1 || rc=$?
    else
        # --color=no + env scrub: FORCE_COLOR/PY_COLORS make pytest write ANSI into
        # the redirected file, and the ^FAILED name-parse finds nothing
        # (OBS-374 class — reproduced live under FORCE_COLOR=3, T-3302).
        ( cd "$FRAMEWORK_ROOT" && timeout -k 10 "$cap" \
            env -u FORCE_COLOR PY_COLORS=0 NO_COLOR=1 \
            python3 -m pytest "$file" -q -rf -p no:cacheprovider --color=no ) \
            < /dev/null > "$out" 2>&1 || rc=$?
    fi
    st=done
    # 143 = TERM from outside (the runner's signal trap stopping the pool).
    if [ "$rc" -eq 143 ]; then st=interrupted
    elif [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
        if [ "$cap" -lt "$FILE_TIMEOUT" ]; then st=run-ceiling; else st=file-timeout; fi
    fi
    echo "$st $rc $(( $(date +%s) - t0 ))" > "$meta"
}
export -f _run_one
export RESULTS FRAMEWORK_ROOT FILE_TIMEOUT

# _run_leg <leg> <deadline-epoch> <files...> — the pool. Files are fed
# longest-first when the previous report measured them (LPT scheduling: a
# 300s file started last would set the leg's wall time on its own).
_run_leg() {
    local leg="$1" deadline="$2"; shift 2
    printf '%s\n' "$@" \
    | T3602_PREV="$REPORT_DIR/LATEST.yaml" T3602_LEG="$leg" python3 -c '
import os, sys, yaml
files = [l.rstrip("\n") for l in sys.stdin if l.strip()]
dur = {}
try:
    d = yaml.safe_load(open(os.environ["T3602_PREV"])) or {}
    dur = ((d.get("legs") or {}).get(os.environ["T3602_LEG"]) or {}).get("file_durations") or {}
except Exception:
    pass
files.sort(key=lambda f: -float(dur.get(os.path.basename(f), 0) or 0))
sys.stdout.write("".join(f + "\n" for f in files))
' \
    | xargs -d '\n' -r -P "$JOBS" -n 1 bash -c '_run_one "$0" "$1" "$2"' "$leg" "$deadline" 9>&-
    # 9>&- : the jobs must not inherit the overlap-lock fd. A test that leaks a
    # daemon (measured: 10 fixture watchtowers orphaned by one run) would
    # otherwise hold the lock after the runner exits, and every later nightly
    # would SKIP as "lock held" — silently, forever (T-3602).
}

# _descendants <pid> — every descendant pid, parents before children.
_descendants() {
    local c
    for c in $(ps -o pid= --ppid "$1" 2>/dev/null); do echo "$c"; _descendants "$c"; done
}

# _stop_pool — stop a running leg the way its own timeouts would. Order
# matters: xargs first, so it cannot start the next file; then each per-file
# `timeout` wrapper, which forwards TERM to its whole process group. Killing the
# bats processes one by one instead lets bats' formatter report the in-flight
# test as `not ok` — a false red. Measured: under a real `timeout` kill bats
# prints no line for the in-flight test.
_stop_pool() {
    local all p comm
    all=$(_descendants "$1")
    for p in $all; do
        comm=$(ps -o comm= -p "$p" 2>/dev/null)
        [ "$comm" = xargs ] && kill -TERM "$p" 2>/dev/null
    done
    kill -TERM "$1" 2>/dev/null
    for p in $all; do
        comm=$(ps -o comm= -p "$p" 2>/dev/null)
        [ "$comm" = timeout ] && kill -TERM "$p" 2>/dev/null
    done
    # Let each _run_one write its record (timeout -k 10 bounds this).
    local i=0
    for p in $all; do
        while kill -0 "$p" 2>/dev/null && [ "$i" -lt 150 ]; do sleep 0.2; i=$((i+1)); done
    done
}

INTERRUPTED=0
LEG_PID=""
BATS_FILES=0 BATS_RC=0 BATS_ERROR="" PY_FILES=0 PY_RC=0 PY_ERROR=""
_on_signal() {
    trap '' TERM INT
    INTERRUPTED=1
    [ -n "$LEG_PID" ] && _stop_pool "$LEG_PID"
    wait 2>/dev/null
    # Every file with no verdict record was never reached (or was in flight):
    # record it as not-run so the report names it.
    local f leg
    for f in "$SUITE_DIR"/*.bats "$SUITE_DIR"/test_*.py; do
        [ -f "$f" ] || continue
        case "$f" in *.bats) leg=bats ;; *) leg=pytest ;; esac
        [ -f "$RESULTS/$leg/$(basename "$f").meta" ] || echo "not-run 0 0" > "$RESULTS/$leg/$(basename "$f").meta"
    done
    BATS_FILES=$(ls "$SUITE_DIR"/*.bats 2>/dev/null | wc -l | tr -d ' ')
    PY_FILES=$(ls "$SUITE_DIR"/test_*.py 2>/dev/null | wc -l | tr -d ' ')
    echo "$(date -u +%FT%TZ) INTERRUPTED by signal — writing partial report" >> "$RUN_LOG"
    _finish
}
trap _on_signal TERM INT

# _finish — aggregate per-file records, write the report, exit. Runs at the
# end of a normal run AND from the signal trap (T-3602): a run killed from
# outside (operator, harness, OOM) still leaves a report naming what it did
# not reach, instead of silently leaving yesterday's report as LATEST.
_finish() {
# Leg exit codes from the per-file records: 124 when any file produced no
# verdict (timed out or never reached), else 1 on any failing file, else 0.
_leg_rc() {
    local dir="$1" m st rc any_fail=0 any_to=0
    for m in "$dir"/*.meta; do
        [ -f "$m" ] || continue
        read -r st rc _ < "$m"
        case "$st" in
            done) [ "$rc" -ne 0 ] && [ "$rc" -ne 5 ] && any_fail=1 ;;  # pytest 5 = nothing collected
            *) any_to=1 ;;
        esac
    done
    if [ "$any_to" -eq 1 ]; then echo 124; elif [ "$any_fail" -eq 1 ]; then echo 1; else echo 0; fi
}
[ -z "$BATS_ERROR" ] && BATS_RC=$(_leg_rc "$RESULTS/bats")
[ -z "$PY_ERROR" ] && PY_RC=$(_leg_rc "$RESULTS/pytest")

FINISHED="$(date -u +%FT%TZ)"

# ── Report (A2): parse both legs, emit LATEST.yaml + dated sibling ──────────
# An empty fixture leg ("no files") is a measured-zero, not an error — only a
# missing TOOL or a non-zero leg exit makes the runner exit non-zero.
RUNNER_EXIT=0
{ [ "$BATS_RC" -ne 0 ] || [ "$PY_RC" -ne 0 ]; } && RUNNER_EXIT=1
{ [ "$BATS_ERROR" = "bats not installed" ] || [ "$PY_ERROR" = "pytest not installed" ]; } && RUNNER_EXIT=2

T3302_STARTED="$STARTED" T3302_FINISHED="$FINISHED" \
T3302_SUITE_DIR="$SUITE_DIR" T3302_TIMEOUT="$TOTAL_TIMEOUT" \
T3302_RUNNER_EXIT="$RUNNER_EXIT" \
T3302_BATS_FILES="$BATS_FILES" T3302_BATS_RC="$BATS_RC" T3302_BATS_ERROR="$BATS_ERROR" \
T3302_PY_FILES="$PY_FILES" T3302_PY_RC="$PY_RC" T3302_PY_ERROR="$PY_ERROR" \
T3302_BATS_BUDGET="$BATS_BUDGET" T3302_PY_BUDGET="$PY_BUDGET" \
T3302_PY_RESERVE="$PY_RESERVE" T3602_JOBS="$JOBS" T3602_FILE_TIMEOUT="$FILE_TIMEOUT" \
T3302_REPORT_DIR="$REPORT_DIR" T3602_INTERRUPTED="$INTERRUPTED" T3602_WALL=$(( $(date +%s) - START_EPOCH )) \
python3 - "$RESULTS" <<'PY'
import glob, os, re, sys, yaml, datetime

results = sys.argv[1]
env = os.environ

def _int(name):
    return int(env.get(name) or 0)

def _leg(leg):
    """Per-file records -> leg summary (T-3602 schema v2)."""
    s = {"tests": 0, "failed": [], "skipped": 0, "completed": 0,
         "timed_out": [], "not_run": [], "durations": {}}
    for meta in sorted(glob.glob(os.path.join(results, leg, "*.meta"))):
        name = os.path.basename(meta)[:-len(".meta")]
        st, rc, secs = (open(meta).read().split() + ["", "0", "0"])[:3]
        rc, secs = int(rc), int(secs)
        if st == "not-run":
            s["not_run"].append(name)
            continue
        s["durations"][name] = secs
        if st == "file-timeout":
            s["timed_out"].append(name)
        elif st == "run-ceiling":
            s["timed_out"].append(name + " (killed at run ceiling)")
        elif st == "interrupted":
            s["timed_out"].append(name + " (interrupted)")
        else:
            s["completed"] += 1
        try:
            out = open(os.path.join(results, leg, name + ".out"), errors="replace").read()
        except OSError:
            out = ""
        before = len(s["failed"])
        if leg == "bats":
            # bats TAP: 'ok N name', 'not ok N name', skips 'ok N name # skip …'.
            # A test killed by a timeout never prints 'not ok': every recorded
            # failure finished and failed (T-3602 — the premise of the audit fix).
            lines = out.splitlines()
            s["tests"] += sum(1 for l in lines if re.match(r"^(not )?ok ", l))
            s["skipped"] += sum(1 for l in lines if re.match(r"^ok .*# skip", l))
            s["failed"] += ["%s: %s" % (name, re.sub(r"^not ok \d+ ", "", l).strip())
                            for l in lines if l.startswith("not ok ")]
        else:
            # pytest -q -rf: 'N passed, M failed, K skipped in …'; failures as
            # 'FAILED path::test' (and collection 'ERROR path…').
            def _count(word):
                m = re.search(r"(\d+) " + word, out)
                return int(m.group(1)) if m else 0
            c = [_count("passed"), _count("failed"), _count("skipped"), _count("error")]
            s["tests"] += sum(c)
            s["skipped"] += c[2]
            s["failed"] += [l.split(" - ")[0].split(None, 1)[1].strip()
                            for l in out.splitlines()
                            if l.startswith(("FAILED ", "ERROR "))]
        # A file that exited non-zero on its own but recorded no failing test
        # (setup_file error, syntax error, import error) is still red.
        if st == "done" and rc not in (0, 5) and len(s["failed"]) == before:
            s["failed"].append("%s: exited rc=%d with no failing test recorded" % (name, rc))
    return s

B, P = _leg("bats"), _leg("pytest")

# timed_out = the RUN ceiling cut something off (a file killed by it, or never
# reached). A per-file cap alone is not a run timeout; it is named per file.
timed_out = any(B["not_run"] or P["not_run"]) or any(
    t.endswith(("(killed at run ceiling)", "(interrupted)"))
    for t in B["timed_out"] + P["timed_out"])

def _leg_report(s, leg):
    return {
        "files": _int("T3302_%s_FILES" % leg),
        "files_completed": s["completed"],
        "files_timed_out": s["timed_out"],
        "files_not_run": len(s["not_run"]),
        "files_not_run_names": s["not_run"],
        "budget_seconds": _int("T3302_%s_BUDGET" % leg),
        "tests": s["tests"],
        "failed_count": len(s["failed"]),
        "skipped": s["skipped"],
        "exit": _int("T3302_%s_RC" % leg),
        "failed": s["failed"],
        "error": env.get("T3302_%s_ERROR" % leg) or None,
        # T-3602: where the time goes. Also feeds next run's LPT ordering.
        "file_durations": dict(sorted(s["durations"].items(), key=lambda kv: -kv[1])),
    }

report = {
    "schema": "unit-suite-report-v2",
    "task": "T-3302",
    "started": env["T3302_STARTED"],
    "finished": env["T3302_FINISHED"],
    "suite_dir": env["T3302_SUITE_DIR"],
    "timeout_seconds": _int("T3302_TIMEOUT"),
    # T-3359: the reserve carved out for leg 2 up front. Recorded so a reader can
    # tell which split produced the numbers below.
    "pytest_reserve_seconds": _int("T3302_PY_RESERVE"),
    # T-3602: pool shape and measured wall time, so the budget trend is visible.
    "jobs": _int("T3602_JOBS"),
    "file_timeout_seconds": _int("T3602_FILE_TIMEOUT"),
    "wall_seconds": _int("T3602_WALL"),
    "timed_out": timed_out,
    # T-3602: killed from outside before it could finish (signal trap).
    "interrupted": env.get("T3602_INTERRUPTED") == "1",
    "runner_exit": _int("T3302_RUNNER_EXIT"),
    "legs": {
        "bats": _leg_report(B, "BATS"),
        "pytest": _leg_report(P, "PY"),
    },
}

report_dir = env["T3302_REPORT_DIR"]
dated = os.path.join(
    report_dir, datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d") + ".yaml")
latest = os.path.join(report_dir, "LATEST.yaml")
text = yaml.safe_dump(report, sort_keys=False, default_flow_style=False)
for path in (dated, latest):
    tmp = path + ".tmp"
    with open(tmp, "w") as fh:
        fh.write(text)
    os.replace(tmp, path)
PY
WRITE_RC=$?
if [ "$WRITE_RC" -ne 0 ]; then
    echo "$FINISHED ERROR report-write-failed rc=$WRITE_RC" >> "$RUN_LOG"
    echo "unit-suite: report write FAILED (rc=$WRITE_RC)" >&2
    exit 2
fi

echo "$FINISHED DONE runner_exit=$RUNNER_EXIT bats_rc=$BATS_RC pytest_rc=$PY_RC wall=$(( $(date +%s) - START_EPOCH ))s jobs=$JOBS" >> "$RUN_LOG"
echo "unit-suite: done runner_exit=$RUNNER_EXIT (bats: $BATS_FILES file(s) rc=$BATS_RC; pytest: $PY_FILES file(s) rc=$PY_RC) — report: $REPORT_DIR/LATEST.yaml"
exit "$RUNNER_EXIT"
}

# ── Leg 1: bats (tests/unit/*.bats) ─────────────────────────────────────────
BATS_LIST=()
while IFS= read -r _f; do BATS_LIST+=("$_f"); done < <(ls "$SUITE_DIR"/*.bats 2>/dev/null)
BATS_FILES=${#BATS_LIST[@]}
BATS_RC=0 BATS_ERROR=""
if [ "$BATS_FILES" -eq 0 ]; then
    BATS_ERROR="no *.bats files in $SUITE_DIR"
elif ! command -v bats >/dev/null 2>&1; then
    BATS_ERROR="bats not installed"
else
    BATS_BUDGET="$(_remaining_reserved)"
    _run_leg bats $(( $(date +%s) + BATS_BUDGET )) "${BATS_LIST[@]}" &
    LEG_PID=$!; wait "$LEG_PID"; LEG_PID=""
fi

# ── Leg 2: pytest (tests/unit/test_*.py) ────────────────────────────────────
PY_LIST=()
while IFS= read -r _f; do PY_LIST+=("$_f"); done < <(ls "$SUITE_DIR"/test_*.py 2>/dev/null)
PY_FILES=${#PY_LIST[@]}
PY_RC=0 PY_ERROR=""
if [ "$PY_FILES" -eq 0 ]; then
    PY_ERROR="no test_*.py files in $SUITE_DIR"
elif ! python3 -c 'import pytest' >/dev/null 2>&1; then
    PY_ERROR="pytest not installed"
else
    PY_BUDGET="$(_remaining)"
    _run_leg pytest $(( $(date +%s) + PY_BUDGET )) "${PY_LIST[@]}" &
    LEG_PID=$!; wait "$LEG_PID"; LEG_PID=""
fi

_finish
