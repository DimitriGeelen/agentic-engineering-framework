---
id: T-632
name: "Watchtower file viewer — clickable links to docs/reports and task files"
description: >
  Watchtower file viewer — clickable links to docs/reports and task files

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-26T22:28:28Z
last_update: 2026-03-26T22:28:28Z
date_finished: null
---

# T-632: Watchtower file viewer — clickable links to docs/reports and task files

## Context

When the agent references `docs/reports/T-625-global-framework-sync.md`, the human should be able to click a link to read it in Watchtower. Add a `/file/<path>` route that renders project markdown files.

## Acceptance Criteria

### Agent
- [x] `/file/<path>` route serves markdown files rendered as HTML
- [x] Only safe directories viewable (docs/, .tasks/, .context/handovers/, .context/episodic/)
- [x] Path traversal blocked (../../etc/passwd → 404, bin/fw → 404)
- [x] Non-existent files return 404
- [x] Verified with curl against running Watchtower on :3010

### Human
- [ ] [RUBBER-STAMP] Click a file link and verify it renders
  **Steps:**
  1. Open: http://localhost:3010/file/docs/reports/T-629-governance-self-audit.md
  **Expected:** Rendered markdown with headings, tables, code blocks
  **If not:** Check Watchtower logs for errors

## Verification

curl -sf http://localhost:3010/file/docs/reports/T-629-governance-self-audit.md -o /dev/null

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

### 2026-03-26T22:28:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-632-watchtower-file-viewer--clickable-links-.md
- **Context:** Initial task creation
