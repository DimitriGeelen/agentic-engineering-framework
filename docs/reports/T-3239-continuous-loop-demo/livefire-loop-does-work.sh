#!/usr/bin/env bash
# T-3246 / arc-012 E9 — THE DELIVERABLE: the loop does WORK across a restart.
#
# Everything before this measured the loop's ENGINE. E8 proved a real session
# crosses the real budget threshold and a real wrapper brings a real session back
# — but that session read four files and exited. It closed no task, advanced no
# backlog, produced nothing anyone wanted. Proving the engine turns over with the
# transmission disconnected is not proving the car moves.
#
# The arc's headline mechanic promises the operator a "multi-cycle continuous
# session". The point of a cycle is the WORK in it. So E9 asks the only question
# that matters:
#
#     does the loop CLOSE A TASK, TRIP, RESTART, and CLOSE ANOTHER?
#
# The sandbox therefore carries a real backlog — three real tasks created through
# the real verb, each with a tickable AC and a verification line the close gate
# actually runs — and the directive tells the loop to work them. Assertion 3 is
# the deliverable: a task whose date_finished lands AFTER the restart event,
# joined mechanically from task frontmatter and the loop ledger. That is work
# surviving the context boundary, which is the whole arc.
#
# WHY THE WINDOW IS ~58000 AND NOT 4000. E8 used 4000 so any turn tripped it
# instantly. Here an instant trip is useless — the first session must get far
# enough to close something before it dies. A sandbox session baselines near 52.6k
# tokens (measured in E8), so 58000 puts critical at 55100: a few turns of real
# task work above the floor. The trip then lands mid-backlog, which is where a
# real one would land.
#
# Usage: bash docs/reports/T-3239-continuous-loop-demo/livefire-loop-does-work.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
EVID="${REPO}/docs/reports/T-3239-continuous-loop-demo/evidence"
OUT="${EVID}/E9-loop-does-work.txt"
mkdir -p "$EVID"

SANDBOX="$(mktemp -d)/proj"
WINDOW=58000
CACHE_AGE=1
RECHECK=1
MAXR=3
cleanup() { [ "${KEEP_SANDBOX:-0}" = "1" ] && { echo "KEPT: $SANDBOX"; return 0; }; rm -rf "$(dirname "$SANDBOX")"; }
trap cleanup EXIT

mkdir -p "$SANDBOX"
git -C "$SANDBOX" init -q
git -C "$SANDBOX" config user.email livefire@test
git -C "$SANDBOX" config user.name livefire

echo "initialising a REAL framework project (fw init) ..."
( cd "$SANDBOX" && timeout 240 "${REPO}/bin/fw" init . >/dev/null 2>&1 )

FW="./.agentic-framework/bin/fw"

echo "creating a real backlog (3 tasks, real verb) ..."
for n in 1 2 3; do
    ( cd "$SANDBOX" && timeout 120 $FW task create \
        --name "E9 backlog item ${n} - record the item number in a file" \
        --type test ) >/dev/null 2>&1
done

python3 - "$SANDBOX" <<'PY'
import glob, os, re, sys
sandbox = sys.argv[1]
for i, path in enumerate(sorted(glob.glob(os.path.join(sandbox, ".tasks/active/T-*.md"))), start=1):
    s = open(path).read()
    ac = ("### Agent\n"
          f"- [ ] `item{i}.txt` exists at the project root containing exactly `done{i}`\n")
    s = re.sub(r'### Agent\n', ac, s, count=1)
    s = s.replace("- [ ] [First criterion]\n", "")
    s = s.replace("- [ ] [Second criterion]\n", "")
    s = s.replace("## RCA", f"grep -qx 'done{i}' item{i}.txt\n\n## RCA", 1)
    open(path, "w").write(s)
PY

git -C "$SANDBOX" add -A >/dev/null 2>&1
git -C "$SANDBOX" commit -qm "baseline: 3-task backlog" >/dev/null 2>&1

