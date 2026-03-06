---
id: T-336
name: "Draft r/ClaudeAI soft launch post"
description: >
  Draft Reddit r/ClaudeAI post for soft launch. "Here's what I built" framing.
  Part of T-334 launch sequence.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [launch, visibility]
components: []
related_tasks: [T-329, T-334]
created: 2026-03-06T22:47:09Z
last_update: 2026-03-06T22:47:09Z
date_finished: null
---

# T-336: Draft r/ClaudeAI soft launch post

## Context

Soft launch post for r/ClaudeAI per T-334 launch sequence. Draft at `docs/articles/reddit-claudeai-post.md`.

## Acceptance Criteria

### Agent
- [x] Post draft at `docs/articles/reddit-claudeai-post.md`
- [x] Includes title, body, and posting notes

### Human
- [ ] Post reviewed for tone/voice
- [ ] Posted to r/ClaudeAI

## Verification

test -f docs/articles/reddit-claudeai-post.md
grep -q "ClaudeAI" docs/articles/reddit-claudeai-post.md

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

### 2026-03-06T22:47:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-336-draft-rclaudeai-soft-launch-post.md
- **Context:** Initial task creation
