# procAsFit — round 2 of 4 — handback

**Run:** T-3517 (parent orchestration task, TermLink-dispatched round 2)
**Worker agent id:** pf0927-r2
**Repo:** /opt/999-Agentic-Engineering-Framework, branch `bleeding-edge`
**Window:** 2026-09-27, single session
**Predecessor:** `docs/reports/procasfit-2026-09-27-round-1.md` (read in full before
selecting any work, per instruction)

## What round 1 left, and what moved since

Round 1 closed T-3506, reconfirmed the corpus-wide BVP flat-tie (Sovereign
Question 1/2), named a narrower flatness question (Sovereign Question 3, not
yet filed), and left T-3481's own close as a "cheap candidate... for round
2+ if the orchestrator instructs a worker to check `termlink_dispatch_status`
/`termlink_agent_history`."

**Sovereign questions from round 1 — status this round:**

1. **BVP v1 heuristic has no differentiating signal for the structural/
   hygiene bug-class family; cost is structurally blind pre-completion.**
   Re-verified this round: `fw bvp --quadrant hv-lc/hv-hc` (confirmed-only)
   is still 0/0. `--include-proposed` still shows the identical 17-task flat
   tie at BVP 108/norm 0.40/cost 3.6 that round 1 (and T-3481 round 3 before
   it) found. **Unchanged, still open.**
2. **Should the standalone hygiene backlog get an accumulator arc?**
   **Unchanged, still open** — no operator answer found this round.
