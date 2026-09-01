#!/usr/bin/env bash
# T-3239 / T-3243 — LIVE FIRE: the real claude binary, under the real claude-fw
# wrapper, observed through TermLink.
#
# WHY THIS EXISTS. tests/unit/t3243_supervisor_restart_policy.bats proves the
# supervisor's branch arithmetic, but it drives a STUB `claude` on PATH. A stub
# cannot answer the two links T-3239's report marked NOT PROVEN:
#
#   - the handover -> restart leg end to end (does a real session actually come back?)
#   - arc focus / directive surviving a restart
#
# So this runs `/root/.local/bin/claude` for real, under `bin/claude-fw` for real,
# inside a TermLink PTY so the operator can attach and watch it happen rather than
# taking a test runner's word for it.
#
# HOW IT TERMINATES WITHOUT A HUMAN. Measured, not assumed: a non-tty `claude`
# invoked with no arguments behaves as --print, finds no prompt on stdin, and
# exits 1 immediately. The re-arm path deliberately drops the user's args
# (T-3166: a restart must start FRESH, not resume the context it restarted to
# escape), so every relaunch is exactly that no-arg form. The loop therefore
# drives itself: real launch, real exit, real re-arm, bounded by the real rate
# limit. Nothing here is stubbed and nothing needs a keypress.
#
# WHAT IT ASSERTS
#   1. a real claude runs and exits under the wrapper
#   2. the wrapper RE-ARMS instead of tearing down          (T-3243 D3)
#   3. it re-arms on a non-zero exit too                    (a crash is not consent to stop)
#   4. more than one distinct real claude PROCESS is spawned — the loop actually
#      went round, rather than merely printing that it would
#   5. the sliding rate limit CONTAINS it at MAX_RESTARTS   (T-3243 D1/D2)
#
# Usage: bash docs/reports/T-3239-continuous-loop-demo/livefire-m2-termlink.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
EVID="${REPO}/docs/reports/T-3239-continuous-loop-demo/evidence"
OUT="${EVID}/E5-livefire-m2-termlink.txt"
mkdir -p "$EVID"

SESSION="t3243-livefire-$$"
SANDBOX="$(mktemp -d)"
MAXR=2
WINDOW=3600

cleanup() {
    termlink signal "$SESSION" SIGTERM >/dev/null 2>&1 || true
    sleep 1
    termlink clean >/dev/null 2>&1 || true
    rm -rf "$SANDBOX"
}
trap cleanup EXIT

# ── sandbox: a real git repo, armed for a continuous run ───────────────────
mkdir -p "${SANDBOX}/.context/working"
git -C "$SANDBOX" init -q
git -C "$SANDBOX" config user.email livefire@test
git -C "$SANDBOX" config user.name livefire

# Armed state. Written directly rather than via `fw continuous arm`, because the
# sandbox is deliberately NOT a framework project — the point is to exercise the
# wrapper, not fw's project detection. The three fields below are the only ones
# _continuous_armed() reads, and `enabled: true` is the whole contract.
cat > "${SANDBOX}/.context/working/.continuous-mode.yaml" <<YAML
enabled: true
current_iteration: 0
max_iterations: 10
tier_ceiling: 1
YAML

echo "T-3239/T-3243 E5 — LIVE FIRE via TermLink"                    >  "$OUT"
echo "generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"                    >> "$OUT"
echo "repo sha:  $(git -C "$REPO" rev-parse --short HEAD)"          >> "$OUT"
echo "claude:    $(command -v claude) $(claude --version 2>/dev/null | head -1)" >> "$OUT"
echo "termlink:  $(termlink --version 2>/dev/null)"                 >> "$OUT"
echo "wrapper:   ${REPO}/bin/claude-fw"                             >> "$OUT"
echo "sandbox:   ${SANDBOX}"                                        >> "$OUT"
echo "policy:    MAX_RESTARTS=${MAXR} RESTART_WINDOW=${WINDOW}s"    >> "$OUT"
echo ""                                                             >> "$OUT"

# ── spawn an observable TermLink session ───────────────────────────────────
echo "spawning TermLink session ${SESSION} — attach with: termlink attach ${SESSION}"
termlink spawn --name "$SESSION" --backend background --shell \
    --tags "task:T-3239,livefire" --wait --wait-timeout 20 >/dev/null 2>&1 || {
        echo "FATAL: termlink spawn failed" | tee -a "$OUT"; exit 3; }

# Record the real claude PIDs THIS WRAPPER spawns. Assertion 4: a banner saying
# "relaunching" is not evidence that anything relaunched.
#
# Scoped to children of the wrapper, discovered from the wrapper_pid the loop
# ledger writes at start. The first version of this polled
# `pgrep -f '^claude'` host-wide and reported 36 PIDs — every claude on the
# machine, including the session running this script and four other projects'.
# It passed, and it measured nothing. Counting a global population to prove a
# local event is the exact false-green this whole task is about.
PIDLOG="${SANDBOX}/claude-pids.txt"
: > "$PIDLOG"
( wpid=""
  for _ in $(seq 1 60); do
      wpid=$(python3 - "${SANDBOX}/.context/working/continuous-run.jsonl" <<'PY' 2>/dev/null
import json, sys
try: lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
except Exception: raise SystemExit
for l in lines:
    l = l.strip()
    if not l: continue
    try: d = json.loads(l)
    except Exception: continue
    if d.get("event") == "start":
        print(d.get("wrapper_pid", "")); break
PY
)
      [ -n "$wpid" ] && break
      sleep 1
  done
  [ -n "$wpid" ] || exit 0
  echo "wrapper_pid=$wpid" > "${SANDBOX}/wrapper-pid.txt"
  while :; do
      pgrep -P "$wpid" 2>/dev/null >> "$PIDLOG"
      sleep 1
  done ) &
