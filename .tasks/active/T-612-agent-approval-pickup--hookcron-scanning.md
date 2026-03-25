---
id: T-612
name: "Agent approval pickup — hook/cron scanning Watchtower approval ledger"
description: >
  Implement agent-side pickup mechanism for Watchtower approvals. Options: (A) PostToolUse hook checks .context/approvals/ periodically, (B) cron job scans every 30s and writes to inbox, (C) agent explicitly checks via fw approvals pending. Preferred: option B (cron, zero friction). Connects Tier 0 hook block to Watchtower approval response. Part of T-608 Watchtower approval surface.

status: captured
workflow_type: build
owner: claude-code
horizon: next
tags: []
components: []
related_tasks: [T-608, T-610, T-611]
created: 2026-03-25T16:51:32Z
last_update: 2026-03-25T16:51:32Z
date_finished: null
---

# T-612: Agent approval pickup — hook/cron scanning Watchtower approval ledger

## Context

Closes the loop for T-608 Watchtower approval surface. After T-611 enables human approval via web UI, this task connects the response back to the agent. Depends on T-611. See `docs/reports/T-608-tier0-approval-surface.md`.

## Acceptance Criteria

### Agent
- [ ] `check-tier0.sh` checks `.context/approvals/` for approved responses matching the pending command hash
- [ ] Approved response consumption: once read by hook, approval is marked consumed (single-use)
- [ ] `fw approvals pending` command shows outstanding approval requests
- [ ] `fw approvals status` shows recent approvals (approved/rejected/expired)
- [ ] Timeout: if no response within configured TTL (default 1hr), pending request expires

### Human
- [ ] [RUBBER-STAMP] End-to-end flow works: agent blocked → approve in Watchtower → agent retries and succeeds
  **Steps:**
  1. Trigger a Tier 0 block in Claude Code session
  2. Open http://localhost:3000/approvals and click approve
  3. Retry the blocked command in Claude Code
  **Expected:** Command executes after Watchtower approval, no terminal switching needed
  **If not:** Check `.context/approvals/` for response file and `check-tier0.sh` logs

## Verification

# fw approvals subcommand exists
bin/fw approvals --help 2>&1 | grep -q "approvals"

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

### 2026-03-25T16:51:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-612-agent-approval-pickup--hookcron-scanning.md
- **Context:** Initial task creation
