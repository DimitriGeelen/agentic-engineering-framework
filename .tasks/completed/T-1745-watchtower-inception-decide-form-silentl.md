---
id: T-1745
name: "Watchtower inception-decide form silently fails on bold-emphasized recommendation — T-1744 GO un-recordable"
description: >
  Inception: Watchtower inception-decide form silently fails on bold-emphasized recommendation — T-1744 GO un-recordable

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-05-05T12:58:17Z
last_update: 2026-05-05T13:25:08Z
date_finished: 2026-05-05T13:25:08Z
---

# T-1745: Watchtower inception-decide form silently fails on bold-emphasized recommendation — T-1744 GO un-recordable

## Problem Statement

**For:** the human, recording inception decisions via Watchtower (the framework's primary GO/NO-GO/DEFER control surface).
**The problem:** POST to `/inception/T-1744/decide` returns HTTP 200 and the page reloads, but the decision is never persisted. No error or warning banner appears. The human submitted GO four times across 2 hours; zero attempts landed.
**Why now:** T-1744 is the orchestrator-rethink arc's blocking decision. The arc cannot proceed while the decision channel is silently broken. The bug pattern (silent no-op on the human's control surface) is also worse than visible failure — the human assumes success.

Full RCA in `docs/reports/T-1745-rca-watchtower-decision-silent-failure.md`. Three independent bugs compound to produce maximum-damage silent failure:

- **RC1** (`lib/task-audit.sh:154`): validator regex requires `[A-Za-z]` immediately after `**Recommendation:**`, rejects `**Recommendation:** **GO**` (inner emphasis on verdict).
- **RC2** (`web/blueprints/inception.py:578`): `_decision_recorded_in_task` matches `## Decision` section without stripping HTML comments — placeholder comment `<!-- ... fw inception decide T-XXX go|no-go ... -->` triggers false-positive `primary_landed=True`.
- **RC3** (`web/templates/inception_detail.html:384`): template renders `?error=` banner but not `?warning=`. RC2 routes the failure as a warning; template renders nothing.

## Assumptions

- **A1:** All three RCs are independent — fixing one does not mask the others. Validated by tracing log path: validator rejects → handler reports primary_landed=True from comment text → template silent.
- **A2:** No third-party caller depends on the current loose `_decision_recorded_in_task` semantics. Validated by `grep -rn "_decision_recorded_in_task"` showing only the one call site.
- **A3:** The bold-emphasis variant `**Recommendation:** **GO**` is not a one-off authoring mistake but a recurring pattern — emphasis on the verdict reads naturally and shipped from agent-authored Recommendations multiple times.

## Exploration Plan

This is a **diagnostic + fix-scoping inception, not exploration.** Diagnosis is complete; the build is small.

1. Reproduce — done (4 entries in `watchtower.log`).
2. Trace failure path through CLI + handler + template — done (RC1+RC2+RC3 documented).
3. Write structural mitigations — done (M1-M5 in artifact).
4. Filing build task on GO: T-1746.
5. Register concern: G-067 (Watchtower silent-failure on decision form).

No spikes, no prototypes — purely a code RCA.

## Technical Constraints

- `audit_inception_recommendation` is shared between `lib/inception.sh` (decide gate) and `lib/review.sh` (review-marker check). Loosened regex must pass both call sites.
- `_decision_recorded_in_task` is the only post-CLI authoritative check that the decision landed; tightening it must not lose true positives where `## Decision` was written without a literal `**Decision**:` line.
- Template render is via Jinja; warning banner must use existing pico CSS variables for visual consistency.

## Scope Fence

**IN:**
- Loosen regex M1 in both `lib/task-audit.sh` and `lib/inception_recommendation.sh`.
- Strip HTML comments and tighten the marker check in `_decision_recorded_in_task` (M2).
- Render `?warning=` banner in `inception_detail.html` (M3).
- Add cross-cutting integration test M4.
- File concern G-067 in `concerns.yaml`.

**OUT:**
- Full parser consolidation (M5) — separate task if framework moves to a single Python parser. Would be a larger structural change.
- Auditing every other Watchtower form for similar silent-failure (worth doing, but T-1745 stays scoped to inception-decide).
- Retroactive scan of completed tasks to find others affected — only T-1744 hit this in the wild (post-RC1 fix the C-006 audit detector will surface them).

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

**GO if (file T-1746 build with M1+M2+M3+M4):**
- All three RCs reproducible from current code (validated — see artifact).
- Fix is bounded (~50 lines across 3 files) and reversible.
- Integration test M4 demonstrably exercises all three layers.
- Concern G-067 captured for the meta-pattern.

