# T-3181 — Refining the continuous-run loop model, node by node

Subject: `.context/designer/projects/draft-continuous-run-loop` v5 (drawn 2026-08-26 16:07,
T-3159 → T-3163). Arc: arc-012 `continuous-run`.

Method: walk the 15 nodes in flow order with the operator, one per exchange. For each node,
verify the annotation against current code BEFORE discussing it, then resolve it to
BUILD / DECIDE / DROP.

## Status refresh — v5's annotations vs. code at 2026-08-26 21:5x

v5 was drawn at 16:07. T-3164 landed at ~16:47. Several annotations are already stale;
**the node v5 calls "THE LOAD-BEARING GAP" is built and registered.**

| # | Node | v5 says | Verified now |
|---|------|---------|--------------|
| 1 | operator arms the run | DIVERGES | PARTLY FIXED — shipped disarmed (T-3164); `max_tasks`/`tasks_completed`/`completed_task_ids` now exist. `expires_after_seconds: 86400` still present and still the last thing that terminated a run. |
| 2 | supervisor spawns FRESH session | DIVERGES ("line 338 sets `-c`") | **STALE** — T-3166 shipped it: `CLAUDE_ARGS=()` by default, `-c` only under `FW_RESTART_MODE=continue`. **New defect instead** (see below). |
| 3 | session init / inject directive | DIVERGES (additionalContext causes no turn) | Re-open — the Stop hook now causes the turn, so this node's failure mode has changed. |
| 4 | work turn | PRESENT | PRESENT. |
| 5 | budget level? | PRESENT | PRESENT. |
| 6 | **Stop hook — continue?** | **MISSING — THE LOAD-BEARING GAP** | **BUILT + REGISTERED** — `agents/context/stop-driver.sh` (T-3164), `.claude/settings.json:223`. Disarmed by default, fails closed. |
| 7 | run cap / arc drained? | DIVERGES (counter keyed to SESSIONS) | **FIXED** — task-keyed: `stop-driver.sh:157-160`, `lib/continuous-mode.sh`. |
| 8 | operator rules on blocking gate | OPEN (IW-5) | Still open. |
| 9 | let the unit COMPLETE | MISSING; today's behaviour is the opposite | Still true — `_terminator_watch` still SIGTERMs mid-unit. |
| 10 | handover protocol | OPEN (IW-4) | Still untested. Nobody has taken LATEST.md into a cold session and measured resume. |
| 11 | cross the boundary (/clear or respawn) | MISSING; "hook-enable cannot even register SessionEnd" | Partly STALE — `bin/hook-enable.sh:18` VALID_EVENTS **does** include SessionEnd. It is simply not registered (0 hits in settings.json). |
| 12 | SessionStart source? | DIVERGES (clamp to 3, `clear` rewritten) | Still true — `post-compact-resume.sh:22-31` clamps to (startup\|resume\|compact). |
| 13 | run halted — kill switch | MISSING (IW-2, sovereignty) | **BUILT** — `stop-driver.sh:60,80-82`, halt file read as Brake 1 before anything else votes. |

### New defect, measured tonight (not in v5)

v5 says the supervisor "IS live" and the only defect was the `-c` flag. Tonight's evidence
says something worse and more specific:

- 21:25:46 — `.context/working/.auto-restart-pending` written = claude-fw's restart branch RAN.
- 21:39:52 — wrapper PID 1017835 (`claude-fw -c`) started **fresh**, 14 min later, by hand.
- The restart loop lives inside one wrapper's `while`; a wrapper that iterates keeps its PID
  and relaunches with no args. A *different* PID, 14 minutes later, with `-c`, is an operator
  relaunch.

**So the wrapper left its loop instead of iterating.** Links 1-4 (detect → signal → terminate →
handover) all fired; link 5 (relaunch) did not. That narrows the fix considerably. Filed IW-6.

Secondary: the sentinel is still on disk 26 min later, unconsumed. Its T-3168 TTL check lives
inside the `SOURCE_TAG = startup` branch, and a `-c` start emits `resume`, which never reaches
that code. Stale sentinels are not expired, only ignored-by-luck-of-ordering.

