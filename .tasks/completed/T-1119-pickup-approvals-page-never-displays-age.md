---
id: T-1119
name: "Pickup: Approvals page never displays agent recommendation or argumentation — rationale_hint only pre-fills textarea, no visible recommendation block (from 010-termlink)"
description: >
  Auto-created from pickup envelope. Source: 010-termlink, task T-939. Type: bug-report.

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [pickup, bug-report]
components: []
related_tasks: []
created: 2026-04-12T07:45:01Z
last_update: 2026-04-13T06:23:17Z
date_finished: 2026-04-12T10:55:00Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1119: Pickup: Approvals page never displays agent recommendation or argumentation — rationale_hint only pre-fills textarea, no visible recommendation block (from 010-termlink)

## Problem Statement

Watchtower approvals page shows inception tasks but hides the agent's recommendation. The `rationale_hint` only pre-fills the textarea — human can't see WHY the agent recommends GO/NO-GO. Fix: extract `## Recommendation` section and display it visibly above the decision form.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- The recommendation data exists in task files (confirmed: `## Recommendation` section)
- The fix is a template + backend change (confirmed: ~20 lines)

**NO-GO if:**
- The recommendation section format varies too much (disproved: standard format)

## Verification

grep -q "recommendation" web/blueprints/approvals.py
grep -q "recommendation" web/templates/_approvals_content.html

## Recommendation

**Recommendation:** GO

**Rationale:** The approvals page hides the agent's recommendation — the human sees a blank form and must click through to the task page to understand what's being recommended. Fix: extract `## Recommendation` from task files and display it inline on the approvals page. Already implemented.

**Evidence:**
- approvals.py: `rationale_hint` truncated to 200 chars and only pre-fills textarea
- Template: no visible recommendation block, just form inputs
- Fix applied: `recommendation` and `rec_decision` fields added to approvals data, template shows collapsible recommendation block with color-coded decision

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: The approvals page hides the agent's recommendation — the human sees a blank form and must click through to the task page to understand what's being recommended. Fix:...

**Date**: 2026-04-12T11:02:26Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: The approvals page hides the agent's recommendation — the human sees a blank form and must click through to the task page to understand what's being recommended. Fix:...

**Date**: 2026-04-12T11:02:26Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-12T10:47:57Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-12T10:55:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Fix applied

### 2026-04-12T11:02:26Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: The approvals page hides the agent's recommendation — the human sees a blank form and must click through to the task page to understand what's being recommended. Fix:...

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c4c4b454
- **Timestamp:** 2026-06-02T14:55:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
