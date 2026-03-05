---
id: T-328
name: "GitHub quick wins: topics, Discussions, v1.0.0 release, AGENTS.md"
description: >
  Execute Tier 1 visibility actions: (1) Set 20 GitHub topics on repo, (2) Rewrite About description, (3) Enable GitHub Discussions with Q&A/Ideas/Show&Tell categories, (4) Create tagged release v1.0.0, (5) Add AGENTS.md file for cross-agent compatibility. All under 1 hour total. Ref: docs/reports/T-327-visibility-strategy.md

status: started-work
workflow_type: build
owner: claude
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-05T01:12:24Z
last_update: 2026-03-05T01:13:59Z
date_finished: null
---

# T-328: GitHub quick wins: topics, Discussions, v1.0.0 release, AGENTS.md

## Context

Tier 1 visibility actions from T-327 GO decision. Ref: `docs/reports/T-327-visibility-strategy.md`

## Acceptance Criteria

### Agent
- [ ] GitHub repo topics set (20 topics via gh API)
- [ ] GitHub repo description updated
- [ ] GitHub Discussions enabled with categories
- [ ] Release v1.0.0 tagged and published
- [ ] AGENTS.md file created in repo root

### Human
- [ ] Topics appear correctly on GitHub repo page
- [ ] Discussions tab visible and usable

## Verification

test -f AGENTS.md
grep -q "agentic" AGENTS.md

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

### 2026-03-05T01:12:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-328-github-quick-wins-topics-discussions-v10.md
- **Context:** Initial task creation

### 2026-03-05T01:13:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
