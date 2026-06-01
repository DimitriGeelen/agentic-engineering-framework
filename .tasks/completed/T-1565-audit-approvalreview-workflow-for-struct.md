---
id: T-1565
name: "Audit approval/review workflow for structural gaps (TermLink-dispatched investigation)"
description: >
  Audit approval/review workflow for structural gaps (TermLink-dispatched investigation)

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: [C-004, agents/task-create/update-task.sh, bin/fw, web/blueprints/approvals.py, web/blueprints/inception.py, web/blueprints/review.py, web/blueprints/tasks.py, web/shared.py, web/templates/_approvals_content.html, web/templates/_review_acs.html, web/templates/review.html]
related_tasks: []
created: 2026-04-27T20:49:14Z
last_update: 2026-04-28T07:23:39Z
date_finished: 2026-04-28T07:23:39Z
---

# T-1565: Audit approval/review workflow for structural gaps (TermLink-dispatched investigation)

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

**Recommendation:** GO

**Rationale:** Audit deliverable shipped (`docs/reports/T-1565-approval-arc-gaps-audit.md` — 9 findings, 2 HIGH / 4 MEDIUM / 3 LOW with file:line evidence and fix sketches). 7/9 findings closed across two sessions; 2/9 deferred with documented justification.

**Evidence — closed (7):**
- F1 (HIGH) — T-1567: Fix dead-code regex in approvals.py inception-decide auto-exec (raw-string `\\d` was literal backslash + d, never matching)
- F2 (HIGH) — T-1568: Replace `--force` with narrow flags in Watchtower complete-task endpoints (closed silent RCA + Recommendation bypass)
- F3 (MEDIUM) — T-1569: Surface Reviewer Verdict on /approvals cards (helper + both loaders + badge; 8 unit tests)
- F4 (MEDIUM) — T-1570: Stop dropping started-work inceptions without Recommendation
- F5 (MEDIUM) — T-1571: Add DECISIONS section to `fw review-queue` (CLI/web parity)
- F6 (MEDIUM) — T-1572: Extend Recommendation gate to fire on reviewer.needs_human signals (frontmatter + reviewer verdict; 8 bats tests)
- F8 (LOW) — T-1573: Surface `.gate-bypass-log.yaml` in `fw audit` (live signal: 27 bypasses in last 7d)

**Evidence — deferred (2):**
- F7 (LOW) — Cross-project /approvals federation: explicitly out of scope per audit ("~1 day of work"). Defer to dedicated inception when consumer count or operator burden makes it material.
- F9 (LOW) — Resolved Tier-0 approvals accumulate without bound: zero signal currently (6 files total, 0 older than 30 days). Re-evaluate when count exceeds 50 or any file is older than 30 days.

**Captured learning:** L-309 — cross-component "needs human" decoupling pattern (originated in F6).

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

**Rationale**: Audit deliverable shipped (`docs/reports/T-1565-approval-arc-gaps-audit.md` — 9 findings, 2 HIGH / 4 MEDIUM / 3 LOW with file:line evidence and fix sketches). 7/9 findings closed across two sessions; 2/9 deferred with documented justification.

**Date**: 2026-04-28T07:23:38Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-28T07:23:38Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Audit deliverable shipped (`docs/reports/T-1565-approval-arc-gaps-audit.md` — 9 findings, 2 HIGH / 4 MEDIUM / 3 LOW with file:line evidence and fix sketches). 7/9 findings closed across two sessions; 2/9 deferred with documented justification.

## Reviewer Verdict (v1.4)

- **Scan ID:** R-89cc4ed7
- **Timestamp:** 2026-04-28T07:23:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-04-28T07:23:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
