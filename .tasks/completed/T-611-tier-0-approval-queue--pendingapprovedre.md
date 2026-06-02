---
id: T-611
name: "Tier 0 approval queue — pending/approved/rejected cards in Watchtower"
description: >
  Add Tier 0 approval surface to Watchtower. Agent writes pending approval to .context/approvals/T-XXX.yaml when hitting a gate. Watchtower shows pending approvals as prominent cards with approve/reject buttons and feedback textarea. Watchtower API endpoint writes response to approval ledger (not file write — unfakeable). Includes approval expiry handling. Part of T-608 Watchtower approval surface.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: []
related_tasks: [T-608, T-610, T-612]
created: 2026-03-25T16:51:23Z
last_update: 2026-04-13T06:29:07Z
date_finished: 2026-03-27T18:32:01Z
---

# T-611: Tier 0 approval queue — pending/approved/rejected cards in Watchtower

## Context

Core of T-608 Watchtower approval surface (GO decision 2026-03-25). See `docs/reports/T-608-tier0-approval-surface.md`. Depends on T-610 (AC parsing).

## Acceptance Criteria

### Agent
- [x] `.context/approvals/` directory structure defined with YAML schema for pending/approved/rejected
- [x] `check-tier0.sh` writes pending approval YAML to `.context/approvals/` when blocking
- [x] Watchtower blueprint `/approvals` shows pending approval queue
- [x] Each approval card has approve/reject buttons + feedback textarea
- [x] POST `/api/approvals/decide` endpoint writes response to approval ledger
- [x] Approval expiry: pending approvals older than 1 hour marked stale
- [x] Agent file writes to `.context/approvals/` are request-only — response written by Flask endpoint

### Human
- [x] [REVIEW] Approval cards are clear and usable — approve/reject flow works intuitively
  **Steps:**
  1. Trigger a Tier 0 block (e.g., agent attempts `rm -rf /tmp/test`)
  2. Open http://localhost:3000/approvals in browser
  3. Verify pending approval card appears with command details
  4. Click approve, add optional feedback
  5. Verify response written and card moves to approved state
  **Expected:** Smooth single-click approval, feedback optional, status updates in real-time
  **If not:** Note which step broke and what the UI showed

## Verification

# Approval directory exists
test -d .context/approvals || mkdir -p .context/approvals
# Approvals blueprint registered
grep -q "approvals" web/blueprints/approvals.py

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-03-25T16:51:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-611-tier-0-approval-queue--pendingapprovedre.md
- **Context:** Initial task creation

### 2026-03-25T17:32:27Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-27T18:32:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4b381bf5
- **Timestamp:** 2026-06-02T15:03:53Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
