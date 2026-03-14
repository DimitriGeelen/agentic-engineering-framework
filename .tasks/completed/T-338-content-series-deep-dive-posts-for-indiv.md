---
id: T-338
name: "Content series: deep-dive posts for individual framework concepts"
description: >
  Create a series of 7 deep-dive posts, each focused on one framework concept.
  Each post stands alone, targets a specific pain point, and links back to the repo.
  Platform-flexible: Reddit (r/ClaudeAI, r/ChatGPTCoding), LinkedIn, Dev.to.

status: work-completed
workflow_type: build
owner: human
horizon: next
tags: [launch, visibility, content]
components: []
related_tasks: [T-334, T-336, T-337, T-329]
created: 2026-03-08T08:09:33Z
last_update: 2026-03-12T12:41:19Z
date_finished: 2026-03-08T08:20:53Z
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
- [x] 7 deep-dive posts drafted in `docs/articles/deep-dives/`
- [x] Each post has title, body, platform notes, and hashtags
- [x] Each post stands alone (no required reading order)
- [x] Each post links back to GitHub repo
- [x] Each post enriched with real research context, thinking process, and decisions from task history

### Human
- [x] Posts reviewed for tone/voice
- [x] [RUBBER-STAMP] Posts published to target platforms
  **Steps:**
  1. List the 7 deep-dive posts: `ls docs/articles/deep-dives/*.md`
  2. For each post, copy the body and publish to the platform noted in its posting notes (LinkedIn, Reddit, Dev.to, etc.)
  3. Space posts 2-3 days apart for reach
  4. Track which have been published (check off in a local note)
  **Expected:** All 7 posts live on their target platforms
  **If not:** Publish remaining posts; check platform-specific formatting requirements

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

## Publication Tracker

| # | Article | Platform | Date | Link |
|---|---------|----------|------|------|
| 01 | Task Gate | LinkedIn | 2026-03-11 | [post](https://www.linkedin.com/posts/dimitrigeelen_claudecode-aiagents-devtools-activity-7437430766051115010-ACMq) |
| 04 | Three-Layer Memory | LinkedIn | 2026-03-10 | [post](https://www.linkedin.com/posts/dimitrigeelen_claudecode-aiagents-aimemory-activity-7437039389249110016-KOfU) |
| 07 | Component Fabric | LinkedIn | 2026-03-09 | [post](https://www.linkedin.com/posts/dimitrigeelen_agenticengineering-componentfabric-codetopology-activity-7436687214798876672-3k1S) |
| 02 | Tier 0 Protection | — | — | — |
| 03 | Context Budget | — | — | — |
| 05 | Healing Loop | — | — | — |
| 06 | Authority Model | — | — | — |
| 08 | Watchtower | — | — | — |
| 09 | Context Fabric | — | — | — |
| 10 | Framework Core | — | — | — |
| 11 | Git Traceability | — | — | — |
| 12 | Learnings Pipeline | — | — | — |
| 13 | Audit | — | — | — |
| 14 | Handover | — | — | — |
| 15 | Enforcement | — | — | — |

## Updates

### 2026-03-08T08:09:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-338-content-series-deep-dive-posts-for-indiv.md
- **Context:** Initial task creation

### 2026-03-08T08:20:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:13Z — status-update [task-update-agent]
- **Change:** horizon: now → next
