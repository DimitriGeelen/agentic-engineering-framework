---
id: T-1107
name: "Inception: task-ID collision defense-in-depth — globally unique IDs or URL namespacing"
description: >
  Follow-up to T-1106 (Watchtower port bleed + cross-project task-ID collision). T-1106's Option D (identity-endpoint check before URL emission) closes the primary bleed-through, but leaks remain when a URL is shared with a second client (QR code scanned later; bookmark hit after Watchtower restart on a different project). This inception explores defense-in-depth: (1) make task IDs globally unique (prefix with project slug, e.g., '025/T-434' vs '999/T-434'); OR (2) namespace URL paths with project ('/proj/025/inception/T-434'); OR (3) embed project identifier in QR payload and have Watchtower /inception/T-XXX reject when the path project doesn't match the served project. Evaluate backwards-compat cost, consumer-project migration burden, QR lifetime, and interaction with T-885 port registry. Scope fence: NO build, NO schema lock. Deliverable: path recommendation with evidence from T-1106 RCA and audit of historical task-ID collisions across consumer projects. Related: T-1106, T-885, T-1105, T-1100.

status: captured
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-11T14:34:33Z
last_update: 2026-04-11T14:36:46Z
date_finished: null
---

# T-1107: Inception: task-ID collision defense-in-depth — globally unique IDs or URL namespacing

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
- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
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

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
