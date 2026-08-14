# T-1981 — Inception: how should arc-scoped drivers contribute to per-task BVP?

> **Inception research artifact** (backfilled by T-2515 from the `T-1981` task body — the research was captured in-task at decision time; this extracts it verbatim to the canonical `docs/reports/` home per C-001). Source: `.tasks/completed/T-1981-inception-how-should-arc-scoped-drivers-.md`. **Decision recorded: GO.**

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
