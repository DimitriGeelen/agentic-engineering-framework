---
id: T-645
name: "Landing page summary card — replace full Human AC list with counts + top 3 + /approvals link"
description: >
  Landing page summary card — replace full Human AC list with counts + top 3 + /approvals link

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-27T12:38:18Z
last_update: 2026-03-27T12:38:18Z
date_finished: null
---

# T-645: Landing page summary card — replace full Human AC list with counts + top 3 + /approvals link

## Context

T-644 build task. Replace landing page "Awaiting Your Verification" full list with a compact summary card showing unified counts (Tier 0 + GO + Human ACs) and top 3 tasks, linking to /approvals as the action hub. Also enrich /approvals Human ACs with expandable detail cards.

## Acceptance Criteria

### Agent
- [ ] Landing page shows unified "Action Required" summary with counts
- [ ] Top 3 most-AC tasks shown as preview
- [ ] "View all in Approvals" link present
- [ ] /approvals Human AC cards have expandable Steps/Expected/If-not
- [ ] Per-task "Complete Task" button on /approvals when all ACs checked
- [ ] Landing page loads without errors

### Human
- [ ] [REVIEW] Landing page summary card looks clean and useful
  **Steps:**
  1. Open http://192.168.10.107:3000/ in browser
  2. Verify "Action Required" summary replaces old full list
  3. Click "View all in Approvals" link
  4. On /approvals, expand a Human AC to see Steps/Expected
  **Expected:** Summary card is concise, /approvals has full detail
  **If not:** Note what's missing or broken

## Verification

curl -sf http://localhost:3000/ | grep -q 'View all in Approvals\|action-summary'
curl -sf http://localhost:3000/approvals | grep -q 'human-ac-card\|Steps'

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

### 2026-03-27T12:38:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-645-landing-page-summary-card--replace-full-.md
- **Context:** Initial task creation
