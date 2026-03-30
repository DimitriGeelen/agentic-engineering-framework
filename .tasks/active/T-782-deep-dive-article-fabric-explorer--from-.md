---
id: T-782
name: "Deep-dive article: Fabric Explorer — from static DAG to interactive architecture browser"
description: >
  Write a deep-dive article about the upgraded component browser (D3.js Fabric Explorer replacing Cytoscape). Covers architecture, interactions, path from evaluation to integration.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: [T-726, T-730]
created: 2026-03-30T13:32:46Z
last_update: 2026-03-30T13:35:26Z
date_finished: 2026-03-30T13:35:26Z
---

# T-782: Deep-dive article: Fabric Explorer — from static DAG to interactive architecture browser

## Context

D3.js Fabric Explorer replaced Cytoscape in T-726 (inception) and T-730 (build). Article covers the upgrade journey.

## Acceptance Criteria

### Agent
- [x] Article written at `docs/articles/deep-dives/19-fabric-explorer.md`
- [x] Covers: problem, old vs new, architecture, key interactions, integration story
- [x] Committed

### Human
- [ ] [REVIEW] Voice and tone match writing style
  **Steps:**
  1. Read the article at `docs/deep-dives/18-fabric-explorer.md`
  2. Compare to published posts at blog.dimitrigeelen.com
  3. Check for anti-patterns: emojis, exclamation marks, "we", hedging
  **Expected:** Reads like a peer-to-peer governance discussion, not a product pitch
  **If not:** Note specific paragraphs for agent revision

## Verification

test -f docs/articles/deep-dives/19-fabric-explorer.md
test -s docs/articles/deep-dives/19-fabric-explorer.md

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

### 2026-03-30T13:32:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-782-deep-dive-article-fabric-explorer--from-.md
- **Context:** Initial task creation

### 2026-03-30T13:35:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
