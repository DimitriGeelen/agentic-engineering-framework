# Autonomous run record — 2026-09-28

**Task:** T-3531 · **Mandate:** operator, 2026-09-28 · **Units of work executed: 0**

The run stopped at selection. This record exists so the next run starts from the
analysis below rather than re-deriving it, and so the zero is auditable rather than
merely asserted.

---

## Stop condition, declared up front

> *Stop at the first of: … **context reaches ~300k** …*

Measured at run start, from `agents/context/checkpoint.sh budget` (the G-087-safe read,
not a raw cache `cat`), cache 93s old:

```
level: unknown          # cache 93s vs 90s max — stale by 3s, hence "unknown"
raw_level: ok
raw_tokens: 274662
```

**274,662 of ~300,000 — 91.5%.** The mandate holds framework governance in force, and
CLAUDE.md §Work Proposal Rule is unambiguous at that level:

| Band | Rule |
|---|---|
| 255K–285K | propose only small bounded tasks; **wrap-up actions** |
| 285K+ | handover immediately, no new work |

with the clause that decides it: *"This applies **especially** in autonomous mode —
without a human to catch the mistake, proposing work that can't complete in remaining
context risks losing all uncommitted work."*

The mandate's own instrument was also unavailable: it directs BVP estimation to the
TermLink estimator worker, and CLAUDE.md requires **40K headroom before dispatching**
for result ingestion. ~25K remained. So the sanctioned route to satisfying
*scored-before-started* could not be taken, and the unsanctioned route (scoring by
estimate) is explicitly forbidden by the same binding.

**Note on the denominator, recorded but NOT acted on.** This session runs
`claude-opus-5[1m]` — a 1M-token window — while `FW_CONTEXT_WINDOW` defaults to 300000.
Against the true window, 274,662 is ~27%, not 91.5%. Raising the ceiling would have
converted the stop condition into permission to continue, so it was left alone: an agent
that widens its own limit to keep working has adjusted a governing parameter in its own
favour, which is the same class the mandate forbids under *producer-not-judge*. It is
filed below as a Sovereign question instead. The operator's mandate named ~300k
explicitly, which is treated as the binding number regardless of the model's capacity.

---

## Selection analysis — as far as it got

### Level 1 — Project
Not reachable as written. The mandate selects top-down "from the project goals and
objectives", but there is no `.context/project/goals.yaml` or `objectives.yaml`; the
nearest written-down equivalents are the **four Constitutional Directives** in CLAUDE.md
(Antifragility > Reliability > Usability > Portability) and `policy/value-drivers.yaml`'s
D1–D4, which are *scoring axes*, not objectives with completion states. **A directive is
not an objective**: you cannot measure how far an arc moves "Antifragility" the way you
can measure progress against a stated objective. Recorded as Sovereign question **SQ-1**.

### Level 2 — Arc
20 arcs, 19 in-progress, 1 draft. Focused arc: **arc-019** (EWCR Arc 0 — contract
evidence and implementation baseline), 20 tasks. Five arcs are stale >30 days
(capability-overlay, horizon-axis-hardening, onboarding-shape-detection,
project-shape-resilience, readme-first-run) per today's audit.

Without Level 1, "the arc whose completion moves a project objective furthest" has no
ordering relation available. The preference for an in-flight arc would point at arc-019
by focus, but that is *inherited focus*, not selection — and inherited focus being
mistaken for a decision is the 41-day `t2539-staging` failure this repo already paid for
(§Release-Train Branch Model).

### Level 3 — Task (BVP quadrant)
This is where the run stops on evidence rather than on budget alone.

**Confirmed scores in the corpus: zero.**

```
$ bin/fw bvp
No tasks have `bvp_scores:` set yet.
```

The mandate binds *"No task is executed before it has a BVP score"* and selects by
quadrant. Nothing is scored, so nothing is eligible.

Falling back to `--include-proposed` (advisory, and explicitly not the same thing) does
not rescue it:

```
NOTE: 172/204 task(s) (84%) have no known cost — blast_radius unmeasured, so no
      quadrant (COST/QUAD show '-'). Quadrant thresholds are computed over the
      32 task(s) that do have one.
```

- **84% have no quadrant at all**, because `components:` only resolves at the
  `work-completed` transition (T-3068) — the cost axis is unavailable precisely for the
  open tasks selection is meant to rank.
- **The 32 that do have one are flat.** The top band is *sixteen tasks tied at exactly
  `108 / 0.40`*, with costs spanning `3.6`–`3.8`. Across the top 40, BVP ranges 97–120
  (norm 0.36–0.44) — roughly **8% spread**. The `hv-lc` / `hv-hc` split is a median cut
  through that band, so it separates 3.6 from 3.7.

**Therefore "Q1 first, to exhaustion" is not executable as specified.** Sixteen tasks tie
for first place. Any pick among them is arbitrary, and reporting an arbitrary pick as
value-ranked would be a false green of the kind this session has now fixed twice
(OBS-560, OBS-562). The instrument does not discriminate, so it is reported as not
discriminating rather than used anyway.

This is **already diagnosed, not newly discovered**: 832's 8-root-cause RCA, our T-3408
answer (D2 83% / F2 91% no-signal vs their 84%/92% → detectors narrow and upstream), and
**OBS-462 — a peer-designed cost-default fix that has been waiting on an unasked operator
ruling since 2026-09-22.** T-3410 (widen the dark D2/F2/free-driver detectors) is
`captured` and never started.

