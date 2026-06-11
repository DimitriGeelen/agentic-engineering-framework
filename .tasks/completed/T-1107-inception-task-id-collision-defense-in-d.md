---
id: T-1107
name: "Inception: task-ID collision defense-in-depth — globally unique IDs or URL
  namespacing"
description: >
  Follow-up to T-1106 (Watchtower port bleed + cross-project task-ID collision). T-1106's
  Option D (identity-endpoint check before URL emission) closes the primary bleed-through,
  but leaks remain when a URL is shared with a second client (QR code scanned later;
  bookmark hit after Watchtower restart on a different project). This inception explores
  defense-in-depth: (1) make task IDs globally unique (prefix with project slug, e.g.,
  '025/T-434' vs '999/T-434'); OR (2) namespace URL paths with project ('/proj/025/inception/T-434');
  OR (3) embed project identifier in QR payload and have Watchtower /inception/T-XXX
  reject when the path project doesn't match the served project. Evaluate backwards-compat
  cost, consumer-project migration burden, QR lifetime, and interaction with T-885
  port registry. Scope fence: NO build, NO schema lock. Deliverable: path recommendation
  with evidence from T-1106 RCA and audit of historical task-ID collisions across
  consumer projects. Related: T-1106, T-885, T-1105, T-1100.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-11T14:34:33Z
last_update: '2026-06-11T22:23:40Z'
date_finished: 2026-04-23T18:42:29Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:40Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1107: Inception: task-ID collision defense-in-depth — globally unique IDs or URL namespacing

## Problem Statement

T-1106's Option D (identity-endpoint check) closes the primary bleed-through at the **point of emission** — `fw task review` refuses to emit a URL unless the target Watchtower serves `$PROJECT_ROOT`. However, a correctly emitted URL can still be resolved against the *wrong* Watchtower later: QR scanned after restart, bookmarked link after port reassignment, or cross-device link pasted after topology change. Task IDs are not globally unique, so integer collisions across projects cause silent wrong-content rendering with HTTP 200. This inception explores whether defense-in-depth (globally unique IDs, URL namespacing, or QR project embedding) is warranted after T-1106 lands.

## Assumptions

- A1: T-1106 emission-time check closes 80%+ of collision scenarios (validated by recommendation analysis)
- A2: Residual post-emission bleed requires a specific precondition (stale URL + topology change) that is rare in practice
- A3: T-885 (per-project configurable port) further reduces the collision surface by eliminating same-port binding
- A4: All 4 mitigation options require some backward-compat cost; none is zero-impact

## Exploration Plan

1. **Wait for T-1106 deployment** — This inception should not proceed until T-1106 is decided GO and deployed to consumer projects
2. **Monitor for 1 week** — Measure residual resolution-time bleed incidents in `.context/project/concerns.yaml` and Watchtower logs
3. **If incidents detected:** Audit cross-project task-ID collisions across all consumer projects, evaluate 4 mitigation options (see research artifact)
4. **If zero incidents:** NO-GO — T-1106 emission-time check is sufficient

## Technical Constraints

- Historical git commits reference `T-XXX` format — rewriting history is not an option
- QR codes already in the wild encode plain URLs, no project identifier
- Consumer projects span 11+ installations on this host with independent Watchtower instances
- T-885 (per-project port) and T-1106 (identity endpoint) are prerequisite/interacting tasks

## Scope Fence

