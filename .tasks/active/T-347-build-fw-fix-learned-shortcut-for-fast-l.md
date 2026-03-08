---
id: T-347
name: "Build fw fix-learned shortcut for fast learning capture"
description: >
  Reduce friction of learning capture during fix cycles. One-liner: fw fix-learned T-XXX text.

status: started-work
workflow_type: build
owner: agent
horizon: next
tags: [cli, learning, ux]
components: []
related_tasks: []
created: 2026-03-08T12:34:06Z
last_update: 2026-03-08T14:08:39Z
date_finished: null
---

# T-347: Build fw fix-learned shortcut for fast learning capture

## Context

One-liner shortcut for capturing bugfix learnings: `fw fix-learned T-XXX "text"`. Wraps `fw context add-learning` with `--source P-001` preset. Referenced by T-346 audit mitigation message.

## Acceptance Criteria

### Agent
- [x] `fw fix-learned` shows usage when called without args
- [x] `fw fix-learned T-XXX "text"` delegates to context agent add-learning
- [x] Command listed in `fw help` output

## Verification

fw fix-learned 2>&1 | grep -q "Shortcut for capturing learnings"
fw help 2>&1 | grep -q "fix-learned"

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

### 2026-03-08T12:34:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-347-build-fw-fix-learned-shortcut-for-fast-l.md
- **Context:** Initial task creation

### 2026-03-08T14:08:39Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
