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
