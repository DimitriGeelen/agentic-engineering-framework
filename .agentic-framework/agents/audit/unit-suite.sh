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

BATS_OUT="$(mktemp)" PY_OUT="$(mktemp)"
trap 'rm -f "$BATS_OUT" "$PY_OUT"' EXIT

# ── Leg 1: bats (tests/unit/*.bats) ─────────────────────────────────────────
BATS_FILES=$(ls "$SUITE_DIR"/*.bats 2>/dev/null | wc -l | tr -d ' ')
BATS_RC=0 BATS_ERROR=""
if [ "$BATS_FILES" -eq 0 ]; then
    BATS_ERROR="no *.bats files in $SUITE_DIR"
elif ! command -v bats >/dev/null 2>&1; then
    BATS_ERROR="bats not installed"
else
    ( cd "$FRAMEWORK_ROOT" && timeout "$(_remaining)" bats "$SUITE_DIR" ) \
        > "$BATS_OUT" 2>&1 || BATS_RC=$?
fi

# ── Leg 2: pytest (tests/unit/test_*.py) ────────────────────────────────────
PY_FILES=$(ls "$SUITE_DIR"/test_*.py 2>/dev/null | wc -l | tr -d ' ')
PY_RC=0 PY_ERROR=""
if [ "$PY_FILES" -eq 0 ]; then
    PY_ERROR="no test_*.py files in $SUITE_DIR"
elif ! python3 -c 'import pytest' >/dev/null 2>&1; then
    PY_ERROR="pytest not installed"
else
    # --color=no + env scrub: FORCE_COLOR/PY_COLORS make pytest write ANSI into
    # the redirected file, and the ^FAILED name-parse below finds nothing
    # (OBS-374 class — reproduced live under FORCE_COLOR=3, T-3302).
    ( cd "$FRAMEWORK_ROOT" && timeout "$(_remaining)" \
        env -u FORCE_COLOR PY_COLORS=0 NO_COLOR=1 \
        python3 -m pytest "$SUITE_DIR" -q -rf -p no:cacheprovider --color=no ) \
        > "$PY_OUT" 2>&1 || PY_RC=$?
fi

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
T3302_REPORT_DIR="$REPORT_DIR" \
python3 - "$BATS_OUT" "$PY_OUT" <<'PY'
import os, re, sys, yaml, datetime

bats_out = open(sys.argv[1], errors="replace").read()
py_out = open(sys.argv[2], errors="replace").read()
env = os.environ

def _int(name):
    return int(env.get(name) or 0)

# bats TAP: 'ok N name', 'not ok N name', skips render as 'ok N name # skip …'
bats_lines = bats_out.splitlines()
bats_tests = sum(1 for l in bats_lines if re.match(r"^(not )?ok ", l))
bats_failed = [re.sub(r"^not ok \d+ ", "", l).strip()
               for l in bats_lines if l.startswith("not ok ")]
bats_skipped = sum(1 for l in bats_lines if re.match(r"^ok .*# skip", l))

# pytest -q -rf: summary 'N passed, M failed, K skipped in …';
# failures listed as 'FAILED path::test' (and collection 'ERROR path…').
def _count(word):
    m = re.search(r"(\d+) " + word, py_out)
    return int(m.group(1)) if m else 0

py_passed, py_failed_n, py_skipped, py_errors = (
    _count("passed"), _count("failed"), _count("skipped"), _count("error"))
py_failed = [l.split(" - ")[0].split(None, 1)[1].strip()
             for l in py_out.splitlines()
             if l.startswith(("FAILED ", "ERROR "))]

timed_out = _int("T3302_BATS_RC") == 124 or _int("T3302_PY_RC") == 124

report = {
    "schema": "unit-suite-report-v1",
    "task": "T-3302",
    "started": env["T3302_STARTED"],
    "finished": env["T3302_FINISHED"],
    "suite_dir": env["T3302_SUITE_DIR"],
    "timeout_seconds": _int("T3302_TIMEOUT"),
    "timed_out": timed_out,
    "runner_exit": _int("T3302_RUNNER_EXIT"),
    "legs": {
        "bats": {
            "files": _int("T3302_BATS_FILES"),
            "tests": bats_tests,
            "failed_count": len(bats_failed),
            "skipped": bats_skipped,
            "exit": _int("T3302_BATS_RC"),
            "failed": bats_failed,
            "error": env.get("T3302_BATS_ERROR") or None,
        },
        "pytest": {
            "files": _int("T3302_PY_FILES"),
            "tests": py_passed + py_failed_n + py_skipped + py_errors,
            "failed_count": len(py_failed) or py_failed_n + py_errors,
            "skipped": py_skipped,
            "exit": _int("T3302_PY_RC"),
            "failed": py_failed,
            "error": env.get("T3302_PY_ERROR") or None,
        },
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

echo "$FINISHED DONE runner_exit=$RUNNER_EXIT bats_rc=$BATS_RC pytest_rc=$PY_RC" >> "$RUN_LOG"
echo "unit-suite: done runner_exit=$RUNNER_EXIT (bats: $BATS_FILES file(s) rc=$BATS_RC; pytest: $PY_FILES file(s) rc=$PY_RC) — report: $REPORT_DIR/LATEST.yaml"
exit "$RUNNER_EXIT"
