#!/usr/bin/env bash
# T-3239 E8 — THE headline mechanic, live and POSITIVE: a real session crosses the
# real budget threshold, the real gate writes the signal, and the real wrapper
# brings a real session back.
#
# E8 exists because E7 FAILED, and the reason it failed was not the reason it was
# built to test. E7 dialled FW_CONTEXT_WINDOW to 4000 and ran a real session that
# unquestionably used more than 3800 tokens. The gauge still read 0/ok.
#
# THREE dials stand between a short real session and the budget trip. Each is
# legitimate production tuning; each was found by measuring, in this order, and
# only the third one was visible from the E7 evidence alone. All three are
# registry keys (lib/config.sh), so all three move the same honest way — shrink a
# configured dial, never fake a transcript.
#
#   1. FW_CONTEXT_WINDOW (E7 moved this one)
#      The threshold itself. 4000 → critical at 3800, which any real framework
#      turn clears; this CLAUDE.md alone dwarfs it.
#
#   2. FW_BUDGET_STATUS_MAX_AGE (E8 delta #1) — default 90
#      post-compact-resume.sh:82-90 seeds .budget-status {"level":"ok","tokens":0}
#      at EVERY SessionStart (deliberate, T-1087: it stops the slow path misreading
#      the pre-compact tail of a resumed JSONL). budget-gate.sh:247 then serves that
#      seed from its fast path for 90s without opening the transcript. E7's entire
#      run was ~32s, so it was blind by construction for its whole life. Moving
#      this alone changed .budget-status's `source` from post-compact-resume to
#      budget-gate — the gate started measuring — and it still read 0, which is
#      what exposed the third dial.
#
#   3. FW_BUDGET_RECHECK_INTERVAL (E8 delta #2) — default 5
#      budget-gate.sh:317 re-reads the transcript only when GATE_COUNT is 1 or
#      1 mod 5. Measured from the kept transcript: the four usage entries landed
#      at 11:53:59-11:54:07, but call 1 fired BEFORE two of them existed, and
#      lib/context_tokens.py:97 returns 0 below two in-scope entries ("fail-open,
#      not fail-guess"). Calls 2-5 then skipped the read entirely, and the session
#      ended around call 4. The gate never looked again after the tokens arrived.
#
#   4. THE FRAMEWORK'S OWN TASK GATE (not a dial — a task)
#      With 1-3 moved, the gate counter still read exactly 1: budget-gate fired
#      once in the whole run. A fresh `fw init` sandbox has `current_task: null`,
#      so check-active-task.sh (Tier 1) refused the very Bash calls whose token
#      volume the measurement depends on, and the session gave up and printed the
#      beacon without running them. The harness was asking a governed framework
#      project to do ungoverned work. Fixed the way a real loop session is fixed —
#      by giving it a task (`fw work-on`), not by setting FW_SAFE_MODE. A
#      continuous run works under an active task by construction; a sandbox that
#      needs the gate disabled to reach the gauge is no longer measuring the loop.
#
# The composition is the finding: none of the four is a defect, and a short
# session cannot trip the gauge with any one of them left at its default. That is
# a property of the loop worth knowing before trusting it to catch a real overrun.
#
# THE SCOPING FLOOR IS DODGED, NOT DISABLED. Point 3 above is why the prompt forces
# several tool calls: the transcript must carry more than two in-scope usage entries
# so this measures the gauge's normal path, not its degraded one. That degraded path
# is E3-B's subject and T-3241's, and it is not what E8 is about.
#
# Usage: bash docs/reports/T-3239-continuous-loop-demo/livefire-budget-restart.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
EVID="${REPO}/docs/reports/T-3239-continuous-loop-demo/evidence"
OUT="${EVID}/E8-livefire-budget-restart.txt"
mkdir -p "$EVID"

SANDBOX="$(mktemp -d)/proj"
WINDOW=4000        # critical at 95% = 3800; a real framework turn clears it easily
CACHE_AGE=1        # E8 delta #1: expire the seeded fast-path cache immediately
RECHECK=1          # E8 delta #2: measure on EVERY tool call, not every 5th
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

( cd "$SANDBOX" && timeout 60 ./.agentic-framework/bin/fw continuous arm \
    --hours 24 --iterations 5 --tier-ceiling 1 \
    --directive "Continue the demo arc. Reply with exactly: BEACON-E8" ) >/dev/null 2>&1
printf 'current_arc: demo-arc\n' > "${SANDBOX}/.context/working/arc-focus.yaml"

# Blocker 4: give the sandbox a real active task, through the real verb. Without
# this the Tier-1 gate refuses every Bash call and the session produces no tokens.
( cd "$SANDBOX" && timeout 120 ./.agentic-framework/bin/fw work-on \
    "E8 live budget trip — generate real token volume under a real task" \
    --type test ) >/dev/null 2>&1
FOCUS=$(grep '^current_task:' "${SANDBOX}/.context/working/focus.yaml" 2>/dev/null | awk '{print $2}')