HOOKS=$(python3 -c "
import json;d=json.load(open('${SANDBOX}/.claude/settings.json'));h=d.get('hooks',{})
print(' '.join('%s=%d'%(k,len(v)) for k,v in sorted(h.items())))" 2>/dev/null)

DIRECTIVE="Work the backlog in .tasks/active/ one task at a time. For each task: run './.agentic-framework/bin/fw work-on <ID>', create the file its acceptance criterion names with exactly the content it specifies, tick that AC from '- [ ]' to '- [x]' in the task file, then close it with './.agentic-framework/bin/fw task update <ID> --status work-completed'. Then move to the next task. Do not stop until every task is closed."

( cd "$SANDBOX" && timeout 60 $FW continuous arm \
    --hours 24 --iterations 6 --tier-ceiling 1 \
    --directive "$DIRECTIVE" ) >/dev/null 2>&1

ARMED=$(grep -c '^enabled: true' "${SANDBOX}/.context/working/.continuous-mode.yaml" 2>/dev/null || echo 0)
BACKLOG=$(ls "${SANDBOX}/.tasks/active/"T-*.md 2>/dev/null | wc -l)

{
  echo "T-3246 / arc-012 E9 - does the loop DO WORK across a restart?"
  echo "generated:  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "repo sha:   $(git -C "$REPO" rev-parse --short HEAD)"
  echo "claude:     $(claude --version 2>/dev/null | head -1)"
  echo "sandbox:    ${SANDBOX}   (real fw init)"
  echo "hooks:      ${HOOKS}"
  echo "backlog:    ${BACKLOG} real tasks in .tasks/active/"
  echo "dials:      FW_CONTEXT_WINDOW=${WINDOW} (critical $((WINDOW*95/100))), CACHE_AGE=${CACHE_AGE}, RECHECK=${RECHECK}"
  echo "policy:     MAX_RESTARTS=${MAXR}, max_iterations=6, tier_ceiling=1"
  echo "armed:      ${ARMED}"
  echo
  echo "directive:  ${DIRECTIVE}"
  echo
} > "$OUT"

echo "running the loop against a real backlog ..."
cd "$SANDBOX"
FW_CONTEXT_WINDOW="$WINDOW" FW_BUDGET_STATUS_MAX_AGE="$CACHE_AGE" \
FW_BUDGET_RECHECK_INTERVAL="$RECHECK" FW_MAX_RESTARTS="$MAXR" \
FW_RESTART_WINDOW=3600 FW_NO_STARTUP_BANNER=1 \
timeout 900 bash "${REPO}/bin/claude-fw" -p "$DIRECTIVE" \
    > "${SANDBOX}/pty.log" 2>&1
WRC=$?

LOG="${SANDBOX}/.context/working/continuous-run.jsonl"

python3 - "$SANDBOX" "$LOG" > "${SANDBOX}/verdict.txt" 2>&1 <<'PY'
import glob, json, os, re, sys
sandbox, log = sys.argv[1], sys.argv[2]
restarts = []
try:
    for line in open(log, encoding="utf-8"):
        line = line.strip()
        if not line: continue
        try: d = json.loads(line)
        except Exception: continue
        if d.get("event") == "iterate" and d.get("reason") == "restart":
            restarts.append(d.get("ts", ""))
except Exception:
    pass
closed = []
for p in sorted(glob.glob(os.path.join(sandbox, ".tasks/completed/T-*.md"))):
    s = open(p).read()
    m = re.search(r'^id:\s*(\S+)', s, re.M)
    fin = re.search(r'^date_finished:\s*(\S+)', s, re.M)
    closed.append((m.group(1) if m else "?", fin.group(1).strip("'\"") if fin and fin.group(1) else ""))
first = restarts[0] if restarts else ""
after = [t for t, f in closed if f and first and f > first]
print(json.dumps({
    "restarts": restarts,
    "closed": closed,
    "closed_after_first_restart": after,
    "still_active": len(glob.glob(os.path.join(sandbox, ".tasks/active/T-*.md"))),
    "artefacts": sorted(os.path.basename(x) for x in glob.glob(os.path.join(sandbox, "item*.txt"))),
}, indent=2))
PY

{
  echo "----- wrapper transcript (tail) -----"
  sed -e 's/\x1b\[[0-9;]*m//g' "${SANDBOX}/pty.log" 2>/dev/null | tail -45
  echo
  echo "----- loop event ledger -----"
  cat "$LOG" 2>/dev/null || echo "(none)"
  echo
  echo "----- backlog outcome (the join that matters) -----"
  cat "${SANDBOX}/verdict.txt"
  echo
  echo "----- continuous-mode state after the run -----"
  cat "${SANDBOX}/.context/working/.continuous-mode.yaml" 2>/dev/null || echo "(none)"
  echo
  echo "wrapper exit code: ${WRC}"
} >> "$OUT"

V="${SANDBOX}/verdict.txt"
jget() { python3 -c "import json;print(len(json.load(open('$V'))['$1']))" 2>/dev/null || echo 0; }
n_restart=$(jget restarts); n_closed=$(jget closed)
n_after=$(jget closed_after_first_restart); n_art=$(jget artefacts)

pass=0; fail=0
chk() { if [ "$2" = 0 ]; then echo "  PASS  $1  $3"; pass=$((pass+1)); else echo "  FAIL  $1  $3"; fail=$((fail+1)); fi; }
{
  echo
  echo "----- assertions -----"
  chk "the budget trip produced a real restart" \
      "$([ "${n_restart:-0}" -ge 1 ] && echo 0 || echo 1)" "iterate/restart events = ${n_restart}"
  chk "the loop closed at least two real tasks" \
      "$([ "${n_closed:-0}" -ge 2 ] && echo 0 || echo 1)" "tasks in completed/ = ${n_closed}"
  chk "WORK CONTINUED ACROSS THE RESTART (the deliverable)" \
      "$([ "${n_after:-0}" -ge 1 ] && echo 0 || echo 1)" "tasks closed after first restart = ${n_after}"
  chk "the closes were real work, not bookkeeping" \
      "$([ "${n_art:-0}" -ge 2 ] && echo 0 || echo 1)" "artefact files created = ${n_art}"
  echo
  echo "PASS: ${pass}  FAIL: ${fail}"
} | tee -a "$OUT"

echo; echo "evidence: $OUT"
exit $(( fail > 0 ? 1 : 0 ))
