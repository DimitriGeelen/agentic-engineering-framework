---
id: T-338
name: "Content series: deep-dive posts for individual framework concepts"
description: >
  Create a series of 7 deep-dive posts, each focused on one framework concept.
  Each post stands alone, targets a specific pain point, and links back to the repo.
  Platform-flexible: Reddit (r/ClaudeAI, r/ChatGPTCoding), LinkedIn, Dev.to.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [launch, visibility, content]
components: []
related_tasks: [T-334, T-336, T-337, T-329]
created: 2026-03-08T08:09:33Z
last_update: 2026-03-08T08:09:33Z
date_finished: null
---

# T-338: Content series: deep-dive posts for individual framework concepts

## Context

Launch posts (T-336 Reddit, T-337 LinkedIn, T-329 Dev.to article) got little traction.
Strategy pivot: break framework into individual concept deep-dives. Each post targets
one pain point, stands alone, and provides a new entry point to discover the framework.

Series:
1. Task Gate — "Nothing gets done without a task"
2. Tier 0 Protection — preventing destructive AI actions
3. Context Budget — treating context as a finite battery
4. Three-Layer Memory — how AI agents remember across sessions
5. Healing Loop — AI learning from its own failures
6. Authority Model — initiative vs authority
7. Component Fabric — blast radius before committing

## Acceptance Criteria

### Agent
- [ ] 7 deep-dive posts drafted in `docs/articles/deep-dives/`
- [ ] Each post has title, body, platform notes, and hashtags
- [ ] Each post stands alone (no required reading order)
- [ ] Each post links back to GitHub repo

### Human
- [ ] Posts reviewed for tone/voice
- [ ] Posts published to target platforms

## Verification

test -d docs/articles/deep-dives
test "$(ls docs/articles/deep-dives/*.md 2>/dev/null | wc -l)" -ge 7

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

### 2026-03-08T08:09:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-338-content-series-deep-dive-posts-for-indiv.md
- **Context:** Initial task creation
