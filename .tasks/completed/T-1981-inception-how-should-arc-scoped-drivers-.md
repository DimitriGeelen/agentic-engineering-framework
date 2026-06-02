---
id: T-1981
name: "Inception: how should arc-scoped drivers contribute to per-task BVP?"
description: >
  T-1980 surfaced gap: tasks in an arc with scoped_drivers (e.g. arc-006 with estimator-fidelity,
  sovereignty-preservation, adoption-friction) do not include those drivers in their
  BVP calculation. _compute_bvp skips drivers without scores. Estimator only writes
  D1-D4. Question: should estimator be extended to score scoped drivers per arc, should
  there be a separate manual scoring path, or do scoped drivers contribute differently
  (weight on arc-rollup only)? Related: T-1956 (arc rollup), T-1980 (per-task BVP
  block), T-1925 (driver workflow).

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: [web/blueprints/tasks.py, web/templates/task_detail.html]
related_tasks: []
created: 2026-05-21T14:56:35Z
last_update: 2026-05-22T18:37:00Z
date_finished: 2026-05-22T18:37:00Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
cost_estimate_proposed:
  - ts: '2026-05-21T15:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-22T15:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-21T15:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1981: Inception: how should arc-scoped drivers contribute to per-task BVP?

## Problem Statement

Tasks in an arc with `scoped_drivers:` (arc-006 value-prioritisation has
estimator-fidelity, sovereignty-preservation, adoption-friction) do **not**
include those drivers in their per-task BVP score. `_compute_bvp` skips drivers
without scores; the estimator only emits proposals for global D1-D4. A task
within arc-006 therefore carries the same per-task BVP fingerprint as a task
outside any arc — scoped drivers exist as an arc-level dimension but never
propagate to task scores.

**For whom?** The human ranking BVP tasks via `/bvp` and `/arcs/<id>` — they
expect tasks inside a scoped-driver arc to reflect the arc's value axes.

**Why now?** T-1980 shipped per-task BVP blocks on `/tasks/T-XXX`. The block
shows global D1-D4 but no arc-scoped contribution. The asymmetry between
arc-rollup (uses scoped drivers via T-1956) and per-task (doesn't) became
visible and prompted this inception.

## Candidate Models

**A. Per-task scoping (maximalist)** — Estimator extended to score each task
against the arc's scoped drivers in addition to D1-D4. `_compute_bvp` sums
global + scoped equally. Symmetric semantic with D1-D4.

**B. Arc-level only (conservative — RECOMMENDED)** — Scoped drivers contribute
only at the arc-rollup layer (T-1956). Per-task BVP stays D1-D4. Clear
separation: global drivers = per-task fingerprint; scoped drivers = arc-level
axis. No estimator change. Per-task BVP block on `/tasks/T-XXX` explains:
"this arc's scoped drivers contribute at arc level only — see `/arcs/<id>`
for rollup".

**C. Arc-derived (middle)** — Per-task BVP includes scoped drivers but every
member task inherits the arc-rollup's weighted scoped score as a constant.
Tasks within an arc share scoped credit equally; no per-task discrimination
on the scoped axis.

**D. Human-only manual scoring** — Add per-task scoped-driver scoring to
`/bvp` UI; estimator never proposes scoped scores. Tasks earn scoped credit
only when the human manually scores them.

## Assumptions

- Arc-006's scoped drivers (estimator-fidelity, sovereignty-preservation,
  adoption-friction) are **arc-distinguishing**, not task-distinguishing —
  they describe the dimension the *arc* is valued on, not how individual
  tasks within the arc differ.
- The heuristic estimator cannot produce signal-bearing scores for arc-specific
  drivers without per-arc rubrics (each scoped driver would need its own
  body-pattern matchers like the global D1-D4 estimator has).
- Without per-arc rubrics, A and D produce mostly no-signal proposals or
  blank scores → noise in per-task BVP for negligible gain.

## Exploration Plan

1. **Quantify the gap** — Count tasks in arcs with non-empty `scoped_drivers:`.
   Currently: arc-006 has 3 scoped drivers + ~30 constituent tasks.
2. **Cost-benefit of A** — Estimating an arc-specific rubric for one driver
   (e.g. estimator-fidelity) requires defining body patterns. Time-cost per
   driver: ~1 hour of pattern design + tests. Benefit: per-task signal only
   if the patterns actually distinguish tasks.
3. **Compare B vs. C** — B has zero implementation cost. C requires `_compute_bvp`
   to read arc-rollup and seed scoped-score constant for each member task —
   adds a cache-invalidation surface.

## Technical Constraints

- `_compute_bvp` lives in `lib/bvp.py` — its current shape iterates over driver
  scores on the task. Extending to include arc-derived constants (C) means
  reading arc YAML at compute time → cache invalidation surface.
- Estimator (`agents/termlink/bvp-estimator/`) writes `bvp_scores_proposed:`
  to task frontmatter. Adding scoped drivers would require per-arc rubric
  config — new YAML structure.
- T-1956 (arc rollup) already handles scoped-driver weighting at arc level.

## Scope Fence

**IN scope:** Decide A/B/C/D. The build child (if GO) ships `ships_in:`
referents for the chosen model.

