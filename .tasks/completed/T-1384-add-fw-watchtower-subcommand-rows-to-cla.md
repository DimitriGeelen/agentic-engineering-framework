---
id: T-1384
name: "Add fw watchtower subcommand rows to CLAUDE.md Quick Reference — close fw doctor
  doc-drift (T-1380 follow-up)"
description: >
  Add fw watchtower subcommand rows to CLAUDE.md Quick Reference — close fw doctor
  doc-drift (T-1380 follow-up)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-22T20:30:28Z
last_update: '2026-06-11T22:23:47Z'
date_finished: 2026-04-22T20:31:57Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1384: Add fw watchtower subcommand rows to CLAUDE.md Quick Reference — close fw doctor doc-drift (T-1380 follow-up)

## Context

T-1380 shipped `fw watchtower {port,url,status,start,stop,restart}`. `fw doctor` flagged doc-drift: `watchtower` subcommand is missing from CLAUDE.md Quick Reference table. Close the warning with a single row covering the namespace.

## Acceptance Criteria

### Agent
- [x] CLAUDE.md Quick Reference contains a row referencing `fw watchtower port`/`url`
- [x] `fw doctor` no longer reports `watchtower` as missing from CLAUDE.md Quick Reference

## Verification

grep -qE 'fw watchtower (port|url|\{)' CLAUDE.md
! bin/fw doctor 2>&1 | grep -q 'Missing:.*watchtower'

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

### 2026-04-22T20:30:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1384-add-fw-watchtower-subcommand-rows-to-cla.md
- **Context:** Initial task creation

### 2026-04-22T20:31:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-29d3e958
- **Timestamp:** 2026-06-02T14:57:06Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `! bin/fw doctor 2>&1 | grep -q 'Missing:.*watchtower'`
