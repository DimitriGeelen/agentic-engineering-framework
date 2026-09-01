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
# The sandbox therefore carries a real backlog — five real tasks created through
# the real verb, each with a tickable AC and a verification line the close gate
# actually runs — and the directive tells the loop to work them. Assertion 3 is
# the deliverable: a task whose date_finished lands AFTER the restart event,
# joined mechanically from task frontmatter and the loop ledger. That is work
# surviving the context boundary, which is the whole arc.
#
# WHY THE WINDOW IS 72000 AND NOT 4000, AND NOT 58000 EITHER. E8 used 4000 so any
# turn tripped it instantly. An instant trip is useless here — the first session
# must get far enough to close something before it dies. But the first E9 run
# showed 58000 was the opposite error, and the arithmetic is the finding:
#
#     useful work per iteration = WINDOW - BASELINE,  not WINDOW
#
# A sandbox session baselines near 52.6k tokens before doing anything (CLAUDE.md,
# hooks, handover), and every restart re-pays that baseline in full — a fresh
# session drops the context it could not afford AND the orientation it had already
# bought. At WINDOW=58000 (critical 55100) that left ~2.5k of headroom, about 4%,
# so the loop cycled correctly and progressed barely: 3 restarts, 1 task closed.
#
# 72000 puts critical at 68400 and headroom at ~15.8k — roughly 6x the first run's
# and the same order as production (300k window, ~50k baseline, ~4.7x headroom).
# The trip still lands mid-backlog, which is where a real one would land, but the
# session now has room to finish a task on either side of it.
#
# Usage: bash docs/reports/T-3239-continuous-loop-demo/livefire-loop-does-work.sh
#        SETUP_ONLY=1 bash ...   build the sandbox, assert the rig, stop before the loop
#        KEEP_SANDBOX=1 bash ...   do not delete the sandbox on exit
#
# NOTE on KEEP_SANDBOX: kept sandboxes accumulate under /tmp/tmp.*/proj and are
# never reaped. If you go looking for "the" sandbox afterwards, `ls -d
# /tmp/tmp.*/proj | head -1` gives you the OLDEST one, not this run's - which
# reads as a completed run with a stale ledger. Sort by mtime, or take the path
# this script prints.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
EVID="${REPO}/docs/reports/T-3239-continuous-loop-demo/evidence"
OUT="${EVID}/E9-loop-does-work.txt"
mkdir -p "$EVID"

SANDBOX="$(mktemp -d)/proj"
WINDOW=72000
CACHE_AGE=1
RECHECK=1
MAXR=4
cleanup() { [ "${KEEP_SANDBOX:-0}" = "1" ] && { echo "KEPT: $SANDBOX"; return 0; }; rm -rf "$(dirname "$SANDBOX")"; }
trap cleanup EXIT

mkdir -p "$SANDBOX"
git -C "$SANDBOX" init -q
git -C "$SANDBOX" config user.email livefire@test
git -C "$SANDBOX" config user.name livefire

echo "initialising a REAL framework project (fw init) ..."
( cd "$SANDBOX" && timeout 240 "${REPO}/bin/fw" init . >/dev/null 2>&1 )

FW="./.agentic-framework/bin/fw"

# ── SETUP IS FAIL-LOUD FROM HERE. Read this before touching it. ─────────────
#
# Every step below used to end in `>/dev/null 2>&1`, and four of them were failing
# silently in every E9 run up to and including the 2026-09-01 22:25 run:
#
#   1. `fw task create` was called with only --name/--type. Non-interactively it
#      also requires --description and --owner, so it created NOTHING and said so
#      only on the stderr we were discarding.
#   2. The AC-graft below globs .tasks/active/T-*.md. With no backlog created,
#      that glob matched `fw init`'s onboarding curriculum (T-001..T-005) and
#      grafted item1..item5 onto THOSE.
#   3. The verification graft anchors on "## RCA". The onboarding template has no
#      such section, so the anchor never matched and NO task in any run ever
#      carried a verification line. The close gate had nothing to run.
#   4. `git commit -m "baseline: ..."` carries no T-XXX, so fw init's own
#      commit-msg hook rejected it. The sandbox had no baseline commit.
#
# None of it surfaced, because BACKLOG counted whatever was in .tasks/active/ and
# got 5 either way. The header line "backlog: 5 real tasks" was true of the wrong
# five. That is the false-green shape this whole arc keeps meeting: a check that
# answers a question next to the one it appears to answer.
#
# So: no step here is allowed to fail quietly, and the population is asserted by
# NAME, not by count.

echo "creating a real backlog (5 tasks, real verb) ..."
for n in 1 2 3 4 5; do
    ( cd "$SANDBOX" && timeout 120 $FW task create \
        --name "E9 backlog item ${n} - record the item number in a file" \
        --description "Create item${n}.txt at the project root containing exactly done${n}." \
        --type test --owner agent --horizon now ) > "${SANDBOX}/.create-${n}.log" 2>&1 \
      || { echo "FATAL: fw task create #${n} failed --"; cat "${SANDBOX}/.create-${n}.log"; exit 3; }