# THE PROMPT MUST FORCE REAL TOOL CALLS **IN SEPARATE TURNS**, AND TWO EARLIER
# VERSIONS DID NOT. Both failures are recorded because each looked like the
# mechanism failing and neither was:
#
#   v1  "…then reply with exactly: BEACON-E8" — satisfiable without running
#       anything, and on some runs the model printed the beacon with ZERO Bash
#       calls. No Bash call → no PreToolUse → no gate → no trip.
#   v2  four unguessable nonces, "report all four". The model DID run all four
#       (4/4 echoed back) — but batched them as parallel tool calls inside ONE
#       assistant turn. One turn is ONE usage entry, and lib/context_tokens.py:97
#       returns 0 below TWO in-scope entries. The gate fired once, measured 0,
#       and passed. Forcing tool USE is not the same as forcing tool TURNS.
#
# v3 (this one) forces SEQUENCE by making each step depend on the previous one's
# output: every file names the next file to read. The chain cannot be batched or
# guessed — the model cannot know step3's name until it has read step2 — so each
# link is its own assistant turn, its own usage entry, and its own gate call.
# The matcher is 'Write|Edit|Bash' (verified in the sandbox's own settings.json),
# so `cat` via Bash is what puts the gate in the path.
CHAIN_LEN=6
for i in $(seq 1 $CHAIN_LEN); do
    _nonce=$(head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n')
    if [ "$i" -lt "$CHAIN_LEN" ]; then
        printf 'token %s\nNEXT FILE TO READ: step%s.txt\n' "$_nonce" "$((i+1))" > "${SANDBOX}/step${i}.txt"
    else
        printf 'token %s\nDONE — no next file.\n' "$_nonce" > "${SANDBOX}/step${i}.txt"
    fi
done
NONCES=$(for i in $(seq 1 $CHAIN_LEN); do awk '/^token /{printf "%s ", $2}' "${SANDBOX}/step${i}.txt"; done)

ARMED=$(grep -c '^enabled: true' "${SANDBOX}/.context/working/.continuous-mode.yaml" 2>/dev/null || echo 0)

{
  echo "T-3239 E8 — LIVE budget trip → REAL restart (the positive of E7)"
  echo "generated:  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "repo sha:   $(git -C "$REPO" rev-parse --short HEAD)"
  echo "claude:     $(claude --version 2>/dev/null | head -1)"
  echo "sandbox:    ${SANDBOX}   (real fw init)"
  echo "hooks:      ${HOOKS}"
  echo "dial 1:     FW_CONTEXT_WINDOW=${WINDOW}  (critical at 95% = $((WINDOW*95/100)))"
  echo "dial 2:     FW_BUDGET_STATUS_MAX_AGE=${CACHE_AGE}  (E8 #1 — E7 ran blind behind the 90s seed)"
  echo "dial 3:     FW_BUDGET_RECHECK_INTERVAL=${RECHECK}  (E8 #2 — default 5 measures only calls 1,6,11…)"
  echo "policy:     MAX_RESTARTS=${MAXR}"
  echo "armed:      ${ARMED}  (1 = fw continuous arm succeeded)"
  echo "focus:      ${FOCUS:-none}  (blocker 4 — Tier-1 task gate needs an active task)"
  echo
} > "$OUT"

echo "running real claude under real claude-fw (window=${WINDOW}, cache=${CACHE_AGE}s, recheck=${RECHECK}) …"
cd "$SANDBOX"
FW_CONTEXT_WINDOW="$WINDOW" FW_BUDGET_STATUS_MAX_AGE="$CACHE_AGE" \
FW_BUDGET_RECHECK_INTERVAL="$RECHECK" \
FW_MAX_RESTARTS="$MAXR" FW_RESTART_WINDOW=3600 FW_NO_STARTUP_BANNER=1 \
timeout 420 bash "${REPO}/bin/claude-fw" \
    -p "Follow a file chain using the Bash tool. Start by running 'cat step1.txt'. Each file contains a token and names the NEXT file to read. Read them ONE AT A TIME, in order, using a separate Bash call for each — you cannot know a file's name until you have read the one before it, so do not guess or batch them. Continue until a file says DONE. Then report every token you collected, each on its own line, and finally reply with exactly: BEACON-E8" \
    > "${SANDBOX}/pty.log" 2>&1
WRC=$?

LOG="${SANDBOX}/.context/working/continuous-run.jsonl"
{
  echo "───── wrapper transcript ─────"
  sed -e 's/\x1b\[[0-9;]*m//g' "${SANDBOX}/pty.log" 2>/dev/null | head -70
  echo
  echo "───── did the session actually make tool calls? (flakiness telltale) ─────"
  _seen=0
  for n in $NONCES; do
      if grep -q "$n" "${SANDBOX}/pty.log" 2>/dev/null; then _seen=$((_seen+1)); fi
  done
  echo "chain tokens echoed back by the model: ${_seen}/${CHAIN_LEN}  (0 = shortcut, no Bash ran)"
  echo "(each token requires its own sequential Bash turn — that is what generates the usage entries)"
  echo
  echo "───── budget-gate invocation count (blocker 4 telltale) ─────"
  cat "${SANDBOX}/.context/working/.budget-gate-counter" 2>/dev/null || echo "(absent — gate never ran)"
  echo
  echo "───── active task the session ran under ─────"
  grep '^current_task:' "${SANDBOX}/.context/working/focus.yaml" 2>/dev/null || echo "(none)"
  echo
  echo "───── budget gauge as the framework recorded it ─────"
  cat "${SANDBOX}/.context/working/.budget-status" 2>/dev/null || echo "(none)"
  echo
  echo "───── restart signal (written by budget-gate, consumed by claude-fw) ─────"
  if [ -f "${SANDBOX}/.context/working/.restart-requested" ]; then
      cat "${SANDBOX}/.context/working/.restart-requested"
  else
      echo "(consumed by the wrapper, or never written — read the ledger below to tell which)"
  fi
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
gauge_src=$(python3 -c "
import json
try: print(json.load(open('${SANDBOX}/.context/working/.budget-status')).get('source','?'))
except Exception: print('?')" 2>/dev/null)
iter=$(grep '^current_iteration:' "${SANDBOX}/.context/working/.continuous-mode.yaml" 2>/dev/null | tr -dc '0-9')
# The signal is CONSUMED by the wrapper, so its absence at the end is not evidence
# either way — the ledger's restart event is what proves it existed and was acted on.
sig_seen=$(awk '/critical_budget_gate_block/{n++} END{print n+0}' "$LOG" 2>/dev/null)
sig_seen=${sig_seen:-0}
gatecount=$(tr -dc '0-9' < "${SANDBOX}/.context/working/.budget-gate-counter" 2>/dev/null || echo 0)
# THE ASSERTIONS BELOW READ THE LEDGER, NOT THE POST-RUN CACHES — see the note in
# the report. .budget-status and .budget-gate-counter both describe the state AFTER
# the last restart (the resumed session re-measures; post-compact-resume clears the
# counter as a volatile file), so using either to prove an event that happened in an
# EARLIER session reads a fresh artefact and calls the mechanism dead. The ledger and
# the wrapper's own stdout are durable across the restart, which is the whole point.
trip_tokens=$(python3 - "$LOG" <<'PY2' 2>/dev/null || echo 0
import json, re, sys
best = 0
try: lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
except Exception: lines = []
for l in lines:
    try: d = json.loads(l.strip())
    except Exception: continue
    if d.get("event") == "iterate" and d.get("reason") == "restart":
        m = re.search(r"tokens=(\d+)", d.get("detail", "") or "")
        if m: best = max(best, int(m.group(1)))
print(best)
PY2
)
CRIT=$((WINDOW * 95 / 100))
# `grep -c` PRINTS 0 and EXITS 1 on no-match, so `|| echo 0` appends a SECOND 0
# and the assertion then compares the string "0\n0" as an integer. Count with awk.
handover_committed=$(awk '/Handover committed/{n++} END{print n+0}' "${SANDBOX}/pty.log" 2>/dev/null)
directive_reinjected=$(awk '/Directive: Continue the demo arc/{n++} END{print n+0}' "${SANDBOX}/pty.log" 2>/dev/null)
handover_committed=${handover_committed:-0}
directive_reinjected=${directive_reinjected:-0}

pass=0; fail=0
chk() { if [ "$2" = 0 ]; then echo "  PASS  $1  $3"; pass=$((pass+1)); else echo "  FAIL  $1  $3"; fail=$((fail+1)); fi; }
{
  echo
  echo "───── assertions ─────"
  chk "the sandbox is a real framework project" \
      "$([ -n "$HOOKS" ] && echo 0 || echo 1)" "hooks: ${HOOKS}"
  chk "the real gauge reached critical on a real session" \
      "$([ "${trip_tokens:-0}" -ge "$CRIT" ] && echo 0 || echo 1)" "restart carried tokens=${trip_tokens} (critical at ${CRIT})"
  chk "the budget trip produced a REAL restart" \
      "$([ "${restarts:-0}" -ge 1 ] && echo 0 || echo 1)" "iterate/restart events = ${restarts} (want >=1)"
  chk "the wrapper committed a handover before restarting" \
      "$([ "${handover_committed:-0}" -ge 1 ] && echo 0 || echo 1)" "'Handover committed' in wrapper stdout = ${handover_committed}"
  chk "the directive was re-injected into the restarted session" \
      "$([ "${directive_reinjected:-0}" -ge 1 ] && echo 0 || echo 1)" "'Directive:' lines = ${directive_reinjected}"
  chk "the loop's iteration counter advanced" \
      "$([ "${iter:-0}" -ge 1 ] && echo 0 || echo 1)" "current_iteration = ${iter}"
  echo
  echo "  note  post-run caches are NOT evidence of an intra-run event:"
  echo "        .budget-status  = ${level} (source ${gauge_src}) — the RESTARTED session re-measured"
  echo "        .budget-gate-counter = ${gatecount} — cleared as a volatile file at each SessionStart"
  echo
  echo "PASS: ${pass}  FAIL: ${fail}"
} | tee -a "$OUT"

echo; echo "evidence: $OUT"
exit $(( fail > 0 ? 1 : 0 ))
