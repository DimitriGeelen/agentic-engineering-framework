---
id: T-1167
name: "Fix CLAUDE.md doc drift — add 32 missing fw subcommands to Quick Reference"
description: >
  Fix CLAUDE.md doc drift — add 32 missing fw subcommands to Quick Reference

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-12T13:51:01Z
last_update: '2026-06-11T22:23:41Z'
date_finished: 2026-04-12T13:56:11Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:41Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1167: Fix CLAUDE.md doc drift — add 32 missing fw subcommands to Quick Reference

## Context

`fw doctor` reports 32 fw subcommands missing from CLAUDE.md Quick Reference table (G-035). Related: T-1104 (doc parity inception).

## Acceptance Criteria

### Agent
- [x] Missing fw subcommands added to CLAUDE.md Quick Reference table
- [x] `fw doctor` doc drift warning reduced or eliminated

## Verification

# Doc drift count is lower than 32
bash -c 'count=$(bin/fw doctor 2>&1 | grep "Doc drift" | grep -oP "\d+" | head -1); [ -z "$count" ] || [ "$count" -lt 32 ]'

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

### 2026-04-12T13:51:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1167-fix-claudemd-doc-drift--add-32-missing-f.md
- **Context:** Initial task creation

### 2026-04-12T13:56:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0a295026
- **Timestamp:** 2026-06-02T14:55:38Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
