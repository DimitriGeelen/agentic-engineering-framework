# T-1710 — Failure-mode discrimination in disposable test instances — distinguish 'scenario

> **Inception research artifact** (backfilled by T-2515 from the `T-1710` task body — the research was captured in-task at decision time; this extracts it verbatim to the canonical `docs/reports/` home per C-001). Source: `.tasks/completed/T-1710-failure-mode-discrimination-in-disposabl.md`. **Decision recorded: DEFER.**

## Go/No-Go Criteria

**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Recommendation

**Recommendation:** DEFER

**Rationale:**

Captured during T-1709 grilling as a forward concern about disposable
AEF review instances. Three reasons to defer rather than GO/NO-GO:

1. **No exploration done.** Problem Statement, Assumptions, Exploration
   Plan, Scope Fence are template placeholders. A real recommendation
   requires ≥1 spike to test whether the discrimination problem actually
   bites in practice.

2. **Urgency unproven.** T-1709 (the parent context that surfaced this
   concern) has not yet shipped. Whether the discrimination problem is a
   real pain point or a hypothetical worry can only be assessed after
   T-1709's review-instance ships and runs at least one full review
   cycle on a disposable instance.

3. **Promotion criterion is observable.** Re-surface and promote to GO if
   any of: (a) a future disposable-instance run shows the agent or
   reviewer confusing "scenario triggered as designed" with "instance is
   broken"; (b) T-1709's run history accumulates ≥2 incidents of this
   confusion; (c) failure-mode telemetry (e.g. `fw orchestrator status`
   or T-1697 outcome rows) cannot distinguish the two failure classes.
   Until any trigger fires, this is captured-but-not-actionable.

**Evidence:**

- Task body contains only template placeholders (Problem Statement,
  Assumptions, Exploration Plan, Scope Fence sections empty). No spike
  data, no human-graded examples, no test of any assumption.
- Horizon already auto-demoted from `now` to `next` at filing
  (status≠started-work invariant), confirming the agent's own implicit
  judgment that this is not actionable yet.
- Sister-arc pattern: G-064 (orchestrator substrate has zero production
  consumers) waited months for real consumer evidence before becoming
  actionable; same shape applies here — defer until consumer signal.

**Risk acknowledged:**

- **Defer-and-forget risk.** Without a re-surface trigger, this could
  rot in `captured` indefinitely. Mitigation: promotion criteria above
  are observable from `fw orchestrator status` and review-instance
  outputs, so a future audit cron or T-1715-class sweep can re-promote
  mechanically.
- **Premature DEFER risk.** If the discrimination problem actually
  fires during T-1709's first review cycle (within ~1 week), promotion
  to GO should be immediate. Tracked via T-1709's related_tasks +
  episodic memory.

**Sequencing note (added during T-1715 sweep):** filed without a
Recommendation block on 2026-05-04; retrofitted as part of the T-1715
in-flight sweep. DEFER honest-records "no exploration done" rather
than fabricating a GO/NO-GO with no evidence base.

## Decision

**Decision**: DEFER

**Rationale**: Recommendation: DEFER

Rationale:

Captured during T-1709 grilling as a forward concern about disposable
AEF review instances. Three reasons to defer rather than GO/NO-GO:

1. No exploration done. Problem Statement, Assumptions, Exploration
   Plan, Scope Fence are template placeholders. A real recommendation
   requires ≥1 spike to test whether the discrimination problem actually
   bites in practice.

2. Urgency unproven. T-1709 (the parent context that surfaced this
   concern) has not yet shipped. Whether the discrimination problem is a
   real pain point or a hypothetical worry can only be assessed after
   T-1709's review-instance ships and runs at least one full review
   cycle on a disposable instance.

3. Promotion criterion is observable. Re-surface and promote to GO if
   any of: (a) a future disposable-instance run shows the agent or
   reviewer confusing "scenario triggered as designed" with "instance is
   broken"; (b) T-1709's run history accumulates ≥2 incidents of this
   confusion; (c) failure-mode telemetry (e.g. `fw orchestrator status`
   or T-1697 outcome rows) cannot distinguish the two failure classes.
   Until any trigger fires, this is captured-but-not-actionable.

Evidence:

- Task body contains only template placeholders (Problem Statement,
  Assumptions, Exploration Plan, Scope Fence sections empty). No spike
  data, no human-graded examples, no test of any assumption.
- Horizon already auto-demoted from `now` to `next` at filing
  (status≠started-work invariant), confirming the agent's own implicit
  judgment that this is not actionable yet.
- Sister-arc pattern: G-064 (orchestrator substrate has zero production
  consumers) waited months for real consumer evidence before becoming
  actionable; same shape applies here — defer until consumer signal.

Risk acknowledged:

- Defer-and-forget risk. Without a re-surface trigger, this could
  rot in `captured` indefinitely. Mitigation: promotion criteria above
  are observable from `fw orchestrator status` and review-instance
  outputs, so a future audit cron or T-1715-class sweep can re-promote
  mechanically.
- Premature DEFER risk. If the discrimination problem actually
  fires during T-1709's first review cycle (within ~1 week), promotion
  to GO should be immediate. Tracked via T-1709's related_tasks +
  episodic memory.

Sequencing note (added during T-1715 sweep): filed without a
Recommendation block on 2026-05-04; retrofitted as part of the T-1715
in-flight sweep. DEFER honest-records "no exploration done" rather
than fabricating a GO/NO-GO with no evidence base.

**Date**: 2026-05-04T16:56:14Z

## Reviewer Verdict (v1.5)

- **Scan ID:** R-18a13025
- **Timestamp:** 2026-06-02T14:59:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-06T13:32:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