**IN scope:** Path recommendation with evidence from T-1106 RCA, audit of historical task-ID collisions across consumer projects, migration cost analysis, interaction with T-885.
**OUT of scope:** Any build, any schema lock, any actual ID rewrite, any route change, any URL emission change. Those are descendant build tasks if T-1107 is decided GO.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw task review T-1107`
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if (promote to started-work and begin research phase):**
- T-1106 has been decided GO and deployed
- Post-T-1106 monitoring window (1 week minimum) shows measurable residual bleed incidents (QR-after-restart, stale bookmark, cross-device leak) in `.context/project/concerns.yaml` or Watchtower logs
- At least one of the 4 mitigation options (unique IDs / URL namespace / QR project ID / combined) has an acceptable backward-compat story for existing URLs in circulation
- Human confirms the residual risk is worth the migration cost (not a rubber stamp — T-1106's emission-time check may be sufficient in practice)

**NO-GO if (close and discard):**
- T-1106's deployed fix measurably eliminates the bleed (zero resolution-time incidents in monitoring window)
- T-885 (per-project configurable port) lands and makes port collisions rare enough that defense-in-depth is unnecessary
- All 4 mitigation options require rewriting historical git commit messages (which is not an option)

**DEFER if (RECOMMENDED — see Recommendation section):**
- T-1106 has not yet been decided or deployed. This is the current state — T-1107 should not be promoted until T-1106 is landed and its effectiveness measured.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** DEFER — pending T-1106 decision.

**Rationale:** T-1107 is a follow-up inception captured during T-1106's structural upgrade pass. T-1106's Option D (Bug 2 fix + `/identity` endpoint + emitter verification) closes the primary bleed-through at the point of emission: `fw task review` will refuse to emit a URL unless the target Watchtower serves `$PROJECT_ROOT`. The residual risk T-1107 addresses is resolution-time bleed (QR scanned after restart, bookmarked link, cross-device context leak) — a real but lower-severity class. Research has not yet been performed; the task exists only as a stub (`docs/reports/T-1107-task-id-collision-defense.md`) with 4 option sketches (globally unique IDs / URL namespacing / project ID in QR payload / combined). Promoting T-1107 to started-work now would fork effort away from completing T-1106's primary fix. Correct sequence: land T-1106 first, measure residual collisions with the T-1106 identity check deployed, then decide whether T-1107 is still needed.

**Evidence:**

- **T-1106 primary fix sufficient for 80%+ of cases** — The identity-endpoint check rejects URL emission when the Watchtower at the target URL does not serve the originating project. This closes the bleed at the most common vector (same-session `fw task review` emission).
- **Residual risk enumerated in the research stub** — `docs/reports/T-1107-task-id-collision-defense.md:11-17` lists 3 post-emission leak paths: QR scanned after Watchtower restart; bookmarked link returned-to after port reassignment; link pasted cross-device between topology changes. All three share the same failure mode: a URL already in the wild is trusted unconditionally by whatever Watchtower it hits because task IDs are not globally unique.
- **4 mitigation options with varying cost/safety** — Option 1 (globally unique IDs) has very high migration burden (history rewrite impossible, incremental path dirty). Option 2 (URL namespacing) has medium burden but breaks every existing QR/bookmark. Option 3 (QR-embedded project ID) is low burden but only helps QR paths. Option 4 (combined + registry) is highest safety + highest cost. None can be chosen without the T-1106 deployment data.
- **Interacts with T-885** — T-885 (per-project configurable port) reduces the "second project binds same port" scenario. If T-885 lands first, T-1107's residual risk shrinks further.

**Proposed next action (after T-1106 decided GO):**

1. Land T-1106a/b/c/d/e build tasks
2. Deploy T-1106 fix to all consumer projects
3. Run for 1 week; measure any resolution-time bleed incidents in `.context/project/concerns.yaml`
4. Promote T-1107 to started-work only if measured incident rate > 0
5. If started, the research phase collects: cross-project task-ID collision audit, QR lifetime analysis, T-885 interaction, path recommendation

**Risk of deferring:** Low. T-1106's fix prevents emission-time bleed. Residual post-emission bleed requires a specific (stale URL + topology change) precondition that is rare in practice. Monitoring for 1 week is cheap; deciding without data is wasted work.

## Decisions

**Decision**: DEFER

**Rationale**: Recommendation: DEFER — pending T-1106 decision.

Rationale: T-1107 is a follow-up inception captured during T-1106's structural upgrade pass. T-1106's Option D (Bug 2 fix + `/identity` endpoint + emitter verification) closes the primary bleed-through at the point of emission: `fw task review` will refuse to emit a URL unless the target Watchtower serves `$PROJECT_ROOT`. The residual risk T-1107 addresses is resolution-time bleed (QR scanned after restart, bookmarked link, cross-device context leak) — a real but lower-severity class. Research has not yet been performed; the task exists only as a stub (`docs/reports/T-1107-task-id-collision-defense.md`) with 4 option sketches (globally unique IDs / URL namespacing / project ID in QR payload / combined). Promoting T-1107 to started-work now would fork effort away from completing T-1106's primary fix. Correct sequence: land T-1106 first, measure residual collisions with the T-1106 identity check deployed, then decide whether T-1107 is still needed.

Evidence:

- T-1106 primary fix sufficient for 80%+ of cases — The identity-endpoint check rejects URL emission when the Watchtower at the target URL does not serve the originating project. This closes the bleed at the most common vector (same-session `fw task review` emission).
- Residual risk enumerated in the research stub — `docs/reports/T-1107-task-id-collision-defense.md:11-17` lists 3 post-emission leak paths: QR scanned after Watchtower restart; bookmarked link returned-to after port reassignment; link pasted cross-device between topology changes. All three share the same failure mode: a URL already in the wild is trusted unconditionally by whatever Watchtower it hits because task IDs are not globally unique.
- 4 mitigation options with varying cost/safety — Option 1 (globally unique IDs) has very high migration burden (history rewrite impossible, incremental path dirty). Option 2 (URL namespacing) has medium burden but breaks every existing QR/bookmark. Option 3 (QR-embedded project ID) is low burden but only helps QR paths. Option 4 (combined + registry) is highest safety + highest cost. None can be chosen without the T-1106 deployment data.
- Interacts with T-885 — T-885 (per-project configurable port) reduces the "second project binds same port" scenario. If T-885 lands first, T-1107's residual risk shrinks further.

Proposed next action (after T-1106 decided GO):

1. Land T-1106a/b/c/d/e build tasks
2. Deploy T-1106 fix to all consumer projects
3. Run for 1 week; measure any resolution-time bleed incidents in `.context/project/concerns.yaml`
4. Promote T-1107 to started-work only if measured incident rate > 0
5. If started, the research phase collects: cross-project task-ID collision audit, QR lifetime analysis, T-885 interaction, path recommendation

Risk of deferring: Low. T-1106's fix prevents emission-time bleed. Residual post-emission bleed requires a specific (stale URL + topology change) precondition that is rare in practice. Monitoring for 1 week is cheap; deciding without data is wasted work.

**Date**: 2026-04-12T12:53:16Z
## Decision

**Decision**: DEFER

**Rationale**: Recommendation: DEFER — pending T-1106 decision.

Rationale: T-1107 is a follow-up inception captured during T-1106's structural upgrade pass. T-1106's Option D (Bug 2 fix + `/identity` endpoint + emitter verification) closes the primary bleed-through at the point of emission: `fw task review` will refuse to emit a URL unless the target Watchtower serves `$PROJECT_ROOT`. The residual risk T-1107 addresses is resolution-time bleed (QR scanned after restart, bookmarked link, cross-device context leak) — a real but lower-severity class. Research has not yet been performed; the task exists only as a stub (`docs/reports/T-1107-task-id-collision-defense.md`) with 4 option sketches (globally unique IDs / URL namespacing / project ID in QR payload / combined). Promoting T-1107 to started-work now would fork effort away from completing T-1106's primary fix. Correct sequence: land T-1106 first, measure residual collisions with the T-1106 identity check deployed, then decide whether T-1107 is still needed.

Evidence:

- T-1106 primary fix sufficient for 80%+ of cases — The identity-endpoint check rejects URL emission when the Watchtower at the target URL does not serve the originating project. This closes the bleed at the most common vector (same-session `fw task review` emission).
- Residual risk enumerated in the research stub — `docs/reports/T-1107-task-id-collision-defense.md:11-17` lists 3 post-emission leak paths: QR scanned after Watchtower restart; bookmarked link returned-to after port reassignment; link pasted cross-device between topology changes. All three share the same failure mode: a URL already in the wild is trusted unconditionally by whatever Watchtower it hits because task IDs are not globally unique.
- 4 mitigation options with varying cost/safety — Option 1 (globally unique IDs) has very high migration burden (history rewrite impossible, incremental path dirty). Option 2 (URL namespacing) has medium burden but breaks every existing QR/bookmark. Option 3 (QR-embedded project ID) is low burden but only helps QR paths. Option 4 (combined + registry) is highest safety + highest cost. None can be chosen without the T-1106 deployment data.
- Interacts with T-885 — T-885 (per-project configurable port) reduces the "second project binds same port" scenario. If T-885 lands first, T-1107's residual risk shrinks further.

Proposed next action (after T-1106 decided GO):

1. Land T-1106a/b/c/d/e build tasks
2. Deploy T-1106 fix to all consumer projects
3. Run for 1 week; measure any resolution-time bleed incidents in `.context/project/concerns.yaml`
4. Promote T-1107 to started-work only if measured incident rate > 0
5. If started, the research phase collects: cross-project task-ID collision audit, QR lifetime analysis, T-885 interaction, path recommendation

Risk of deferring: Low. T-1106's fix prevents emission-time bleed. Residual post-emission bleed requires a specific (stale URL + topology change) precondition that is rare in practice. Monitoring for 1 week is cheap; deciding without data is wasted work.

**Date**: 2026-04-12T12:53:16Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-12T09:30:47Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T12:52:37Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)

### 2026-04-12T12:53:16Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Recommendation: DEFER — pending T-1106 decision.

Rationale: T-1107 is a follow-up inception captured during T-1106's structural upgrade pass. T-1106's Option D (Bug 2 fix + `/identity` endpoint + emitter verification) closes the primary bleed-through at the point of emission: `fw task review` will refuse to emit a URL unless the target Watchtower serves `$PROJECT_ROOT`. The residual risk T-1107 addresses is resolution-time bleed (QR scanned after restart, bookmarked link, cross-device context leak) — a real but lower-severity class. Research has not yet been performed; the task exists only as a stub (`docs/reports/T-1107-task-id-collision-defense.md`) with 4 option sketches (globally unique IDs / URL namespacing / project ID in QR payload / combined). Promoting T-1107 to started-work now would fork effort away from completing T-1106's primary fix. Correct sequence: land T-1106 first, measure residual collisions with the T-1106 identity check deployed, then decide whether T-1107 is still needed.

Evidence:

- T-1106 primary fix sufficient for 80%+ of cases — The identity-endpoint check rejects URL emission when the Watchtower at the target URL does not serve the originating project. This closes the bleed at the most common vector (same-session `fw task review` emission).
- Residual risk enumerated in the research stub — `docs/reports/T-1107-task-id-collision-defense.md:11-17` lists 3 post-emission leak paths: QR scanned after Watchtower restart; bookmarked link returned-to after port reassignment; link pasted cross-device between topology changes. All three share the same failure mode: a URL already in the wild is trusted unconditionally by whatever Watchtower it hits because task IDs are not globally unique.
- 4 mitigation options with varying cost/safety — Option 1 (globally unique IDs) has very high migration burden (history rewrite impossible, incremental path dirty). Option 2 (URL namespacing) has medium burden but breaks every existing QR/bookmark. Option 3 (QR-embedded project ID) is low burden but only helps QR paths. Option 4 (combined + registry) is highest safety + highest cost. None can be chosen without the T-1106 deployment data.
- Interacts with T-885 — T-885 (per-project configurable port) reduces the "second project binds same port" scenario. If T-885 lands first, T-1107's residual risk shrinks further.

Proposed next action (after T-1106 decided GO):

1. Land T-1106a/b/c/d/e build tasks
2. Deploy T-1106 fix to all consumer projects
3. Run for 1 week; measure any resolution-time bleed incidents in `.context/project/concerns.yaml`
4. Promote T-1107 to started-work only if measured incident rate > 0
5. If started, the research phase collects: cross-project task-ID collision audit, QR lifetime analysis, T-885 interaction, path recommendation

Risk of deferring: Low. T-1106's fix prevents emission-time bleed. Residual post-emission bleed requires a specific (stale URL + topology change) precondition that is rare in practice. Monitoring for 1 week is cheap; deciding without data is wasted work.

### 2026-04-23T16:46:48Z — status-update [task-update-agent]
- **Change:** horizon: later → next

### 2026-04-23T18:41:51Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-23T18:42:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d7e6354b
- **Timestamp:** 2026-06-02T14:55:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
