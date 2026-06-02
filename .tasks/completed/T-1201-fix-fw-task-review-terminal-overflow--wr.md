---
id: T-1201
name: "Fix fw task review terminal overflow — wrap URLs, compact output"
description: >
  Fix fw task review terminal overflow — wrap URLs, compact output

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/review.sh]
related_tasks: []
created: 2026-04-13T07:40:24Z
last_update: 2026-04-13T07:42:33Z
date_finished: 2026-04-13T07:42:33Z
---

# T-1201: Fix fw task review terminal overflow — wrap URLs, compact output

## Context

`fw task review` output exceeds 80 columns — long URLs and CLI commands get cut off in terminal. User reported QR code + text truncation.

## Acceptance Criteria

### Agent
- [x] No line in `fw task review` output exceeds 78 chars (65 max)
- [x] CLI command alternative with pre-filled rationale from recommendation
- [x] Research artifact URLs shortened to filename only

## Verification

# No line exceeds 78 chars in review output
cd /opt/999-Agentic-Engineering-Framework && test $(bin/fw task review T-1200 2>&1 | wc -L) -le 78

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

### 2026-04-13T07:40:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1201-fix-fw-task-review-terminal-overflow--wr.md
- **Context:** Initial task creation

### 2026-04-13T07:42:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-38f3bfff
- **Timestamp:** 2026-06-02T14:55:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
