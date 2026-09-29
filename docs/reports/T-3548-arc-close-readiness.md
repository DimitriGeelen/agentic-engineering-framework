# T-3548 — Arc close-readiness: quadrant exhaustion, not a completion ratio

**Status:** inception, open. Research artefact per C-001 — created before the research, updated
as the dialogue produces findings.
**Operator:** Dimitri Geelen · **Filed:** 2026-09-29

---

## 1. The proposal, as the operator stated it

> "the threshold for Arc should not be 80%, it should be no high value, low cost, no high cost
> items left anymore, right?"

and, on being asked to write it up:

> "the rationale should be of course no unestimated tasks, point. And then no high value, no Q1,
> Q1 and Q2, quadrant 1 and quadrant 2 tasks left. And then we also talked about validating if
> the [arc] goals are achieved. That's a good one. That can be in the recommendation and
> rationale. And then it goes to the external reviewer and it's done. Same as with the task."

Three legs plus a verdict mechanism:

| | Leg | Shape |
|---|---|---|
| **L1** | No unestimated tasks in the arc | precondition — hard |
| **L2** | No Q1 and no Q2 tasks left | the value test |
| **L3** | Arc goals demonstrably achieved | expressed in Recommendation + Rationale |
| **V** | External reviewer validates; positive outcome closes it | "same as with the task" |

## 2. What the 80% actually is — measured, not assumed

`web/blueprints/approvals.py:484`:

```python
def _load_close_ready_arcs(threshold: float = 0.80) -> list[dict]:
```

It is a **surfacing heuristic** for the Watchtower approvals queue. `lib/arc.sh`'s `arc_close()`
carries **no completion-ratio check at all** — grepping it for `ratio|complete|threshold` returns
only unrelated matches.

**This matters for scope.** Replacing the threshold changes *what the queue offers the operator*,
not *what the framework permits*. That is a far smaller and safer change than "changing the arc
close gate", which is what the phrase sounds like. The real gates on `arc_close()` are untouched
by this: `--demo` (G-062), the §ACD headline-mechanic question, and the `$CLAUDECODE=1`
agent-refusal (T-1671, default-on via `FW_REQUIRE_ARC_CLOSE_APPROVAL`).

## 3. Why the ratio is not merely imprecise but wrong-directional

A completion ratio weights every task equally. Two consequences, both observed in the live corpus
on 2026-09-29:

- **It rises fastest when the cheap work is done.** An arc can walk to 95% by closing trivia
  while its expensive, valuable work sits untouched. Nothing in the measure notices.
- **It flattens genuinely different states.** `arc-003` is 85.4% with **18 open tasks**;
  `arc-019` is 92.3% with **1**. The ratio calls both "nearly done".

A value-aware predicate cannot be gamed in that direction: closing trivia moves it not at all.

## 4. The measurement that constrains the design

Corpus-wide, 3,530 task files:

| | count |
|---|---|
| confirmed `bvp_scores:` | **0** |
| confirmed `cost_estimate:` | **0** |
| estimator-proposed scores (`bvp_scores_proposed:`) | 3,464 |
| proposed cost (`cost_estimate_proposed:`) | 1,278 |

Per close-ready arc, its **open** tasks:

| arc | open | has value | has cost | both |
|---|---:|---:|---:|---:|
| parallel-execution-aef | 2 | 2 | 1 | 1 |
| ewcr-arc0-contract-evidence | 1 | 1 | 1 | 1 |
| inception-review-loop | 1 | 1 | 1 | 1 |
| arc-grooming | 2 | 2 | 1 | 1 |
| orchestrator-rethink | 18 | 18 | 8 | 8 |
| continuous-run | 5 | 5 | 3 | 3 |

Value is near-universal — the estimator proposes on almost everything. **Cost is the sparse
axis**: roughly a third of the corpus, about half of these arcs' open tasks. `blast_radius` only
resolves at close (T-3068), which is why.

Arc-side: **20 of 20** open arcs carry a `headline_mechanic` (G-062 makes it mandatory at
create). **4 of 20** carry `demo_evidence`. There is no `goals:` or `objectives:` field — the
goal *is* the headline mechanic.

## 5. L1 dissolves a trap raised before the operator stated it

Before L1 was on the table, a bare "close when Q1 and Q2 are empty" had a false-green hole:

> A task with no cost has no quadrant. No quadrant means it is in neither Q1 nor Q2. So an
> unscored expensive task would not block closure — it silently is not counted. `arc-003` would
> report "no high-value work left" on the strength of 10 tasks nobody priced.

**L1 closes this by construction.** If an unestimated task *blocks* closure rather than failing
to count, the dangerous direction is removed. Unknown stops meaning cheap.

It also lowers the urgency of OBS-462 (the cost-default ruling) *for this purpose*: a default is
what you need when unknown must still be ranked. L1 says unknown must instead be **resolved**
before the arc can close. The OBS-462 conflict — the operator biases the default low,
1409-sprind's operator biases it high — still needs settling for `fw bvp` ranking, but it is
**not a blocker for this predicate**. That is a better outcome than the dependency the agent
asserted an hour earlier, and the correction is logged in §8.

## 6. The four open questions (IW-1..IW-4 in the task)

### IW-1 — Does "estimated" mean *confirmed* or *marked-proposed*?

