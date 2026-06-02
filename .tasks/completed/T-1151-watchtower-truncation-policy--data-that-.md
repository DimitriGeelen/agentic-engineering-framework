---
id: T-1151
name: "Watchtower truncation policy — data that flows into permanent records must NEVER be truncated at display layer"
description: >
  Inception: Watchtower truncation policy — data that flows into permanent records must NEVER be truncated at display layer

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: [web/blueprints/approvals.py, web/blueprints/inception.py]
related_tasks: []
created: 2026-04-12T11:08:23Z
last_update: 2026-04-13T13:20:11Z
date_finished: 2026-04-13T13:20:11Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1151: Watchtower truncation policy — data that flows into permanent records must NEVER be truncated at display layer

## Problem Statement

Watchtower truncates data at the display layer ([:200], [:197], [:500]) without distinguishing display-only fields from fields that flow into permanent records. When `rationale_hint` (pre-fills approval textarea) was truncated to 200 chars, the human clicking approve recorded a permanently truncated decision rationale in the task file. This is a class of bug: any Watchtower field that pre-fills a form that writes to disk must not be truncated. T-1091 fixed the inception detail page, but the approvals page (T-1150) had the same cap. Need a structural policy + audit of all truncation sites.

## Assumptions

- A1: There are two categories of truncation in Watchtower: display-only (safe) vs write-through (unsafe)
- A2: An invariant test can grep for `[:` patterns near form fields to catch new violations

## Exploration Plan

1. Audit all truncation sites in `web/blueprints/*.py` — grep for `[:N]`, `.split()[:N]`, explicit truncation helpers
2. Classify each as display-only (safe) vs write-through (unsafe — data flows into forms/APIs that write to task files)
3. Write findings to `docs/reports/T-1151-truncation-audit.md`
4. Propose structural enforcement (test or code pattern) if warranted

## Technical Constraints

No platform constraints — this is a code audit of Python blueprint files.

## Scope Fence

**IN scope:** All `web/blueprints/*.py` files, any `[:N]` slice or explicit truncation function.
**OUT of scope:** Jinja templates (display-only by nature), JavaScript (client-side display).

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw task review T-1151`
  2. Review the research artifact at `docs/reports/T-1151-truncation-audit.md` (62 sites audited, 1 write-through found)
  3. Record decision via the Watchtower form
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Audit reveals additional write-through truncation sites that cause data loss in governance records
- A structural enforcement mechanism (test, lint rule) is warranted to prevent regression

**NO-GO if:**
- All write-through truncation is already fixed (T-1091, T-1150) and remaining sites are display-only
- The cost of building enforcement tooling exceeds the risk of future regressions

## Verification

# Research artifact exists
test -f docs/reports/T-1151-truncation-audit.md

## Recommendation

**Recommendation:** NO-GO

**Rationale:** The audit found 62 truncation sites across 16 blueprint files. Only 1 remaining write-through exists (`discovery.py:421` — conversation title capped at 120 chars), and it's low-risk (Q&A artifact, full content preserved in other fields). The two high-risk write-throughs (rationale pre-fills in `approvals.py` and `inception.py`) were already fixed by T-1091 and T-1150 with explicit comments. Building structural enforcement tooling (grep-based test, AST analysis) would cost more than the risk it mitigates — the pattern is clear, the dangerous sites are fixed, and the codebase shows good separation between display and write paths.

**Evidence:**
- 62 truncation sites audited across 16 files
- 24 display-only, 18 error-display, 11 list-cap, 6 file-identity — all safe
- 2 write-through sites already fixed (T-1091, T-1150) with documenting comments
- 1 remaining write-through: `discovery.py:421` (`title[:120]`) — low risk, original data preserved in `history` and `final_question` fields
- No additional governance-impacting truncation found

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

**Decision**: NO-GO

**Rationale**: Recommendation: NO-GO

Rationale: The audit found 62 truncation sites across 16 blueprint files. Only 1 remaining write-through exists (`discovery.py:421` — conversation title capped at 120 chars), and it's low-risk (Q&A artifact, full content preserved in other fields). The two high-risk write-throughs (rationale pre-fills in `approvals.py` and `inception.py`) were already fixed by T-1091 and T-1150 with explicit comments. Building structural enforcement tooling (grep-based test, AST analysis) would cost more than the risk it mitigates — the pattern is clear, the dangerous sites are fixed, and the codebase shows good separation between display and write paths.

Evidence:
- 62 truncation sites audited across 16 files
- 24 display-only, 18 error-display, 11 list-cap, 6 file-identity — all safe
- 2 write-through sites already fixed (T-1091, T-1150) with documenting comments
- 1 remaining write-through: `discovery.py:421` (`title[:120]`) — low risk, original data preserved in `history` and `final_question` fields
- No additional governance-impacting truncation found

**Date**: 2026-04-13T11:07:12Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-12T11:14:41Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T14:01:13Z — status-update [task-update-agent]
- **Change:** status: started-work → captured

### 2026-04-13T11:07:12Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** Recommendation: NO-GO

Rationale: The audit found 62 truncation sites across 16 blueprint files. Only 1 remaining write-through exists (`discovery.py:421` — conversation title capped at 120 chars), and it's low-risk (Q&A artifact, full content preserved in other fields). The two high-risk write-throughs (rationale pre-fills in `approvals.py` and `inception.py`) were already fixed by T-1091 and T-1150 with explicit comments. Building structural enforcement tooling (grep-based test, AST analysis) would cost more than the risk it mitigates — the pattern is clear, the dangerous sites are fixed, and the codebase shows good separation between display and write paths.

Evidence:
- 62 truncation sites audited across 16 files
- 24 display-only, 18 error-display, 11 list-cap, 6 file-identity — all safe
- 2 write-through sites already fixed (T-1091, T-1150) with documenting comments
- 1 remaining write-through: `discovery.py:421` (`title[:120]`) — low risk, original data preserved in `history` and `final_question` fields
- No additional governance-impacting truncation found

### 2026-04-13T13:20:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Reason:** T-1226: Status fix — decision already recorded via Watchtower

### 2026-04-13T13:20:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** T-1226: NO-GO decision already recorded via Watchtower

## Reviewer Verdict (v1.5)

- **Scan ID:** R-71ae5b93
- **Timestamp:** 2026-06-02T14:55:31Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
