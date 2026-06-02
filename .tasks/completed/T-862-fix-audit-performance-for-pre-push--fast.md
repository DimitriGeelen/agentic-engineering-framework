---
id: T-862
name: "Fix audit performance for pre-push — fast path for push hook"
description: >
  Fix audit performance for pre-push — fast path for push hook

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/git/lib/hooks.sh]
related_tasks: []
created: 2026-04-04T19:57:14Z
last_update: 2026-04-04T21:58:09Z
date_finished: 2026-04-04T21:58:09Z
---

# T-862: Fix audit performance for pre-push — fast path for push hook

## Context

Full audit takes >90s with 124 active tasks (7 loops × 15 Python calls). Pre-push hook runs full audit, blocking git push with timeout. Fix: add `--sections` filter to pre-push, running only structure + task-compliance + git-traceability (skip discovery, quality, observations).

## Acceptance Criteria

### Agent
- [x] Pre-push hook passes `--section structure` flag to audit to run fast subset
- [x] `audit.sh --section structure` completes in ~11s (vs >90s for full audit)
- [x] Full audit (no --section) still runs all checks

## Verification

# pre-push hook uses --section flag
grep -q 'section structure' .git/hooks/pre-push

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

### 2026-04-04T19:57:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-862-fix-audit-performance-for-pre-push--fast.md
- **Context:** Initial task creation

### 2026-04-04T21:58:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0fe71209
- **Timestamp:** 2026-06-02T15:05:18Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
