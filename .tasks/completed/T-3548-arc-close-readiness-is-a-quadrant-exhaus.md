---
id: T-3548
name: "Arc close-readiness is a quadrant-exhaustion predicate, not a completion ratio
  — and the verdict is reviewer-gated like a task"
description: >
  Inception: Arc close-readiness is a quadrant-exhaustion predicate, not a completion
  ratio — and the verdict is reviewer-gated like a task

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-09-29T06:55:58Z
last_update: 2026-09-29T07:18:07Z
date_finished: 2026-09-29T07:18:07Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-09-29T06:58:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-09-29T07:00:20Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=7 (lines=166,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3548: Arc close-readiness is a quadrant-exhaustion predicate, not a completion ratio — and the verdict is reviewer-gated like a task

## Problem Statement

Sixteen arcs are open. Six sit at or past the ≥80% completion mark. **`closed_at` is null on
every one of the twenty arcs that have ever existed** — zero closures in five months.

The threshold deciding which arcs surface as close-ready is a **completion ratio**, and the
operator's objection is that a ratio measures the wrong thing: it weights a typo fix and a
keystone identically, and it rises fastest when the cheap work is done. Measured on the live
corpus, `arc-003` is 85.4% with 18 open tasks and `arc-019` is 92.3% with 1 — the ratio calls
both "nearly done".

Proposed instead: an arc is close-ready when **(L1)** no task in it is unestimated, **(L2)** no
Q1 or Q2 task remains — no high-value work, cheap or expensive — and **(L3)** its goals are
demonstrably achieved, argued in the anchor's Recommendation. The verdict goes to the external
reviewer, "same as with the task".

Full measurement, the four open questions, and the proposed decomposition:
`docs/reports/T-3548-arc-close-readiness.md`.

**Why now:** the closure rate is the binding constraint on the whole system. 290 of 493 active
task files are already `work-completed` and waiting on human criteria; six arcs are waiting on a
ruling. Production is not the bottleneck — ratification is. A threshold that surfaces the wrong
arcs makes that worse.

## Assumptions

- **A1 — the estimator's proposed scores are good enough to gate an arc closure on.** Untested.
  3,464 tasks carry them; nothing has ever confirmed one, so their accuracy is unmeasured. IW-1
  turns on this.
- **A2 — "no Q1/Q2 left" is reachable in practice.** If value scores cluster high (the estimator
  gave this very task D1..D4 = 2 across the board with rationale `no-signal`), most tasks may
  land high-value by default and no arc ever empties its Q1. Worth a spike before building.
- **A3 — the reviewer can certify L1 and L2 without judgement.** They are arithmetic over
  declared fields, so this looks safe; L3 is where judgement actually lives, which is why the
  artefact proposes splitting it.

## Open Questions

<!-- T-2190 (T-2186 Slice 4): every IW-N question must be disposed before
     --status work-completed. Disposition gate (agents/task-create/update-task.sh
     check_disposition_gate) refuses on under-disposed inceptions.

     Per-question shape:

       - **IW-1: <question text>**
         confidence: 0-3      (your confidence in your current answer; 0=guess, 3=verified)
         disposition: answered | deferred | dissolved
         rationale: <one-line evidence — file:line, decision id, dialogue ref>

     Never bare yes/no — the gate refuses bare checkboxes. See 050-Inceptions.md
     §Disposition Gate. Bypass: --skip-disposition-gate "rationale" (direct) or
     FW_SKIP_DISPOSITION_GATE=1 (env-var, T-1890 producer/consumer parity).
-->

- **IW-1: Does "no unestimated tasks" mean CONFIRMED estimates, or marked-PROPOSED ones?**
  confidence: 2
  disposition: answered
  rationale: ANSWER — MARKED-PROPOSED counts as estimated, and the verdict must name the
    provenance ("closed on estimator figures, N of M confirmed"). A GO on this task ratifies
    that reading; say otherwise and it becomes confirmed-only.
    Decisive and three orders of magnitude apart. Measured 2026-09-29 over 3,530
    task files: confirmed `bvp_scores:` = 0, confirmed `cost_estimate:` = 0, proposed scores
    = 3,464, proposed cost = 1,278. Reading it as CONFIRMED makes every arc permanently
    unclosable, reproducing today's zero-closures-in-five-months with a better-sounding
    justification. Reading it as MARKED-PROPOSED is computable now for value and for ~36% of
    cost. Leaning proposed-with-provenance so the verdict reads "closed on estimator figures,
    none confirmed" rather than a bare PASS. Operator's call.

- **IW-2: Q1/Q2 membership needs a cost median — over the ARC's tasks or the CORPUS? And how
    is tied-at-median value treated?**
  confidence: 2
  disposition: answered
  rationale: ANSWER, two parts. (i) The cost median is taken over the CORPUS, not the arc — an
    arc-internal median labels half of any uniformly-expensive arc "low cost" by construction,
    which is meaningless as a closure test. (ii) Tied-at-median value stays HIGH-value (the
    existing `>=`), accepted as a CHOSEN conservative behaviour: it over-counts Q1 by about the
    tied cohort and therefore keeps arcs OPEN rather than closing them early. The alternative —
    extending T-3485's withholding to non-degenerate medians — is deliberately NOT taken here,
    because T-3485's own comment argues that moving tied mass to the other side is equally
    invented. A GO ratifies both parts.
    `lib/bvp.sh:265-272` splits on the median of known costs, and the population is
    unspecified for this use. An arc of uniformly expensive work has an internal median that
    labels half of it "low cost", which is meaningless as a closure test. 1409-sprind measured
    the adjacent hazard: defaulted costs entering the median pool moved it 2.45 -> 3.2 and
    silently flipped every task at 3.2 from hv-hc to hv-lc. IW-1's answer constrains this.
    S4 ADDED A SECOND HALF, measured 2026-09-29 over 204 ranked tasks: the value axis has only
    31 distinct norm values, and 36 tasks sit EXACTLY on the median (0.26). The comparison is
    `>=`, so all 36 are promoted to high-value. T-3485's QUAD_VALUE_WITHHELD exists for this
    equality defect but is deliberately scoped to fire only when the median collapses onto the
    corpus floor (0.04 here), so it stays silent. Net: L2 will over-count Q1 by roughly the
    tied cohort, which keeps arcs OPEN — conservative, but it should be a chosen behaviour
    rather than a discovered one.

- **IW-3: How is "arc goals achieved" judged, and does any part of it mechanise?**
  confidence: 2
  disposition: answered
  rationale: ANSWER — L3 SPLITS. The reviewer certifies only the mechanical half: `demo_evidence`
    is non-empty, resolves, and is traceable to the arc. The judgement half — does the artefact
    show the `headline_mechanic` firing — stays prose in the anchor task's Recommendation and
    remains the operator's, which is where the operator said to put it. This keeps §ACD's binding
    question exactly where G-062 put it and adds only a precondition check. A GO ratifies the
    split. Consequence to expect: 16 of 20 open arcs currently fail the mechanical half outright,
    because they have no demo at all.
    The goal is `headline_mechanic` (present on 20 of 20 open arcs; G-062 mandates it
    at create). §ACD already asks the binding question — does the captured `--demo` show the
    mechanic firing — in prose. Only 4 of 20 open arcs have `demo_evidence` at all, so this leg
    is mostly a demand for an artefact that does not exist yet. Proposed split: the mechanical
    half (demo present, resolvable, traceable to the arc) is reviewer-checkable; the judgement
    half (does it show the mechanic firing) stays prose in the anchor's Recommendation, which is
    where the operator said to put it.

- **IW-4: Is reviewer-gating arc CLOSURE the delegation already made, or a new sovereignty step?**
  confidence: 1
  disposition: deferred
  rationale: DEFERRED ON PURPOSE, and not to the build work — to its own operator ruling. This
    is the one Sovereign question in the set and an agent must not dispose of it by answering
    it. A GO here authorises Slices A and B (the predicate and the mechanical demo check, both
    surfacing-side) and explicitly does NOT authorise Slice C. Deferring is the correct
    disposition rather than a dodge: T-1671's refusal is incident-derived, so reversing it needs
    a decision that cites the incident and states what has changed — which cannot be produced by
    this exploration. If the operator wants C, the cleanest route is to say so and let it be
    filed as its own inception with its own rationale.
    "Same as with the task" points at D-586/T-3429 (driver approval became
    reviewer-gated by default) and D-626/T-3445 (deterministic Human criteria delegate to the
    reviewer). But T-1671 made arc closure agent-refused after a FOURTH incident in which an
    agent auto-closed an arc — the refusal is incident-derived, not general policy, and reversing
    it deserves a decision citing T-1671 and stating what has changed, not a side-effect of
    adopting a better threshold. D-626's own carve-outs list inception go/no-go as
    never-delegable, and an arc close is nearer to a go/no-go than to a criterion check.
    Sovereign; must be ruled before Slice C is built, not during.

## Exploration Plan

Done already (this session, read-only):

- **S1 — locate the threshold.** Found at `web/blueprints/approvals.py:484`; confirmed
  `lib/arc.sh:arc_close()` has no ratio check. Result: this is a *surfacing* change, not a gate
  change. Materially smaller scope than the phrasing suggests.
- **S2 — measure estimate coverage.** 3,530 task files: 0 confirmed scores, 0 confirmed costs,
  3,464 proposed scores, 1,278 proposed costs. Per-arc breakdown in the artefact.
- **S3 — measure arc-side goal evidence.** 20/20 open arcs have `headline_mechanic`; 4/20 have
  `demo_evidence`; no `goals:` field exists — the goal *is* the mechanic.

Still open, and small:

- **S4 (time-box 30 min) — does A2 hold?** Compute the would-be Q1/Q2 split over the six
  close-ready arcs using proposed scores, and see whether any arc empties. If value clusters
  uniformly high, L2 never fires and the predicate is decorative. This is the one spike that can
  invalidate the design, so it should run before Slice A.
- **S5 (time-box 20 min) — cost the gap.** `fw bvp estimate-cost` across the ~29 open tasks in
  those six arcs; report how many resolve and how many come back `blast_radius: unknown` because
  `components:` only resolves at close (T-3068).

No prototype is needed before a decision. S4 and S5 are measurements over existing data.

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN** — the definition of close-*readiness* (what surfaces in the approvals queue), the
estimate precondition, the quadrant test, the mechanical half of goal-validation, and the
question of who issues the verdict.

**OUT, explicitly:**

- **Changing `arc_close()`'s existing gates.** `--demo` (G-062), the §ACD headline-mechanic
  question and the `$CLAUDECODE=1` refusal (T-1671) are untouched by Slices A and B.
- **Resolving OBS-462.** The cost-default conflict (operator biases low, 1409-sprind's operator
  biases high) still matters for `fw bvp` ranking. L1 makes it a non-blocker *here* — unknown
  blocks rather than defaults — and it stays open on its own terms.
- **Closing any arc.** This inception produces a definition, not a closure. The six close-ready
  arcs remain the operator's to rule on under the current rules until a decision changes them.
- **Retro-estimating the corpus.** Only the open tasks of arcs being assessed need estimates.
  3,530 tasks do not.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO

**Rationale:**

The 80 percent ratio is a surfacing heuristic in web/blueprints/approvals.py:484, not a gate, so replacing it changes what the approvals queue offers rather than what is permitted — the change is cheap. It is also actively misleading: it weights a typo fix and a keystone identically and rises fastest when the easy work is done, so arc-003 (85.4 percent, 18 open) and arc-019 (92.3 percent, 1 open) read as the same kind of nearly-done. The operator's definition — no unestimated tasks, no Q1 or Q2 left, arc goals demonstrably achieved — is value-aware and cannot be gamed that way, and its first leg closes the false-green hole that a naive quadrant threshold would open, because an unestimated task BLOCKS closure instead of silently failing to count. Open questions are real but bounded and are what this inception is for: whether estimated means confirmed (0 of 3530 today) or marked-proposed (3464 value, 1278 cost), how goal-achievement is judged against headline_mechanic when only 4 of 20 open arcs have captured demo evidence, and whether reviewer-gating arc closure is the same delegation D-586 and D-626 already made or a larger sovereignty step that needs its own ruling.

**Evidence:**

- `web/blueprints/approvals.py:484` — `_load_close_ready_arcs(threshold: float = 0.80)`. A
  surfacing heuristic. `lib/arc.sh:arc_close()` has no ratio check; grepping it for
  `ratio|complete|threshold` returns only unrelated matches.
- 3,530 task files: **0** confirmed `bvp_scores:`, **0** confirmed `cost_estimate:`, 3,464
  proposed scores, 1,278 proposed costs.
- Open tasks in the six close-ready arcs — value present on all 29, cost present on 15.
- **20 of 20** open arcs carry `headline_mechanic`; **4 of 20** carry `demo_evidence`. No
  `goals:` field exists; the goal is the mechanic.
- 16 open arcs, `closed_at` null on all of them, over five months.
- Full working: `docs/reports/T-3548-arc-close-readiness.md`.

**What a GO authorises, and what it does not.** GO authorises Slices A and B only — the
predicate and the mechanical half of goal-validation, both surfacing-side. **Slice C (whether a
reviewer PASS closes an arc, or only clears it for you) is NOT authorised by this GO** and is
recorded as IW-4. T-1671 made arc closure agent-refused after a fourth incident in which an
agent auto-closed an arc; reversing that deserves its own decision citing what has changed, not
a side-effect of adopting a better threshold. If you want C, say so explicitly and it becomes a
separate ruling.

**One sequencing consequence worth knowing before you decide.** Slice A will make the six
currently close-ready arcs *stop* surfacing, because L1 fails on the roughly half of their open
tasks that carry no cost estimate. That is correct behaviour and a short-term regression in the
queue's usefulness. Producing those ~14 missing estimates is small and can precede A.

**Evidence:**

<!-- Add evidence bullets as exploration progresses (file paths,
     commit hashes, test results). The filing-time recommendation
     can be revised before fw inception decide. -->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: The 80 percent ratio is a surfacing heuristic in web/blueprints/approvals.py:484, not a gate, so replacing it changes what the approvals queue offers rather than what is permitted — the change is cheap. It is also actively misleading: it weights a typo fix and a keystone identically and rises fastest when the easy work is done, so arc-003 (85.4 percent, 18 open) and arc-019 (92.3 percent, 1 open) read as the same kind of nearly-done. The operator's definition — no unestimated tasks, no Q1 or Q2 left, arc goals demonstrably achieved — is value-aware and cannot be gamed that way, and its first leg closes the false-green hole that a naive quadrant threshold would open, because an unestimated task BLOCKS closure instead of silently failing to count. Open questions are real but bounded and are what this inception is for: whether estimated means confirmed (0 of 3530 today) or marked-proposed (3464 value, 1278 cost), how goal-achievement is judged against headline_mechanic when only 4 of 20 open arcs have captured demo evidence, and whether reviewer-gating arc closure is the same delegation D-586 and D-626 already made or a larger sovereignty step that needs its own ruling.

**Date**: 2026-09-29T07:18:06Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-09-29T06:58:16Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-09-29T07:18:06Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** The 80 percent ratio is a surfacing heuristic in web/blueprints/approvals.py:484, not a gate, so replacing it changes what the approvals queue offers rather than what is permitted — the change is cheap. It is also actively misleading: it weights a typo fix and a keystone identically and rises fastest when the easy work is done, so arc-003 (85.4 percent, 18 open) and arc-019 (92.3 percent, 1 open) read as the same kind of nearly-done. The operator's definition — no unestimated tasks, no Q1 or Q2 left, arc goals demonstrably achieved — is value-aware and cannot be gamed that way, and its first leg closes the false-green hole that a naive quadrant threshold would open, because an unestimated task BLOCKS closure instead of silently failing to count. Open questions are real but bounded and are what this inception is for: whether estimated means confirmed (0 of 3530 today) or marked-proposed (3464 value, 1278 cost), how goal-achievement is judged against headline_mechanic when only 4 of 20 open arcs have captured demo evidence, and whether reviewer-gating arc closure is the same delegation D-586 and D-626 already made or a larger sovereignty step that needs its own ruling.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fd5e2cc7
- **Timestamp:** 2026-09-29T07:18:08Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-1
     - evidence: `IW-1 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-63ca97d7
- **Timestamp:** 2026-09-29T07:18:08Z
- **Overall:** CONTRADICTED
- **Claims:** 4

| Claim | Type | Status |
|-------|------|--------|
| `web/blueprints/approvals.py:484` | file_line | ✓ pass |
| `lib/arc.sh:arc_close()` | file | ✗ fail — file not found at PROJECT_ROOT |
| `docs/reports/T-3548-arc-close-readiness.md` | file | ✓ pass |
| `T-1671` | task | ✓ pass |

### 2026-09-29T07:18:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