**DEFER if:**
- Other arc-critical bugs surface that displace this in priority (none observed).
- Human prefers parser consolidation (M5) before patching — adds scope, delays unblock.

**NO-GO if:**
- Diagnosis is wrong and the fix doesn't actually unblock T-1744 GO recording (sanity-checked: T-1744 body line 105 *does* contain `**Recommendation:** **GO**`, validator does reject this on dry-run).

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

Three compounding structural bugs found via watchtower.log: (1) validator regex audit_inception_recommendation in lib/task-audit.sh:154 requires [A-Za-z] immediately after '**Recommendation:**' whitespace and rejects bold-emphasized verdicts like '**GO**' which is what T-1744 uses; (2) _decision_recorded_in_task in web/blueprints/inception.py:578 captures the '## Decision' section without stripping HTML comments, so the template placeholder comment containing literal 'go|no-go' triggers false-positive primary_landed=True; (3) web/templates/inception_detail.html only renders ?error= banner, not ?warning=, so when handler routes through warning-path due to (2), the human sees no UI feedback at all — form appears successful, browser shows no banner, decision never persisted. Combined effect: human GO recorded 4 times in log, zero times on disk. Arc-blocking — T-1744 (orchestrator-rethink) cannot promote. Fix is small, scoped, and structural. Recommend GO.

**Evidence:**

- `.context/working/watchtower.log` — four `inception decide T-1744 failed: primary_landed=True stderr='ERROR: ## Recommendation section required before decision'` entries at 12:48:09, 13:33:25, 14:02:20, 14:55:07
- `.tasks/active/T-1744-spike-d-off-ramp-pick-a-different-g-064-.md:105` — body uses `**Recommendation:** **GO**` (inner emphasis)
- `lib/task-audit.sh:154` — failing regex `\*\*Recommendation:\*\*[[:space:]]*[A-Za-z]`
- `web/blueprints/inception.py:578` — false-positive `^## Decision\b.*?` with no comment-stripping
- `web/templates/inception_detail.html:384` — only renders `?error=`, not `?warning=`
- `lib/inception_recommendation.sh:39` — sibling regex with same weakness (must also be fixed for C-006 audit detector to align)
- Full diagnostic in `docs/reports/T-1745-rca-watchtower-decision-silent-failure.md`

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

**Rationale**: Three compounding structural bugs found via watchtower.log: (1) validator regex audit_inception_recommendation in lib/task-audit.sh:154 requires [A-Za-z] immediately after '**Recommendation:**' whitespace and rejects bold-emphasized verdicts like '**GO**' which is what T-1744 uses; (2) _decision_recorded_in_task in web/blueprints/inception.py:578 captures the '## Decision' section without stripping HTML comments, so the template placeholder comment containing literal 'go|no-go' triggers false-positive primary_landed=True; (3) web/templates/inception_detail.html only renders ?error= banner, not ?warning=, so when handler routes through warning-path due to (2), the human sees no UI feedback at all — form appears successful, browser shows no banner, decision never persisted. Combined effect: human GO recorded 4 times in log, zero times on disk. Arc-blocking — T-1744 (orchestrator-rethink) cannot promote. Fix is small, scoped, and structural. Recommend GO.

**Date**: 2026-05-05T13:25:08Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-05T13:00:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-05T13:25:08Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Three compounding structural bugs found via watchtower.log: (1) validator regex audit_inception_recommendation in lib/task-audit.sh:154 requires [A-Za-z] immediately after '**Recommendation:**' whitespace and rejects bold-emphasized verdicts like '**GO**' which is what T-1744 uses; (2) _decision_recorded_in_task in web/blueprints/inception.py:578 captures the '## Decision' section without stripping HTML comments, so the template placeholder comment containing literal 'go|no-go' triggers false-positive primary_landed=True; (3) web/templates/inception_detail.html only renders ?error= banner, not ?warning=, so when handler routes through warning-path due to (2), the human sees no UI feedback at all — form appears successful, browser shows no banner, decision never persisted. Combined effect: human GO recorded 4 times in log, zero times on disk. Arc-blocking — T-1744 (orchestrator-rethink) cannot promote. Fix is small, scoped, and structural. Recommend GO.

## Reviewer Verdict (v1.4)

- **Scan ID:** R-ab8226f4
- **Timestamp:** 2026-05-05T13:25:08Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-05T13:25:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
