---
id: T-439
name: "Standardize Try it sections in articles 01-07 with improved install instructions"
description: >
  Standardize Try it sections in articles 01-07 with improved install instructions

status: work-completed
workflow_type: refactor
owner: agent
horizon: now
tags: [docs, articles]
components: []
related_tasks: []
created: 2026-03-11T09:19:07Z
last_update: 2026-03-11T10:00:41Z
date_finished: 2026-03-11T10:00:41Z
---

# T-439: Standardize Try it sections in articles 01-07 with improved install instructions

## Context

Standardize Try it sections across all 15 deep-dive articles to match improved install script and README patterns. Continuation of T-438.

## Acceptance Criteria

### Agent
- [x] All 15 articles use `cd my-project && fw init --provider claude`
- [x] All 15 articles include `fw serve` dashboard command
- [x] No fictional URLs or placeholder commands remain
- [x] Each article has topic-relevant fw commands in Try it section

## Verification

# All articles have --provider claude
grep -rq "\-\-provider claude" docs/articles/deep-dives/
# All articles have fw serve
grep -rq "fw serve" docs/articles/deep-dives/
# No placeholder URLs
! grep -rq "yourorg\|your-project\|example\.com/repo" docs/articles/deep-dives/
# 15 articles exist
test $(ls docs/articles/deep-dives/*.md | wc -l) -eq 15

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

### 2026-03-11T09:19:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-439-standardize-try-it-sections-in-articles-.md
- **Context:** Initial task creation

### 2026-03-11T10:00:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
