---
id: T-1710
name: "Failure-mode discrimination in disposable test instances — distinguish 'scenario triggered as designed' from 'instance is broken'"
description: >
  Failure-mode discrimination in disposable test instances — distinguish 'scenario triggered as designed' from 'instance is broken'

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-04T05:35:45Z
last_update: 2026-05-06T13:32:47Z
date_finished: 2026-05-06T13:32:47Z
---

# T-1710: Failure-mode discrimination in disposable test instances — distinguish 'scenario triggered as designed' from 'instance is broken'

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

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

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-04T05:36:10Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)
- **Change:** tags: +arc:orchestrator-rethink

### 2026-05-04T10:46:24Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-05-04T16:56:14Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Recommendation: DEFER

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

### 2026-05-06T13:32:32Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: preserved at started-work (T-1589 shipping evidence)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-18a13025
- **Timestamp:** 2026-06-02T14:59:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-06T13:32:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