**OUT of scope:** Per-arc estimator rubric design (follow-up build only if A
is chosen). UI changes beyond explanatory text (T-1980 sibling).

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

**GO (model B) if:**
- The asymmetry is acceptable as long as the per-task UI explains it (scoped
  drivers contribute at arc level only, see `/arcs/<id>` for rollup)
- The user agrees per-task BVP is a fingerprint of generic value (D1-D4) and
  arc-scoped value lives at arc level

**GO (model A or C) if:**
- The user wants per-task discrimination on arc-scoped axes AND is willing to
  invest in per-arc rubric design (A) OR accept constant-per-arc seeding (C)

**NO-GO if:**
- The decision should wait until arc-007/008 ship and we see whether scoped
  drivers in general are arc-distinguishing or task-distinguishing in practice

**DEFER if:**
- arc-006 is the only arc with scoped drivers right now; sample size = 1.
  Waiting for arc-007 to land scoped drivers would give a 2-arc comparison
  before locking in a model

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

**Recommendation:** GO — model B (arc-level only)

**Rationale:** Scoped drivers are arc-distinguishing by design (T-1925 framing —
"what distinguishes this arc from global D1-D4"). Per-task scoring on an
arc-distinguishing axis is semantically muddled: every member task of arc-006
would get the same scoped score from the estimator (no per-task signal in
arc-006's scoped drivers without per-arc rubrics). Model B preserves the
separation cleanly: D1-D4 = per-task fingerprint, scoped = arc-level axis,
visible via `/arcs/<id>` rollup (already implemented in T-1956).

Model A would require ~3 hours per scoped driver for rubric design +
estimator extension + tests, with poor signal-to-noise for arc-006's
specifically arc-level drivers (estimator-fidelity is *about* the estimator,
not *of* the task). Model C adds compute-time arc-YAML reads to `_compute_bvp`
with no marginal signal benefit. Model D leaves estimator and adds manual
UI burden for a UX that's not been requested.

The minimum-cost path to closing the visible asymmetry: ship a one-liner in
the `/tasks/T-XXX` per-task BVP block explaining the separation.

**Evidence:**
- arc-006 scoped drivers: estimator-fidelity, sovereignty-preservation, adoption-friction. Reading rationales in `.context/arcs/value-prioritisation.yaml`: all three describe what arc-006 *is about*, not what individual tasks differ on
- T-1956 already handles scoped-driver weighting at arc-rollup level
- `lib/bvp.py:_compute_bvp` skips drivers without scores — adding scoped drivers without scores changes nothing; the question is whether to add scores
- Estimator at `agents/termlink/bvp-estimator/estimator.py` has per-D1-D4 pattern matchers — extending to a 4th-driver-class without rubric data is a no-op (produces no-signal proposals)
- T-1980 surfaced the asymmetry visibly on `/tasks/T-XXX` — a one-liner explanation closes the UX gap without touching the model

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

**Rationale**: Scoped drivers are arc-distinguishing by design (T-1925 framing —
"what distinguishes this arc from global D1-D4"). Per-task scoring on an
arc-distinguishing axis is semantically muddled: every member task of arc-006
would get the same scoped score from the estimator (no per-task signal in
arc-006's scoped drivers without per-arc rubrics). Model B preserves the
separation cleanly: D1-D4 = per-task fingerprint, scoped = arc-level axis,
visible via `/arcs/<id>` rollup (already implemented in T-1956).

Model A would require ~3 hours per scoped driver for rubric design +
estimator extension + tests, with poor signal-to-noise for arc-006's
specifically arc-level drivers (estimator-fidelity is *about* the estimator,
not *of* the task). Model C adds compute-time arc-YAML reads to `_compute_bvp`
with no marginal signal benefit. Model D leaves estimator and adds manual
UI burden for a UX that's not been requested.

The minimum-cost path to closing the visible asymmetry: ship a one-liner in
the `/tasks/T-XXX` per-task BVP block explaining the separation.

**Date**: 2026-05-22T18:37:00Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-22T18:37:00Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Scoped drivers are arc-distinguishing by design (T-1925 framing —
"what distinguishes this arc from global D1-D4"). Per-task scoring on an
arc-distinguishing axis is semantically muddled: every member task of arc-006
would get the same scoped score from the estimator (no per-task signal in
arc-006's scoped drivers without per-arc rubrics). Model B preserves the
separation cleanly: D1-D4 = per-task fingerprint, scoped = arc-level axis,
visible via `/arcs/<id>` rollup (already implemented in T-1956).

Model A would require ~3 hours per scoped driver for rubric design +
estimator extension + tests, with poor signal-to-noise for arc-006's
specifically arc-level drivers (estimator-fidelity is *about* the estimator,
not *of* the task). Model C adds compute-time arc-YAML reads to `_compute_bvp`
with no marginal signal benefit. Model D leaves estimator and adds manual
UI burden for a UX that's not been requested.

The minimum-cost path to closing the visible asymmetry: ship a one-liner in
the `/tasks/T-XXX` per-task BVP block explaining the separation.

### 2026-05-22T18:37:00Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Reason:** Inception decision in progress

## Reviewer Verdict (v1.5)

- **Scan ID:** R-79bf9ca7
- **Timestamp:** 2026-06-02T15:00:44Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-22T18:37:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