## Dialogue Log

### Exchange 0 — framing (2026-08-26 ~21:55)

**Operator:** "can we please focus on the continuous and automatic restart? We've now modeled
it in Workflow Designer. Looks good. We need to refine it and you need to take me to it piece
by piece and have the conversation with it and piece by piece, I mean step by step."

**Agent:** Located the model, verified every annotation against code before opening the
walkthrough, and found that the node v5 calls the load-bearing gap is already built. Recorded
the refresh above so the walkthrough refines the *current* gap set rather than re-litigating
fixed problems.

## Node decisions

(filled one per exchange)

### Exchange 1 — node 1 `hum_1_operator`, "operator arms the run" (2026-08-26 ~22:0x)

**Agent asked:** is a "run" a session respawn or a task? And should `expires_after_seconds`
be deleted or demoted?

**Operator (verbatim, mixed NL/EN speech-to-text):** "wat we willen is de mode continuous run,
en dan zet eider complete the task, of complete the arc, met high value high cost, and high
value low cost items, tasks completed en ook een limiter voor de amount of runs waardoor, maar
dat is niet mandatieve[.] wat je dan wilt is de sessie om te adhieren tot het tokenlimit dat is
geconfigurd, en als we in de urgent zone komen, om de task te [voltooien], om de precompact
routine te beginnen en dan gaan we naar een situatie waar we kunnen beginnen en beginnen de
continue commands en we hebben de prompt die de instrucjons in de werk aan de arc of task en
een heel clear set van instrucjons dat je nu vaak krijgt. De instrucjons ook moeten
configurablen worden, dus een repeating prompt injection, zo te zeggen."

**The agent's question was the wrong question.** The cap is not the design; the TARGET is.

#### D-1.1 — arming sets a MODE + TARGET, not a counter
Continuous mode is armed with one of two targets:
- `complete-task` — drive one task to done.
- `complete-arc`  — drive an arc until drained.

Within `complete-arc`, work is selected by BVP quadrant: **HV/HC and HV/LC first**.
Machinery exists: `fw bvp --quadrant {hv-hc|hv-lc}`. Nothing in the loop calls it yet.

#### D-1.2 — the run limiter is OPTIONAL
`max_iterations` / `max_tasks` stay as optional guards, default unset. They are a
convenience ("kicked out after five runs"), explicitly *not* mandatory and not the
terminal condition.

#### D-1.3 — the terminal driver is the TOKEN BUDGET, and the action threshold is URGENT
The session adheres to the configured token limit. On entering the **urgent** zone:
1. finish the current task,
2. run the precompact routine,
3. cross the boundary,
4. resume the continue commands.

**This moves the split in the map one notch left.** v5 routes `ok/warn/urgent → Stop hook`
and `critical → cross the boundary`. Under D-1.3, **urgent** is the *action* threshold and
critical becomes the *failure* threshold — the place we should never reach, not the place
where the design fires. Node 5 (`fw_2_budget`) and node 9 (`agt_4_let`) both change.

#### D-1.4 — the continuation prompt must be CONFIGURABLE
A repeating prompt injection carrying the work-on-arc/task instructions. Today it is a
hard-coded shell string at `agents/context/stop-driver.sh:207-212` (`next_reason=`), with
the governance bootstrap baked in. It needs to become operator-editable content.

#### D-1.5 — wall-clock demoted (agent proposal, not operator-stated)
`expires_after_seconds` was not mentioned. Given D-1.3 it is not a terminal condition.
Proposed: keep as a runaway fuse only, set far away and renamed so nobody reads it as design.
NOT operator-confirmed — flagged, not decided.

#### Gap confirmed at this node
`.context/working/.continuous-mode.yaml` has **no arc field and no target field**, and
nothing in the loop reads an arc — every `arc` hit in `stop-driver.sh`,
`lib/continuous-mode.sh` and `inject-next-directive.py` is a comment or a task-ref regex.
`stop-driver.sh:209` injects the words "toward the current arc" into the continuation
prompt while nothing computes which arc that is. The good ending ("arc drained") is
therefore not evaluable today.
