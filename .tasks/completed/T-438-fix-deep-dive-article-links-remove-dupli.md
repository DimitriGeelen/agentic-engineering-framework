---
id: T-438
name: "Fix deep-dive article links, remove duplicates, standardize URLs"
description: >
  Fix deep-dive article links, remove duplicates, standardize URLs

status: work-completed
workflow_type: refactor
owner: agent
horizon: now
tags: [docs, articles]
components: []
related_tasks: []
created: 2026-03-11T08:45:20Z
last_update: 2026-03-11T08:58:13Z
date_finished: 2026-03-11T08:58:13Z
---

# T-438: Fix deep-dive article links, remove duplicates, standardize URLs

## Context

Audit found: 11 fictional URLs, 5 duplicate articles, 2 wrong file paths, fictional commands across articles 08-20. See /tmp/fw-agent-deep-dive-links.md for full report.

All fixes complete:
- Deleted 5 duplicate articles (08, 13, 15, 16, 18)
- Fixed all 8 remaining articles with real GitHub URL + install script
- Fixed `.docs/plans/` → `docs/plans/` in article 10 (now 09)
- Fixed `.handovers/` → `.context/handovers/` in article 19 (now 14)
- Replaced all fictional commands with real `fw` commands
- Renumbered 01-07,09-12,14,17,19-20 → 01-15
- Updated `python3 -m web.app` → `fw serve` in Watchtower article
- All 15 articles now have consistent Try it pattern + GitHub link

## Acceptance Criteria

### Agent
- [x] 5 duplicate articles removed
- [x] All fictional/placeholder URLs replaced with real GitHub URL
- [x] Wrong file paths fixed (`.docs/plans/`, `.handovers/`)
- [x] Fictional commands replaced with real `fw` commands
- [x] Articles renumbered to fill gaps

## Verification

# All 15 articles have the real GitHub URL
grep -c 'DimitriGeelen/agentic-engineering-framework' docs/articles/deep-dives/*.md | grep -v ':0$' | wc -l | grep -q '^15$'
# No fictional URLs remain
! grep -ql 'yourorg\|aef/fabric\|watchtower/ai-governance\|agentic-engineering/framework\.git\|fw install \|agentic install' docs/articles/deep-dives/*.md

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

### 2026-03-11T08:45:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-438-fix-deep-dive-article-links-remove-dupli.md
- **Context:** Initial task creation

### 2026-03-11T08:58:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
