# T-3072 — Predicted blast radius for open tasks

**Status:** inception, awaiting operator go/no-go
**Predecessor:** T-3068 (made unknown-cost honest; explicitly deferred this half)
**Question:** is there a signal available *before* `work-completed` that predicts
blast radius well enough to steer by, and can it be shown without being mistaken
for a measurement?

---

## 1. Why now

The operator's standing instruction is *"focus on HV/LC & HV/HC tasks and run BVP
estimator regularly"*. Run today, the tool refuses to answer:

```
NOTE: 115/141 task(s) (82%) have no known cost — blast_radius unmeasured, so no
      quadrant (COST/QUAD show '-').
      Quadrant thresholds are computed over the 26 task(s) that do have one.
```

The 26 tasks that *do* have a cost are almost entirely inceptions, which get theirs
from the T-2189 `target_blast_radius` exception. So the quadrant column is not
partitioning on cost — it is partitioning on workflow type, and the instruction to
prefer HV/LC over HV/HC has nothing underneath it.

This is not a defect introduced by T-3068. T-3068 *revealed* it: before that change
the same 82% were scored `blast_radius: 0`, which is the cheapest value on the
term carrying weight 0.6, so they read as maximally attractive. Honest silence is
strictly better than confident wrongness. It is still silence.

## 2. The mechanism, restated

`components:` is populated at the `work-completed` transition — `update-task.sh`
resolves it from git history, because that is the first moment the answer is
knowable for certain. `fw bvp` excludes `work-completed` by default (T-2223),
because the rank answers *"what should I work on next"*.

Both decisions are individually right. Together they guarantee the dominant cost
input is available only for the population the ranking excludes.

## 3. Spike 1 — does any pre-close signal exist?

**Method.** For each open task (`captured` / `started-work` / `issues`), scan the
body for repo-relative paths with a recognised extension and keep those that
resolve to a file that actually exists.

**Result.**

| measure | value |
|---|---|
| open tasks scanned | 141 |
| naming ≥1 existing repo path | **129 (91%)** |
| median paths named | 3 |
| max | 18 (T-1719) |

The signal exists and is close to universal. Task authors describe what they intend
to touch, because that is what a task body is for.

## 4. Spike 2 — is the signal any good?

**Method.** Take the completed tasks that hold a real `components:` list (resolved
from git history at close — ground truth, not another guess). Re-derive a prediction
from the body text alone, ignoring the frontmatter. Compare.

**Result, and the effect of scoping:**

| variant | n | recall | precision | ladder exact | within-one-rung | over : under |
|---|---:|---:|---:|---:|---:|---|
| all paths | 1084 | 0.50 | 0.33 | 32% | 79% | 534 : 124 |
| excl. `docs/` `.tasks/` `.context/` | 1066 | 0.50 | 0.50 | 37% | 82% | 444 : 122 |
| **source dirs only** | **985** | **0.75** | **0.50** | **36%** | **82%** | **421 : 112** |

*Source dirs* = `lib/ bin/ agents/ web/ tests/ policy/`.

Three things this says:

1. **Scoping to source directories is what makes the proxy work.** Recall goes
   0.50 → 0.75 purely by refusing to count the task's own artefacts, sibling task
   references, and `docs/reports/` citations. Those are *mentions*, not *touches* —
   the distinction the naive scan cannot make and the path prefix can.
2. **Exact ladder agreement is 36%, and that is the wrong bar.** The ladder is
   non-linear on purpose; its own docstring says *"a component count of 7 vs 8 is
   rarely meaningful, but 1 vs 5+ is"*. Within-one-rung — 82% — is the metric that
   matches the ladder's own claim about itself.
3. **The error is directional, 3.8 : 1 toward over-pricing.** This matters more than
   the headline accuracy, and §6 explains why.

## 5. What the numbers do *not* say

Precision 0.50 means half of the source paths a task names are not files it ends up
touching. Recall 0.75 means a quarter of what it touches was never named. This is a
proxy with real error in both directions, and it should never be described as a
measurement. L-589, surfaced by `fw work-on` on this very task, is the exact
statement of the trap:

> A structural proxy plus an inference is not a measurement, and the inference is
> where the error lives.

The response is not to claim the error away. It is to carry the label with the
number everywhere the number goes.

## 6. Why over-pricing is the acceptable failure

A cost axis is consumed by a filter that prefers *low* cost. So the two errors are
not symmetric:

- **Over-price a task** → it drops out of HV/LC → it does not get promoted → the
  operator notices it sitting unworked and can correct. Visible, recoverable.
- **Under-price a task** → it rises to the top of HV/LC → it gets promoted → the
  cost surfaces during the work. This is exactly T-3068's inverted signal, and it
  is invisible until it has already happened.

Measured bias is 421 over to 112 under, so the proxy fails predominantly in the
direction the operator can see. That is the argument for shipping it — not the
accuracy figure on its own.

## 7. Recommendation

**GO**, with the labelling constraint as a hard condition rather than a nicety.

**Build slice shape (for the child task, not decided here):**

1. `score_blast_radius` gains a second, clearly separate source: when
   `components:` is empty, derive a count from source-directory paths named in the
   body and run it through the *same* ladder.
2. The returned estimate carries `source: predicted-from-body-paths`, distinct from
   the measured path. `cost_estimate_proposed:` already carries a `source` field and
   `fw bvp` already prints a SOURCE column — the seam exists and does not need
   inventing.
3. Every surface that shows a cost shows which kind it is. The existing NOTE line
   must not simply vanish when the unknown count falls; it should report the
   predicted/measured split instead.
4. `fw bvp auto-promote` keeps requiring a *measured* cost. Predicted costs inform
   the human's ranking; they do not silently start promoting tasks on their own.
   This is the clause that keeps the change reversible.

**What would make this NO-GO:** writing the prediction into `cost_estimate:`, or
rendering it identically to a measured value. Either would be worse than the
current honest silence, because a confident wrong number is harder to distrust than
a blank.

**Deferred (IW-5):** weighting by fabric dependency edges rather than raw path
count. Almost certainly a better definition of blast radius — and precisely for
that reason it cannot ship in the same change, because it would make predicted and
measured values incomparable. Revisit after predicted-vs-measured has been observed
on live rankings.

## 8. Reproducing the numbers

Both spikes are pure read-only scans over `.tasks/`; nothing in them depends on
session state. The scan definition is in §3 and §4 — path regex restricted to
`lib/ bin/ agents/ web/ tests/ policy/`, existence-checked against the working
tree, compared against `components:` parsed from completed-task frontmatter. The
ground-truth population is every completed task holding a non-empty `components:`
list (985 under source-dir scoping, 1084 unfiltered).

## 9. Dialogue Log

- **2026-08-18 — agent, unprompted.** Ran `fw bvp` as part of the standing "run BVP
  estimator regularly" directive; the tool's own NOTE line reported 82% of ranked
  tasks with no quadrant. Traced to T-3068's deferred half rather than treating it
  as a fresh finding.
- **2026-08-18 — agent → self, course correction.** First instinct was to file a
  build task for a body-path scan. Stopped: T-3068 had already labelled this "a
  bigger change with its own design questions", and the naive scan measured at
  precision 0.33. Ran the ground-truth comparison (Spike 2) *before* proposing
  anything, which is what produced the source-directory scoping and changed the
  recommendation from "count paths" to "count source paths, and label them".
- **Open for the operator.** IW-3 (is 82% within-one-rung enough to steer by?) is
  filed at confidence 2, deliberately. It is a judgement about acceptable error, not
  a fact, and it is the one to overturn if the operator disagrees.