3. **(Round 1's narrower framing, not yet filed as its own task.)**
   **Unchanged, still open** — not filed this round either; naming it a
   second time without filing it starts to look like the thing itself
   deserves a task, but filing it was not this round's selected work and I
   did not want to invent scope under a different unit of work's evidence
   trail. Flagging for round 3/4 or the operator: if this keeps recurring
   across rounds, that recurrence is itself the signal to file it.

**T-3481's own close:** I checked whether this round has access the
predecessor round didn't. `termlink list` (mcp**termlink**termlink_list_sessions
equivalent, via the `termlink` CLI directly) shows `pf0925-r1`/`pf0925-r2`/
`pf0925-r3` — the actual T-3481 round sessions — still alive (`ready`, 1d
old, tagged `task:T-3481,task-type:build`). That is *closer* to evidence
than round 1 had (round 1 only checked `dispatches.jsonl`, which has one
unrelated T-3481 entry). But the AC in question ("worker liveness and
outcome are checked per round via `fw termlink wait`/`result`") asks about
*commands the orchestrating session ran against these sessions*, not about
the sessions' own state — and TermLink's session registry does not log who
polled a session's status or when. I confirmed there is no separate
fw-level dispatch log for `fw termlink dispatch` (unlike the resolver-based
dispatch, which posts to `.context/dispatches.jsonl`) — checked
`.context/working/`, `.context/dispatch-blobs/`, and found nothing.
**Conclusion unchanged from round 1: this evidence genuinely does not exist
anywhere I can reach, not just somewhere I didn't look hard enough.** Left
open; the honest owner of this evidence is the orchestrating session for
T-3481 itself (whichever session ran `fw termlink dispatch` three times in
2026-09-25), and that session's transcript is gone.

## Selection (stated before execution, per mandate)

**Objective:** AEF governs its own development (D2 Reliability — same
objective as round 1: landed/resolved work should reach a clean, auditable
terminal state rather than reading as open when it factually is not).
**Arc:** `orchestrator-rethink` (T-1820's own `arc_id:`) — chosen not
because BVP ranked it (BVP is still corpus-flat, confirmed above) but
because it is the arc of a task with **new evidence round 1 had no reason
to check**: round 1 never examined T-1820, because round 1's selection pass
was driven by the general started-work/owner:agent list and stopped at
T-3506. This round's pass through the same list (`fw task list --status
started-work --owner agent`) surfaced **T-1820**, whose own history showed
a 5-month investigation chain (T-1820 → T-1821 → T-2918 → T-3396 → T-3397)
that has fully resolved *downstream* of T-1820 (T-1821/T-2918/T-3396/T-3397
are all `work-completed`) while T-1820 itself, the root of the chain, sat
open. **Task:** T-1820. **Quadrant:** BVP-unselectable (same flat-tie
family as everything else in the corpus), re-entered at task level via the
same remaining-cost tiebreaker round 1 used for T-3506 — except here
"remaining cost" is not "verify and close" but "the underlying Sovereign
question this task was blocked on has since been answered elsewhere, and
that answer needs to be reflected back onto this task." **Activity:**
investigate whether the downstream chain's resolution actually supersedes
T-1820's blocked ACs (it does — see below), reclassify the two
unsatisfiable Agent ACs with citations, add a Human AC scoping the
accept/reopen call, transfer ownership to human (T-1820 was `owner: agent`;
the acceptance call is a strategic/architecture judgment per T-954 criterion
1, same class T-2918 itself already used this exact reclassification
pattern for), write an updated Recommendation, and attempt the close —
expecting (and getting) a sovereignty-gate refusal, which is the correct
outcome for a human-owned task's status transition.

## What closed

**Nothing closed to `work-completed`.** T-1820 remains `status:
started-work`, `owner: human` — correctly, because the sovereignty gate
(R-033) refused the agent-initiated `--status work-completed` transition the
instant ownership was human, before it even reached the AC/verification
checks. This is not a partial result; it is the gate doing exactly what it
exists to do, and the task's file, ACs, and Recommendation are now in a
state where the operator's remaining action is a single Human-AC tick.

## What this round actually did (T-1820)

- Edited the two unresolved Agent ACs (originally `[ ]` "Live joint smoke
  executed" and `[-]` "Demo artefact written") to `[x]`, each rewritten with
  a citation trail proving the AC's *premise* — not merely its execution —
  no longer exists: the poll-based `inbox.queued` mechanism T-1820 targeted
  was investigated to its root cause (T-2918, hub aggregator has no
  cursor/replay primitive at all, confirmed against TermLink source) and
  then *replaced*, not fixed, by an inception decision (T-3396, GO, "real
  always-on listener per agent session") that has since shipped — confirmed
  by this session's own use of `fw sidecar inbox`/`fw sidecar send`
  (arc-011/T-3407), the literal mechanism T-3396 authorised.
- Added one Human AC (`[REVIEW]`) with Steps/Expected/If-not asking the
  operator to confirm the closure is correct rather than deciding it myself
  — this is a strategic/architecture acceptance call (T-954 criterion 1),
  the same class T-2918 itself already routed to a Human AC for its own
  four-way architecture choice.
- Changed `owner: agent` → `owner: human` via `fw task update T-1820
  --owner human --reason "..."` (a verb call, not a hand-edit of the
  frontmatter field).
- Added a dated Evolution entry and a new, clearly-labelled "Recommendation
  (updated 2026-09-27)" block (GO — close as superseded) above the
  preserved original 2026-08-11 PARTIAL-SHIP recommendation, rather than
  overwriting history.
- Ran `python3 -m pytest tests/unit/test_peer_subscribe.py` for real
  (12/12 PASS, reconfirmed this session) before citing it as still-green
  evidence — did not rehearse-and-assume, per round 1's own lesson about
  not substituting a self-induced read for a real check.
- Attempted `fw task update T-1820 --status work-completed` — **refused by
  the sovereignty gate (R-033)**, exactly as expected for an owner:human
  task; did not use `--skip-sovereignty` or any bypass. Framework printed
  the canonical review URL and QR code and wrote
  `.context/working/.reviewed-T-1820`.
- Ran `fw task review T-1820` to get the **canonical, tool-emitted** handoff
  URL (never hand-typed, per T-2125/T-2129): **http://192.168.10.107:3002/review/T-1820**
- Committed (`b61e32282`) — only the T-1820 task file; verified via `git
  diff --cached --stat` that none of the ~1444 pre-existing mode-only
  changes round 1 documented were swept in.
- `git push origin bleeding-edge` was still in flight as this handback was
  written — see Auditability below for the resolved outcome (this round
  waited for and recorded the actual push result rather than assuming it
  succeeded, per round 1's own hypothesis-driven-debugging discipline about
  not treating a slow gate as a problem to route around).

## New finding this round: `fw review-queue`'s "READY TO CLOSE" list

Running `fw review-queue` (not run by round 1) surfaced a list round 1 never
saw: **16 owner:human tasks with zero `### Human` criteria and all Agent ACs
already done**, each with a ready-made `fw task update T-XXX --status
work-completed` command (T-1274, T-1542, T-2410, T-2801, T-2802, T-3297,
T-3298, T-3299, T-3300, T-3301, T-3302, T-3306, T-3316, and 3 more not fully
enumerated in this round's terminal scroll). The same command run for
`review-queue` reports **324 tasks total awaiting human review** (292 GO /
20 DEFER / 4 NO-GO / 2 unscored / 5 NO-REC).

**I did not run any of these commands.** Every one of these 16 tasks has
`owner: human`, and completing a human-owned task is explicitly **not
delegated** to agent initiative under CLAUDE.md's Autonomous Mode Boundaries
— that holds regardless of whether the task currently has zero Human
criteria to tick, because the ownership field itself is the sovereignty
signal, not the presence of an unticked box. This is exactly the shape the
mandate's "Sovereign questions are surfaced, not resolved" binding covers:
the review-queue's own evidence (N agent ACs done, per task) is real and
worth surfacing, but "should these actually close" is the operator's call,
not mine to batch-execute even though the commands are sitting right there
formatted and ready. Naming it here rather than running it.

## Objectives advanced, against round 1's end state

- One five-month-old investigation chain (T-1820 → T-1821 → T-2918 →
  T-3396 → T-3397) had its root task (T-1820) brought into sync with what
  its own downstream tasks already resolved. Before this round, T-1820 read
  as open/blocked work in every task listing (`fw task list`, `fw review-
  queue` would not have surfaced it as ready-to-close since it *does* have
  Human criteria now) despite the actual blocking question having been
  answered five days ago (T-3396, 2026-09-20) by a shipped architecture
  change. That gap is now closed to a single operator tick.
- Corroborated round 1's corpus-wide BVP flatness finding independently a
  third time (round 3 → round 1 → this round), same numbers, same 17 tasks.
- Surfaced a genuinely new, previously-unexamined backlog view (`fw review-
  queue`'s 16-task ready-to-close list, 324-task total human-review queue)
  as evidence for the operator, without acting on it.

## Arc state: tasks by status and quadrant

Unchanged from round 1's finding, reconfirmed: `fw bvp --quadrant
{hv-lc,hv-hc}` (confirmed-only) is 0/0 corpus-wide. `--include-proposed`
reproduces the identical 17-task flat tie. No arc's `scoped_drivers:` breaks
the tie (not re-checked exhaustively this round — round 1 already checked
`value-prioritisation`/arc-006, the arc that owns BVP tooling itself, and
nothing has changed there).

## What remains in Q1/Q2, per task, with the reason it was not done

| Task | Why not done this round |
|---|---|
| T-3358 (claude-fw exit-detection, root fleet) | Not re-attempted. Round 1 already hit a session-permission-classifier denial on the exact fleet-access call needed (`mcp__skills__remote_exec_test`), the third distinct failure mode across sessions on this task. Retrying the identical denied call without new information would be shotgun debugging through a wall already named; per Hypothesis-Driven Debugging discipline this stays parked for operator/fleet-access-session attention, not another autonomous attempt. |
| T-3481 (predecessor 3-round orchestration) | Re-investigated this round with a genuinely different check (TermLink session registry, not just `dispatches.jsonl`) — confirmed the evidence gap is real, not just unexplored. See "T-3481's own close" above. Still left open. |
| T-2770 (inception: read-only fw query auto-init) | Unchanged — correctly parked at `Recommendation: DEFER`, owner sovereignty boundary, not re-examined this round (no new information would change this). |
| T-3496 (SOVEREIGN: voi_score constant on inceptions) | Unchanged — owner: human, explicitly filed Sovereign question, not touched. |
| The ~39-task standalone hygiene backlog | Unchanged — structurally unselectable via the sanctioned BVP path (Sovereign Question 1/2 above). |
| 16-task `fw review-queue` "READY TO CLOSE" list | New finding this round, not touched — all owner: human, completing human-owned tasks is not delegated to agent initiative regardless of Human-AC-count. Surfaced as evidence above for the operator's own batch review. |

## Sovereign questions — priority order

Carried forward from round 1, unchanged in substance, re-verified current:

1. **BVP v1 heuristic has no differentiating signal for the structural/
   hygiene bug-class task family** (round 3 → round 1 → this round,
   independently reproduced a third time, identical numbers each time).
2. **Should the standalone hygiene backlog get an accumulator arc, or is
   arc-less maintenance-by-design intended?** Unchanged.
3. **(Round 1's narrower inception-vs-build voi_score/BVP flatness framing)**
   Unchanged, still unfiled. Naming it a second round running without
   filing it is itself worth the operator's attention — see note above.

**New, not carried from round 1:**

4. **(Not filed as a task — an observation, not yet a Sovereign question in
   the formal sense, but named for completeness.)** The 324-task human-
   review backlog `fw review-queue` reports is large enough that it may
   itself warrant a structural question: is there a sanctioned way for an
   agent to *batch-surface* (not batch-execute) the ready-to-close subset
   to the operator more efficiently than one-task-at-a-time discovery via
   `fw review-queue`? Not answering this — naming it, since it recurred
   as a genuine "I found real work I structurally cannot do" moment this
   round, which is exactly the shape a Sovereign question takes.

## Gates that refused me, and what I did instead

| Gate | What it refused | What I did |
|---|---|---|
| Sovereignty gate (R-033) | `fw task update T-1820 --status work-completed` after transferring ownership to human | Did not bypass with `--skip-sovereignty`. Accepted the refusal as correct (owner: human, Human AC unticked), ran `fw task review T-1820` for the canonical handoff URL instead. |
| Autonomous Mode Boundaries (self-governed, no hook) | Running any of the 16 ready-made `fw task update --status work-completed` commands from `fw review-queue`'s owner:human list | Did not run them. Named the list as evidence in this handback instead. |
| None on the T-1820 edit itself | — | Both real checks (pytest, doc-content greps) run for real before citing them, not rehearsed-and-assumed. |

No `--force`, `--skip-*`, or `FW_ALLOW_*` bypass was used anywhere this
round.

## Cost-vs-estimate deltas worth feeding back into calibration

T-1820's own `cost_estimate_proposed` (last entry, 2026-08-17): `tier: 2,
effort: 8`, `blast_radius: unmeasured`. The actual cost this round was:
reading ~5 related task files in full (T-1820, T-1821, T-2918, T-3396,
T-3397 headers), two grep/citation checks, one pytest run, three edit
operations, two verb calls (`--owner`, `--status`), one refused close
attempt, one `fw task review`, one commit, one (slow) push. This is
meaningfully *cheaper* than T-3506's verification cost in round 1 (which
was dominated by an unscoped `fw audit` invocation) precisely because this
task's own `## Verification` block was never reached — the sovereignty gate
fired before verification ran. **Worth noting for calibration:** a task
whose remaining work is "resolve a stale cross-task supersession and hand
to human review" is cheap in a way current cost fields have no vocabulary
for — it's not "small effort" (the investigation reading was real) and it's
not "low blast radius" (touches a 5-task chain) — it's cheap because the
actual state-changing action is gated to a single human tick, and gate-
refused work costs approximately nothing past the refusal. Same shape as
round 1's finding (Verification-block cost is invisible to the estimator)
but the inverse case: here the gate being *reached and correctly firing
early* is what kept cost down, and that's equally invisible to `effort=8`.

A second, smaller note: `git push origin bleeding-edge` took long enough
this round to still be in flight when this handback was drafted — almost
certainly the same `AUDIT_TIMEOUT`/pre-push audit contention round 1
documented for the close-time `fw audit` line (T-3297, T-3324 already
filed, human-owned). This is the same cost source showing up on a different
gate (pre-push, not close-verification) — worth noting that it's not
localized to one gate, it's a property of `fw audit` itself being invoked
from multiple trigger points with the same ~20-50min unscoped cost.

## Next unit of work, if a further round runs against this same state

With T-1820 now staged for a single human tick and no other agent-
executable, sufficiently-evidenced Q1/Q2 task found, round 3 should expect
the same shape round 1 and this round both found: **corpus-wide BVP
selection is still closed off**, and new executable work (if any) will come
from the same pattern this round used — walking `owner: agent` started-work
tasks individually for stale cross-task supersessions, not from `fw bvp`
ranking. T-3358 and T-3481 remain the two standing agent-owned blocked
items; neither moved this round for reasons already exhausted (see table
above). The `fw review-queue` 16-task list is real, evidenced, ready-made
work — for the operator, not for an autonomous round.

## Auditability

Every claim above traces to a command run in this session: `fw bvp`
(quadrant + include-proposed, reconfirmed), `fw task list --status
started-work --owner agent`, `fw review-queue`, `termlink list` (session
registry check for T-3481), direct file reads of T-1820/T-1821/T-2918/
T-3396/T-3397, `python3 -m pytest tests/unit/test_peer_subscribe.py` (12/12
PASS, run live), `fw task update T-1820 --owner human` (verb call, logged),
`fw task update T-1820 --status work-completed` (refused, sovereignty gate,
output captured above), `fw task review T-1820` (canonical URL captured
verbatim, not hand-typed), `git log`/`git diff --cached --stat`/`git
status -sb` (commit `b61e32282`, push outcome below), `fw sidecar inbox`
(checked at session start, before the edit, and before finishing — empty
each time except the one non-actionable D-660 DM at session start, which
named itself as needing no reply).

**Push outcome (addendum, written after the fact once the real state was
known — the line above shipped with a live placeholder because the
orchestrating session harvested this file from disk before this addendum
was written; left the original line intact above rather than rewriting
history):** `git push origin bleeding-edge` for commit `b61e32282` did not
resolve quickly. While it was in flight, the orchestrating session (T-3517)
read this handback off disk, committed it itself (`c070da76c`, "harvest
round 2's handback"), and **also** started its own `git push origin
bleeding-edge`. `ps aux` at that point showed **two concurrent `git push
origin bleeding-edge` processes** (PID 507606, started ~16:06; PID 672309,
started ~16:13), both with 0:00 CPU time after 7+ minutes — blocked, not
crashed. This is a live, dated reproduction of the exact hazard T-3297
already names (pre-push audit gate lock contention: "5 commits could not be
pushed for 15+ min... the ONLY documented escape is Tier 0 `git push
--no-verify`"). I did not kill either process (round 1's own lesson: a slow
gate is evidence to investigate, not a hang to route around) and did not
reach for `--no-verify`. Both commits (`b61e32282`, `c070da76c`) are safe
locally regardless of push timing (P-009). Concrete evidence worth adding
to T-3297's own record: this is now a **directly observed concurrent-push
occurrence** of the contention it describes, not just a single-session one
— two sessions sharing one checkout (this worker + its own orchestrator)
each independently hit the same lock at the same time, which T-3297's
existing text doesn't explicitly name as a possible trigger shape.
