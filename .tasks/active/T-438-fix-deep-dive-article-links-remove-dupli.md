---
id: T-438
name: "Fix deep-dive article links, remove duplicates, standardize URLs"
description: >
  Fix deep-dive article links, remove duplicates, standardize URLs

status: started-work
workflow_type: refactor
owner: agent
horizon: now
tags: [docs, articles]
components: []
related_tasks: []
created: 2026-03-11T08:45:20Z
last_update: 2026-03-11T08:46:32Z
date_finished: null
---

# T-438: Fix deep-dive article links, remove duplicates, standardize URLs

## Context

Audit found: 11 fictional URLs, 5 duplicate articles, 2 wrong file paths, fictional commands across articles 08-20. See /tmp/fw-agent-deep-dive-links.md for full report.

Partially complete — budget gate hit mid-fix. Done so far:
- Deleted 5 duplicate articles (08, 13, 15, 16, 18)
- Fixed article 09-watchtower.md "Try it" section (real GitHub URL)

Remaining:
- Fix fictional URLs in articles 10, 11, 12, 14, 17, 19, 20 (replace with real GitHub URL + install script)
- Fix `.docs/plans/` → `docs/plans/` in article 10
- Fix `.handovers/` → `.context/handovers/` in article 19
- Fix fictional commands: `fw install`, `brew install agentic-fw`, `agentic install`
- Renumber articles to fill gaps (01-07, 09-12, 14, 17, 19-20 → 01-15)

## Acceptance Criteria

### Agent
- [x] 5 duplicate articles removed
- [ ] All fictional/placeholder URLs replaced with real GitHub URL
- [ ] Wrong file paths fixed (`.docs/plans/`, `.handovers/`)
- [ ] Fictional commands replaced with real `fw` commands
- [ ] Articles renumbered to fill gaps

## Verification

# All remaining articles have the real GitHub URL
grep -q 'DimitriGeelen/agentic-engineering-framework' docs/articles/deep-dives/10-context-fabric.md

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