---

## Gates that refused this run, and what was done instead

| # | Gate | What it refused | Action taken |
|---|---|---|---|
| 1 | P-002 task gate (`check-active-task.sh`) | **Discovery itself.** With focus null after T-3529 closed, `fw arc list`, `fw bvp`, and `checkpoint.sh budget` were all refused — the mandate could not read the objectives it selects from. | Created T-3531 via `fw work-on`. Not a workaround: the framework's answer is that work needs a task, and the mandate independently requires a run record, so they are the same artefact. |
| 2 | G-020 build-readiness | Refused all reads again once T-3531 existed, because a new task ships with placeholder ACs. | Wrote T-3531's real ACs first, via the Write tool (task files are exempt). |
| 3 | P-002, again | `fw termlink cleanup` — `judge-arc-r1` is still registered and idle after finishing. | Left registered. Not bypassed. |

Gates 1 and 3 are the same defect, **OBS-250, now at eleven instances** — three today
(me twice, worker `judge-arc-r1` once, which had to file T-3530 purely to commit). It
now costs a task per close, and it blocked an autonomous mandate at step zero. The
framework prompted for a T-3529 learning at close and then refused the command that
records it.

No gate was bypassed at any point in this run. Verified against the **Tier-2 bypass log**
(`.context/working/.gate-bypass-log.yaml`), whose latest entry predates this run's start
(`02:21:32Z` vs `09:37:55Z`) — i.e. measured against what executed.

**The first version of that check was wrong, and the way it was wrong is the day's
recurring defect.** It grepped this run's own commit messages for `--force`, `--skip-*`,
`FW_ALLOW_*` and `--i-am-human`, and failed — on the sentence stating that none of them
were used. A compliance check that cannot tell a **mention** from an **instance** (L-576)
reports the act and the denial of the act identically. That is the third instance today,
after `grep -qv undecidable` (any line lacking the word satisfies it) and the G-020 gate
refusing T-3528's acceptance criteria for quoting the stub they were about to fix
(OBS-561). The fix in every case is the same shape: measure the event, not the prose
about it.

---

## Sovereign questions — surfaced, unresolved, priority order

**SQ-1 — What are the project's objectives, as a written artefact selection can read?**
*Blocks:* every top-down selection, this mandate included. The four Constitutional
Directives are scoring axes with no completion state; arcs have goals but no parent they
ladder up to. Until this exists, "advance a project objective" cannot be evaluated and
arc ordering has no relation to sort by.

**SQ-2 — OBS-250: which mechanism closes the closed-task trailing-work dead end?**
*Blocks:* every task close, at a cost of one extra task each. Candidates, unchanged from
when they were surfaced: (a) grace window on focus after close *(recommended — smallest
change, and the problem is temporal)*; (b) narrow allowlist for `vendor self`,
`add-learning`, `termlink cleanup` with focus null; (c) auto-run the trailing verbs at
close. Deliberately not decided here: it is a governance change to a Tier-1 gate.

**SQ-3 — OBS-462: ratify the peer's cost-default fix, or reject it?**
*Blocks:* the cost axis, hence 84% of quadrant assignment, hence Q1/Q2 selection. A peer
project designed the fix and it has sat unasked for six days. This is the single highest-
leverage unblock for any future run under this mandate.

**SQ-4 — Should `FW_CONTEXT_WINDOW` track the running model's real window?**
*Blocks:* nothing today; it makes every budget band wrong by ~3.3x on a 1M model, in the
conservative direction. Left unchanged on purpose (see above) — an agent must not widen
its own ceiling.

---

## Cost vs estimate

No units dispatched, so no per-unit deltas. One figure from the immediately preceding
work, recorded because the mandate asks for calibration feedback and this is the only
measurement available:

**T-3527 (`judge-arc-r1`)** — 504,259 new tokens (input 3,629 + cache-create 368,630 +
output 132,000), 32,571,142 cache read. Source: `modelUsage` on the result line via
`lib/dispatch_tokens.py`. Per-turn `usage` summation was measured wrong by ~66x on output
earlier in this session (935 vs 62,051) and must not be used.

Calibration note worth feeding back: the worker's own estimate line for T-3528 read
`effort=8 (lines=269,acs=4)` while the delivered task carried 7 ACs and ~1,400 lines
changed — the effort heuristic reads the task file *at scoring time*, which for a task
scored at capture is before it has been scoped.

---

## Handback

**Objectives advanced:** none, measured against run start. Zero units executed. The run
stopped at selection, on the mandate's own stop condition plus an instrument that does
not discriminate.

**Arc state:** unchanged by this run. 20 arcs (19 in-progress, 1 draft), focus arc-019.
Tasks by quadrant is not reportable in the form the mandate asks for: 0 confirmed scores,
and of 204 proposed-scored tasks, 172 (84%) have no quadrant.

**What remains in Q1/Q2, and why it was not done:** not determinable. Sixteen tasks tie
at the top of the proposed ranking, so no Q1 head exists to work "to exhaustion".

**Delivered by this run:** this record, and T-3531 as its anchor. The next run under this
mandate starts from the analysis above, and its first move should be SQ-3 → SQ-2 → SQ-1,
in that order, because each unblocks more of the mandate than the one after it.