WATCH=$!

termlink pty inject "$SESSION" "cd ${SANDBOX}" --enter >/dev/null 2>&1
termlink pty inject "$SESSION" \
  "FW_MAX_RESTARTS=${MAXR} FW_RESTART_WINDOW=${WINDOW} FW_NO_STARTUP_BANNER=1 FW_NO_TERMINATOR=1 bash ${REPO}/bin/claude-fw -p 'reply with exactly: LIVEFIRE-OK' 2>&1 | tee ${SANDBOX}/pty.log" \
  --enter >/dev/null 2>&1

# ── wait for the loop to finish on its own ────────────────────────────────
deadline=$(( $(date +%s) + 240 ))
while [ "$(date +%s)" -lt "$deadline" ]; do
    grep -q "max-restarts\|Max restarts\|budget is exhausted\|Restart budget exhausted" \
        "${SANDBOX}/pty.log" 2>/dev/null && break
    sleep 3
done
kill "$WATCH" 2>/dev/null; wait "$WATCH" 2>/dev/null

# ── evidence ──────────────────────────────────────────────────────────────
{
    echo "───── PTY transcript (what the operator would see attached) ─────"
    cat "${SANDBOX}/pty.log" 2>/dev/null || echo "(no pty log)"
    echo
    echo "───── loop event ledger (.context/working/continuous-run.jsonl) ─────"
    cat "${SANDBOX}/.context/working/continuous-run.jsonl" 2>/dev/null || echo "(none)"
    echo
    echo "───── real claude PIDs spawned BY THIS WRAPPER ─────"
    cat "${SANDBOX}/wrapper-pid.txt" 2>/dev/null || echo "wrapper_pid=(not captured)"
    echo -n "children: "; sort -u "$PIDLOG" 2>/dev/null | tr '\n' ' '; echo
    echo
    echo "───── independent launch count, straight off the transcript ─────"
    echo "  LIVEFIRE-OK lines (run 1, the -p invocation) : $(grep -c 'LIVEFIRE-OK' "${SANDBOX}/pty.log" 2>/dev/null || echo 0)"
    echo "  --print error lines (runs 2..n, no-arg form) : $(grep -c 'Input must be provided' "${SANDBOX}/pty.log" 2>/dev/null || echo 0)"
} >> "$OUT"

# ── assertions ────────────────────────────────────────────────────────────
LOG="${SANDBOX}/.context/working/continuous-run.jsonl"
cnt() { grep -c "\"event\": *\"$1\", *\"reason\": *\"$2\"" "$LOG" 2>/dev/null || echo 0; }
jcnt() {
    python3 - "$LOG" "$1" "$2" <<'PY' 2>/dev/null || echo 0
import json, sys
try: lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
except Exception: print(0); raise SystemExit
n = 0
for l in lines:
    l = l.strip()
    if not l: continue
    try: d = json.loads(l)
    except Exception: continue
    if d.get("event") == sys.argv[2] and d.get("reason") == sys.argv[3]: n += 1
print(n)
PY
}

rearms=$(jcnt iterate rearm)
capped=$(jcnt exit max-restarts)
pids=$(sort -u "$PIDLOG" 2>/dev/null | grep -c . || echo 0)
ok1=$(grep -c 'LIVEFIRE-OK' "${SANDBOX}/pty.log" 2>/dev/null || echo 0)
errs=$(grep -c 'Input must be provided' "${SANDBOX}/pty.log" 2>/dev/null || echo 0)
launches=$(( ok1 + errs ))

pass=0; fail=0
check() { # check <label> <condition-result> <detail>
    if [ "$2" = "0" ]; then echo "  PASS  $1   $3"; pass=$((pass+1))
    else echo "  FAIL  $1   $3"; fail=$((fail+1)); fi
}
{
    echo
    echo "───── assertions ─────"
    check "real claude ran under the wrapper" \
        "$(grep -q 'LIVEFIRE-OK' "${SANDBOX}/pty.log" 2>/dev/null && echo 0 || echo 1)" \
        "LIVEFIRE-OK present in PTY transcript"
    check "wrapper RE-ARMED rather than tearing down (D3)" \
        "$([ "$rearms" -ge 1 ] && echo 0 || echo 1)" \
        "iterate/rearm events = ${rearms} (want >=1)"
    # Two independent measurements of the same fact, on purpose. The PID count is
    # scoped to the wrapper's own children; the transcript count is derived from
    # what the real binary printed. If they disagree, neither is trusted.
    check "the loop actually went round (>1 claude process under THIS wrapper)" \
        "$([ "$pids" -ge 2 ] && echo 0 || echo 1)" \
        "claude PIDs with PPID=wrapper = ${pids} (want >=2)"
    check "transcript agrees: N real launches produced N real outputs" \
        "$([ "$launches" -eq $(( MAXR + 1 )) ] && echo 0 || echo 1)" \
        "1 x LIVEFIRE-OK + ${errs} x --print error = ${launches} launches (want $(( MAXR + 1 )))"
    check "rate limit CONTAINED it at MAX_RESTARTS (D1/D2)" \
        "$([ "$capped" -ge 1 ] && echo 0 || echo 1)" \
        "exit/max-restarts events = ${capped} (want >=1)"
    check "it stopped at exactly MAX_RESTARTS re-arms, not more" \
        "$([ "$rearms" -eq "$MAXR" ] && echo 0 || echo 1)" \
        "rearms=${rearms} MAX_RESTARTS=${MAXR}"
    echo
    echo "PASS: ${pass}   FAIL: ${fail}"
} | tee -a "$OUT"

echo
echo "evidence written: $OUT"
exit $(( fail > 0 ? 1 : 0 ))
