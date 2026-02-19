---
id: T-204
name: "Fix CTL-013 audit HTML comment parsing — skips opening/closing but not content inside comment blocks"
description: >
  Fix CTL-013 audit HTML comment parsing — skips opening/closing but not content inside comment blocks

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-19T21:52:41Z
last_update: 2026-02-19T21:55:21Z
date_finished: 2026-02-19T21:55:21Z
---

# T-204: Fix CTL-013 audit HTML comment parsing — skips opening/closing but not content inside comment blocks

## Context

CTL-013 OE test in audit.sh parses verification commands from completed tasks but doesn't track HTML comment blocks. It skips `<!--` and `-->` lines individually but runs example commands inside comment blocks (e.g., template boilerplate in `## Verification`). The P-011 gate in `update-task.sh` already handles this correctly using Python `re.sub(r'<!--.*?-->', '', text, flags=re.DOTALL)`.

## Acceptance Criteria

### Agent
- [x] CTL-013 parser in audit.sh tracks HTML comment block state (in_comment flag)
- [x] Lines inside `<!-- ... -->` blocks are skipped entirely
- [x] T-203 and T-202 no longer produce false verification warnings
- [x] Audit passes with 0 CTL-013 warnings for tasks with only template comments

## Verification

# Verify no CTL-013 false failures (grep exits 1 when pattern NOT found = success)
bash -c 'fw audit 2>&1 | grep -q "CTL-013.*failing" && exit 1 || exit 0'

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

### 2026-02-19T21:52:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-204-fix-ctl-013-audit-html-comment-parsing--.md
- **Context:** Initial task creation

### 2026-02-19T21:55:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
