---
id: T-611
name: "Tier 0 approval queue — pending/approved/rejected cards in Watchtower"
description: >
  Add Tier 0 approval surface to Watchtower. Agent writes pending approval to .context/approvals/T-XXX.yaml when hitting a gate. Watchtower shows pending approvals as prominent cards with approve/reject buttons and feedback textarea. Watchtower API endpoint writes response to approval ledger (not file write — unfakeable). Includes approval expiry handling. Part of T-608 Watchtower approval surface.

status: captured
workflow_type: build
owner: claude-code
horizon: next
tags: []
components: []
related_tasks: [T-608, T-610, T-612]
created: 2026-03-25T16:51:23Z
last_update: 2026-03-25T16:51:23Z
date_finished: null
---

# T-611: Tier 0 approval queue — pending/approved/rejected cards in Watchtower

## Context

Core of T-608 Watchtower approval surface (GO decision 2026-03-25). See `docs/reports/T-608-tier0-approval-surface.md`. Depends on T-610 (AC parsing).

## Acceptance Criteria

### Agent
- [ ] `.context/approvals/` directory structure defined with YAML schema for pending/approved/rejected
- [ ] `check-tier0.sh` writes pending approval YAML to `.context/approvals/` when blocking
- [ ] Watchtower blueprint `/approvals` shows pending approval queue
- [ ] Each approval card has approve/reject buttons + feedback textarea
- [ ] POST `/api/approvals/<id>/decide` endpoint writes response to approval ledger
- [ ] Approval expiry: pending approvals older than 1 hour marked stale
- [ ] Agent file writes to `.context/approvals/` are request-only — response written by Flask endpoint

### Human
- [ ] [REVIEW] Approval cards are clear and usable — approve/reject flow works intuitively
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
# Watchtower approvals page loads
curl -sf http://localhost:3000/approvals | grep -q "Approval"

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