done

# fw init leaves its onboarding curriculum (T-001..T-005) in .tasks/active/. That
# is not our backlog and must not be treated as one: those tasks are heavy, carry
# their own ACs, and T-005 ("Generate first session handover") would exercise the
# very restart machinery under test. Remove them so the population is exactly the
# five items we created and the result is attributable.
rm -f "${SANDBOX}/.tasks/active/"T-00[1-5]-*.md

python3 - "$SANDBOX" <<'PY'
import glob, os, re, sys
sandbox = sys.argv[1]
paths = sorted(glob.glob(os.path.join(sandbox, ".tasks/active/T-*.md")))

if len(paths) != 5:
    sys.exit("FATAL: expected exactly 5 backlog tasks, found %d: %s"
             % (len(paths), [os.path.basename(p) for p in paths]))

for i, path in enumerate(paths, start=1):
    s = open(path).read()
    if "E9 backlog item" not in s:
        sys.exit("FATAL: %s is not an E9 backlog task -- the wrong files are being "
                 "patched (this is exactly the defect the asserts exist to catch)"
                 % os.path.basename(path))

    ac = ("### Agent\n"
          f"- [ ] `item{i}.txt` exists at the project root containing exactly `done{i}`\n")
    s, n_ac = re.subn(r'### Agent\n', ac, s, count=1)
    if n_ac != 1:
        sys.exit("FATAL: no '### Agent' anchor in %s" % os.path.basename(path))

    s = s.replace("- [ ] [First criterion]\n", "")
    s = s.replace("- [ ] [Second criterion]\n", "")

    if "## RCA" not in s:
        sys.exit("FATAL: no '## RCA' anchor in %s -- the verification line would be "
                 "dropped and the close gate would have nothing to run"
                 % os.path.basename(path))
    s = s.replace("## RCA", f"grep -qx 'done{i}' item{i}.txt\n\n## RCA", 1)

    open(path, "w").write(s)

    check = open(path).read()
    assert f"item{i}.txt` exists" in check, path
    assert f"grep -qx 'done{i}' item{i}.txt" in check, path

print("backlog OK: 5 E9 tasks, each with a tickable AC and a verification line")
PY
[ $? -eq 0 ] || { echo "FATAL: backlog setup failed"; exit 3; }

# The commit message needs a T-XXX or fw init's own commit-msg hook rejects it.
git -C "$SANDBOX" add -A >/dev/null 2>&1
git -C "$SANDBOX" commit -qm "T-3246: baseline - 5-task E9 backlog" >/dev/null 2>&1 \
  || { echo "FATAL: sandbox baseline commit rejected"; exit 3; }

