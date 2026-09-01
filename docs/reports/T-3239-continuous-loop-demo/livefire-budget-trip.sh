#!/usr/bin/env bash
# T-3239 E7 — THE headline mechanic, live: a real session crosses the real budget
# threshold and the loop brings it back.
#
# This is the one link nothing has yet proven on a real session:
#
#   E3  proved the trigger fires — on SYNTHETIC transcripts I wrote.
#   E5  proved the wrapper relaunches a real claude — but I FORCED the exits.
#   E7  the real gauge reads a real transcript, crosses a real threshold,
#       writes the signal, and the real wrapper brings a real session back.
#
# HOW THE THRESHOLD IS REACHED HONESTLY. Not by faking a transcript — by shrinking
# the window. FW_CONTEXT_WINDOW is a configured dial (fw doctor says so in as many
# words: "the cap is a configured dial, not this model's window"). Setting it to a
# few thousand tokens means a genuine session, doing genuine work, genuinely
# crosses 95% of it on its first turn. Every component is the shipped one; only
# the dial moves. That is the difference between compressing a test and faking it.
#
# THE SANDBOX IS A REAL PROJECT. `fw init` wires the real hooks — 9 PreToolUse,
# 3 SessionStart, 7 PostToolUse. budget-gate is not invoked by this script; it is
# invoked by Claude Code, because settings.json says so.
#
# Usage: bash docs/reports/T-3239-continuous-loop-demo/livefire-budget-trip.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
EVID="${REPO}/docs/reports/T-3239-continuous-loop-demo/evidence"
OUT="${EVID}/E7-livefire-budget-trip.txt"
mkdir -p "$EVID"

SANDBOX="$(mktemp -d)/proj"
WINDOW=4000        # critical at 95% = 3800 tokens; any real turn clears it
MAXR=2
cleanup() { [ "${KEEP_SANDBOX:-0}" = "1" ] && { echo "KEPT: $SANDBOX"; return 0; }; rm -rf "$(dirname "$SANDBOX")"; }
trap cleanup EXIT

mkdir -p "$SANDBOX"
git -C "$SANDBOX" init -q
git -C "$SANDBOX" config user.email livefire@test
git -C "$SANDBOX" config user.name livefire

echo "initialising a REAL framework project (fw init) …"
( cd "$SANDBOX" && timeout 240 "${REPO}/bin/fw" init . >/dev/null 2>&1 )
git -C "$SANDBOX" add -A >/dev/null 2>&1
git -C "$SANDBOX" commit -qm "baseline" >/dev/null 2>&1

HOOKS=$(python3 -c "
import json;d=json.load(open('${SANDBOX}/.claude/settings.json'));h=d.get('hooks',{})
print(' '.join('%s=%d'%(k,len(v)) for k,v in sorted(h.items())))" 2>/dev/null)

# Arm a continuous run through the REAL verb, in the REAL project.
( cd "$SANDBOX" && timeout 60 ./.agentic-framework/bin/fw continuous arm \
    --hours 24 --iterations 5 --tier-ceiling 1 \
    --directive "Continue the demo arc. Reply with exactly: BEACON-E7" ) >/dev/null 2>&1
printf 'current_arc: demo-arc\n' > "${SANDBOX}/.context/working/arc-focus.yaml"

ARMED=$(grep -c '^enabled: true' "${SANDBOX}/.context/working/.continuous-mode.yaml" 2>/dev/null || echo 0)

{
  echo "T-3239 E7 — LIVE budget trip: real session, real gauge, real restart"
  echo "generated:  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "repo sha:   $(git -C "$REPO" rev-parse --short HEAD)"
  echo "claude:     $(claude --version 2>/dev/null | head -1)"
  echo "sandbox:    ${SANDBOX}   (real fw init)"
  echo "hooks:      ${HOOKS}"
  echo "dial:       FW_CONTEXT_WINDOW=${WINDOW}  (critical at 95% = $((WINDOW*95/100)))"
  echo "policy:     MAX_RESTARTS=${MAXR}"
  echo "armed:      ${ARMED}  (1 = fw continuous arm succeeded)"
  echo
} > "$OUT"

echo "running real claude under real claude-fw with a ${WINDOW}-token dial …"
cd "$SANDBOX"
FW_CONTEXT_WINDOW="$WINDOW" FW_MAX_RESTARTS="$MAXR" FW_RESTART_WINDOW=3600 \
FW_NO_STARTUP_BANNER=1 \
timeout 300 bash "${REPO}/bin/claude-fw" \
    -p "Run the bash command 'echo hello' and then reply with exactly: BEACON-E7" \
    > "${SANDBOX}/pty.log" 2>&1
WRC=$?

LOG="${SANDBOX}/.context/working/continuous-run.jsonl"
{
  echo "───── wrapper transcript ─────"
  sed -e 's/\x1b\[[0-9;]*m//g' "${SANDBOX}/pty.log" 2>/dev/null | head -60
  echo
  echo "───── budget gauge as the framework recorded it ─────"
  cat "${SANDBOX}/.context/working/.budget-status" 2>/dev/null || echo "(none)"
  echo
  echo "───── restart signal (written by budget-gate, consumed by claude-fw) ─────"
  ls -la "${SANDBOX}/.context/working/.restart-requested" 2>/dev/null || echo "(consumed or never written)"
  echo
  echo "───── loop event ledger ─────"
  cat "$LOG" 2>/dev/null || echo "(none)"
  echo
  echo "───── continuous-mode state after the run ─────"
  cat "${SANDBOX}/.context/working/.continuous-mode.yaml" 2>/dev/null || echo "(none)"
  echo
  echo "wrapper exit code: ${WRC}"
} >> "$OUT"

jcnt() {
  python3 - "$LOG" "$1" "$2" <<'PY' 2>/dev/null || echo 0
import json, sys
try: lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
except Exception: print(0); raise SystemExit
n=0
for l in lines:
    l=l.strip()
    if not l: continue
    try: d=json.loads(l)
    except Exception: continue
    if d.get("event")==sys.argv[2] and d.get("reason")==sys.argv[3]: n+=1
print(n)
PY
}

restarts=$(jcnt iterate restart)
level=$(python3 -c "
import json
try: print(json.load(open('${SANDBOX}/.context/working/.budget-status')).get('level','?'))
except Exception: print('?')" 2>/dev/null)
iter=$(grep '^current_iteration:' "${SANDBOX}/.context/working/.continuous-mode.yaml" 2>/dev/null | tr -dc '0-9')

pass=0; fail=0
chk() { if [ "$2" = 0 ]; then echo "  PASS  $1  $3"; pass=$((pass+1)); else echo "  FAIL  $1  $3"; fail=$((fail+1)); fi; }
{
  echo
  echo "───── assertions ─────"
  chk "the sandbox is a real framework project" \
      "$([ -n "$HOOKS" ] && echo 0 || echo 1)" "hooks: ${HOOKS}"
  chk "the real gauge reached critical on a real session" \
      "$([ "$level" = critical ] && echo 0 || echo 1)" "budget level = ${level} (want critical)"
  chk "the budget trip produced a REAL restart" \
      "$([ "${restarts:-0}" -ge 1 ] && echo 0 || echo 1)" "iterate/restart events = ${restarts} (want >=1)"
  chk "the loop's iteration counter advanced" \
      "$([ "${iter:-0}" -ge 1 ] && echo 0 || echo 1)" "current_iteration = ${iter}"
  echo
  echo "PASS: ${pass}  FAIL: ${fail}"
} | tee -a "$OUT"

echo; echo "evidence: $OUT"
exit $(( fail > 0 ? 1 : 0 ))
