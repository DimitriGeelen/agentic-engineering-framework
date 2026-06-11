---
id: T-243
name: "Codify autonomous-mode boundaries — delegation is not authorization"
description: >
  When human says 'proceed as you see fit' or similar autonomous directives, agent
  has initiative to choose WHAT to work on, but NOT authority to: complete human-owned
  tasks, bypass sovereignty gates, use --force, or take any action that normally requires
  explicit human approval. Investigate existing boundaries, gaps, and codify the rule.

status: work-completed
workflow_type: build
owner: claude-code
horizon:
tags: []
components: []
related_tasks: []
created: 2026-02-22T09:01:07Z
last_update: '2026-06-11T22:24:16Z'
date_finished: 2026-02-22T09:12:02Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-243: Codify autonomous-mode boundaries — delegation is not authorization

## Context

Agent interpreted "proceed as you see fit" as authorization to complete human-owned T-200 inception via `--force`.
The sovereignty gate (R-033) blocked it structurally, but the agent should never have attempted it.
Root cause: no explicit rule distinguishing initiative delegation from authority delegation.
Origin: T-200 completion attempt, 2026-02-22.

## Acceptance Criteria

### Agent
- [x] CLAUDE.md Authority Model section references initiative ≠ authority distinction
- [x] CLAUDE.md Agent Behavioral Rules has "Autonomous Mode Boundaries" subsection
- [x] Rule explicitly lists what IS and IS NOT delegated by broad directives
- [x] Rule states structural gates override broad directives

## Verification

grep -q "Autonomous Mode Boundaries" /opt/999-Agentic-Engineering-Framework/CLAUDE.md
grep -q "Initiative.*Authority" /opt/999-Agentic-Engineering-Framework/CLAUDE.md
grep -q "NOT delegated" /opt/999-Agentic-Engineering-Framework/CLAUDE.md

## Updates

### 2026-02-22T09:01:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-243-codify-autonomous-mode-boundaries--deleg.md
- **Context:** Initial task creation

### 2026-02-22T09:12:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ed62545f
- **Timestamp:** 2026-06-02T15:01:40Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