Decisive, because the answers differ by three orders of magnitude.

- **Confirmed**: 0 tasks qualify today. Every arc becomes permanently unclosable — today's
  zero-closures-in-five-months with a better-sounding justification. Worse than the ratio.
- **Marked-proposed**: computable now for value on essentially everything, and for cost on ~36%.
  These arcs become decidable once their remaining cost estimates are produced, which
  `fw bvp estimate-cost` can do on demand.

Leaning **marked-proposed with provenance surfaced in the verdict**, so the operator reads
"closed on estimator figures, none confirmed" rather than a bare PASS.

### IW-2 — Which population is the cost median taken over?

`fw bvp` splits on the median of known costs (`lib/bvp.sh:265-272`), and the population is
unspecified for this use. An arc of uniformly expensive work has an internal median that labels
half of it "low cost" — meaningless as a closure test. 1409-sprind measured the adjacent hazard:
defaulted costs joining the median pool moved it 2.45 → 3.2 and silently flipped every task at
3.2 from hv-hc to hv-lc. IW-1's answer constrains this one.

### IW-3 — How is "goals achieved" judged, and does any part mechanise?

The goal is the `headline_mechanic`, and §ACD already asks the binding question — *does the
captured `--demo` artefact show the mechanic firing?* — in prose.

The gap is not the question. It is that **4 of 20 arcs have demo evidence at all**, so L3 is
largely a demand for an artefact that does not yet exist. Mechanising the *judgement* is hard (a
claim about what a screencast shows); mechanising the *precondition* is trivial (is
`demo_evidence` non-empty, does it resolve, is it traceable to the arc).

**Proposed split:** the mechanical half goes to the reviewer; the judgement half stays prose in
the anchor task's Recommendation — exactly where the operator said to put it.

### IW-4 — Is reviewer-gating closure the delegation already made, or a new one?

"Same as with the task" points at two existing rulings:

- **D-586 / T-3429** — arc *driver* approval became reviewer-gated by default; only the negative
  ruling (`--none`) stayed sovereign.
- **D-626 / T-3445** — deterministic Human criteria delegate to the reviewer via
  `fw task delegate`, with six never-convert classes.

Arc closure is structurally similar (a static predicate over declared state) but differs in one
way that should be named rather than glossed: **T-1671 made arc closure agent-refused after a
fourth incident**, in which an agent auto-closed an arc. That refusal is incident-derived, not
general policy. Reversing it is legitimate — it is the operator's to reverse — but it deserves a
decision that cites T-1671 and says what has changed since, not a side-effect of adopting a
better threshold.

Note also that D-626's own carve-outs list *inception go/no-go* as never-delegable, and an arc
close is nearer to a go/no-go than to a criterion check. That is an independent argument for the
IW-3 split: the reviewer certifies the mechanical predicate, the operator rules on the arc.

## 7. Recommendation

**GO** on the definition. **Decompose before building:**

| Slice | What | Depends on | Owner |
|---|---|---|---|
| **A** | Replace `_load_close_ready_arcs`'s ratio with L1+L2. Surfacing only, no gate change. | IW-1, IW-2 | agent |
| **B** | L3's mechanical half — demo-evidence presence/resolvability as a reviewer check. Independent of A. | IW-3 | agent |
| **C** | The verdict: does reviewer PASS *close* the arc, or only clear it for the operator? | **IW-4 — sovereign** | operator |

A and B are agent-buildable once IW-1..IW-3 are answered. C must be ruled before it is built,
not during.

**A note on sequencing that is worth the operator's attention.** Slice A makes the six currently
close-ready arcs *less* likely to surface, not more — because L1 will fail on the ~half of their
open tasks that carry no cost estimate. That is correct behaviour and it is also a short-term
regression in the queue's usefulness. Producing those estimates (`fw bvp estimate-cost` across
~29 open tasks) is small and could precede or accompany Slice A.

## 8. Dialogue log

### 2026-09-29 — origin

Operator, shown 16 open arcs with 6 at/past the 80% mark and zero ever closed: *"the threshold
for Arc should not be 80%, it should be no high value, low cost, no high cost items left anymore,
right?"*

Agent measured rather than agreed: found the 80% is a Watchtower surfacing heuristic rather than
a gate; found 0 confirmed scores and 0 confirmed costs corpus-wide; raised the false-green hole
in a bare quadrant test and asserted a dependency on OBS-462's cost default.

Operator added the leg that removes that dependency — *"no unestimated tasks, point"* — plus goal
validation, and specified the verdict path as *"external reviewer... same as with the task"*.

**Correction recorded:** the agent's claim that OBS-462 must land first was wrong once L1 is part
of the definition. L1 makes unknown *block* rather than *default*, which is the safe direction and
needs no default at all. Recorded here rather than silently dropped.

### 2026-09-29 — gates encountered while filing

Worth logging because they shaped the artefact rather than merely delaying it. `fw inception
start` refused without `--recommendation` and `--rationale` (T-2204), which forced the
recommendation to be written from the measurement rather than after the exploration. The
PreToolUse hook then refused to let this file be written while `## Open Questions` was empty
(T-2194 / G-067) — so IW-1..IW-4 were declared in the task *before* the artefact arguing them
existed. Both refusals produced a better ordering than the one the agent had chosen.