HOOKS=$(python3 -c "
import json;d=json.load(open('${SANDBOX}/.claude/settings.json'));h=d.get('hooks',{})
print(' '.join('%s=%d'%(k,len(v)) for k,v in sorted(h.items())))" 2>/dev/null)

DIRECTIVE="Work the backlog in .tasks/active/ one task at a time. For each task: run './.agentic-framework/bin/fw work-on <ID>', create the file its acceptance criterion names with exactly the content it specifies, tick that AC from '- [ ]' to '- [x]' in the task file, then close it with './.agentic-framework/bin/fw task update <ID> --status work-completed'. Then move to the next task. Do not stop until every task is closed."

( cd "$SANDBOX" && timeout 60 $FW continuous arm \
    --hours 24 --iterations 8 --tier-ceiling 1 \
    --directive "$DIRECTIVE" ) >/dev/null 2>&1

ARMED=$(grep -c '^enabled: true' "${SANDBOX}/.context/working/.continuous-mode.yaml" 2>/dev/null || echo 0)
BACKLOG=$(grep -l "E9 backlog item" "${SANDBOX}/.tasks/active/"T-*.md 2>/dev/null | wc -l)

{
  echo "T-3246 / arc-012 E9 - does the loop DO WORK across a restart?"
  echo "generated:  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "repo sha:   $(git -C "$REPO" rev-parse --short HEAD)"
  echo "claude:     $(claude --version 2>/dev/null | head -1)"
  echo "sandbox:    ${SANDBOX}   (real fw init)"
  echo "hooks:      ${HOOKS}"
  echo "backlog:    ${BACKLOG} E9 tasks in .tasks/active/ (matched by name, not counted)"
  echo "dials:      FW_CONTEXT_WINDOW=${WINDOW} (critical $((WINDOW*95/100))), CACHE_AGE=${CACHE_AGE}, RECHECK=${RECHECK}"
  echo "policy:     MAX_RESTARTS=${MAXR}, max_iterations=8, tier_ceiling=1"
  echo "armed:      ${ARMED}"
  echo
  echo "directive:  ${DIRECTIVE}"
  echo
} > "$OUT"

# SETUP_ONLY=1 exercises everything above and stops before the 30-minute loop.
# Use it after touching the setup: four setup defects once survived several full
# runs precisely because verifying them cost half an hour each time.
if [ "${SETUP_ONLY:-0}" = "1" ]; then
    echo
    echo "SETUP_ONLY=1 - stopping before the loop."
    echo "backlog tasks:"
    for f in "${SANDBOX}/.tasks/active/"T-*.md; do
        printf '  %s  AC=%s  VERIFY=%s\n' "$(basename "$f")" \
            "$(grep -c 'item[0-9]*\.txt` exists' "$f")" \
            "$(grep -c "grep -qx 'done[0-9]*'" "$f")"
    done
    echo "sandbox git log:"; git -C "$SANDBOX" log --oneline | sed 's/^/  /'
    echo "kept at: $SANDBOX"
    KEEP_SANDBOX=1
    exit 0
fi

echo "running the loop against a real backlog ..."
cd "$SANDBOX"
FW_CONTEXT_WINDOW="$WINDOW" FW_BUDGET_STATUS_MAX_AGE="$CACHE_AGE" \
FW_BUDGET_RECHECK_INTERVAL="$RECHECK" FW_MAX_RESTARTS="$MAXR" \
FW_RESTART_WINDOW=3600 FW_NO_STARTUP_BANNER=1 \
timeout 1800 bash "${REPO}/bin/claude-fw" -p "$DIRECTIVE" \
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
# Only E9 backlog tasks count. A close is evidence about the loop only if the
# thing closed is the thing we put there; anything else in completed/ is noise
# from fw init and would inflate every assertion below.
closed, ignored = [], []
for p in sorted(glob.glob(os.path.join(sandbox, ".tasks/completed/T-*.md"))):
    s = open(p).read()
    m = re.search(r'^id:\s*(\S+)', s, re.M)
    fin = re.search(r'^date_finished:\s*(\S+)', s, re.M)
    rec = (m.group(1) if m else "?", fin.group(1).strip("'\"") if fin and fin.group(1) else "")
    (closed if "E9 backlog item" in s else ignored).append(rec)

first = restarts[0] if restarts else ""
after = [t for t, f in closed if f and first and f > first]

# An artefact counts only if its CONTENT is right. A file that merely exists is
# the bookkeeping this assertion is supposed to exclude.
good, wrong = [], []
for x in sorted(glob.glob(os.path.join(sandbox, "item*.txt"))):
    b = os.path.basename(x)
    m = re.match(r'item(\d+)\.txt$', b)
    try:
        body = open(x).read().strip()
    except Exception:
        body = None
    if m and body == "done" + m.group(1):
        good.append(b)
    else:
        wrong.append({"file": b, "content": body})

print(json.dumps({
    "restarts": restarts,
    "closed": closed,
    "closed_ignored_non_e9": ignored,
    "closed_after_first_restart": after,
    "still_active": len(glob.glob(os.path.join(sandbox, ".tasks/active/T-*.md"))),
    "artefacts": good,
    "artefacts_wrong_content": wrong,
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
n_bad=$(jget artefacts_wrong_content)

pass=0; fail=0
chk() { if [ "$2" = 0 ]; then echo "  PASS  $1  $3"; pass=$((pass+1)); else echo "  FAIL  $1  $3"; fail=$((fail+1)); fi; }
{
  echo
  echo "----- assertions -----"
  chk "the budget trip produced a real restart" \
      "$([ "${n_restart:-0}" -ge 1 ] && echo 0 || echo 1)" "iterate/restart events = ${n_restart}"
  chk "the loop closed at least two real tasks" \
      "$([ "${n_closed:-0}" -ge 2 ] && echo 0 || echo 1)" "E9 tasks in completed/ = ${n_closed}"
  chk "WORK CONTINUED ACROSS THE RESTART (the deliverable)" \
      "$([ "${n_after:-0}" -ge 1 ] && echo 0 || echo 1)" "tasks closed after first restart = ${n_after}"
  chk "the closes were real work, not bookkeeping" \
      "$([ "${n_art:-0}" -ge 2 ] && echo 0 || echo 1)" "artefacts with CORRECT content = ${n_art} (wrong = ${n_bad})"
  echo
  if [ "${WRC}" = "124" ]; then
    echo "  NOTE  wrapper hit the 1800s wall clock (exit 124) - the run was TRUNCATED,"
    echo "        not concluded. Any FAIL above is unattributable: the harness stopped"
    echo "        watching before the loop was finished. Re-run with a longer timeout"
    echo "        before reading a negative result as evidence about the loop."
    echo
  fi
  echo "PASS: ${pass}  FAIL: ${fail}"
} | tee -a "$OUT"

echo; echo "evidence: $OUT"
exit $(( fail > 0 ? 1 : 0 ))
