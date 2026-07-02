---
id: T-596
name: "Fix context budget thresholds — Anthropic reduced window to 200K without notice"
description: >
  Fix context budget thresholds — Anthropic reduced window to 200K without notice

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-03-24T07:31:57Z
last_update: '2026-06-11T22:24:25Z'
date_finished: 2026-03-24T07:34:08Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:25Z'
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

# T-596: Fix context budget thresholds — Anthropic reduced window to 200K without notice

## Context

Anthropic reduced the Claude Code context window from 1M to ~200K without notice. Max observed token reading: 196,505. Our budget gate thresholds (600K/800K/900K) never fired — sessions hit the real limit and got force-compacted with no warning, destroying working context. New thresholds: 150K/170K/190K.

## Acceptance Criteria

### Agent
- [x] budget-gate.sh CONTEXT_WINDOW default is 200000
- [x] budget-gate.sh thresholds are 75%/85%/95% (150K/170K/190K)
- [x] checkpoint.sh CONTEXT_WINDOW default is 200000
- [x] checkpoint.sh thresholds are 75%/85%/95% (150K/170K/190K)
- [x] CLAUDE.md Context Budget Management section updated with new values
- [x] checkpoint.sh status reports percentages based on 200K window

## Verification

grep -q "CONTEXT_WINDOW:-200000" agents/context/budget-gate.sh
grep -q "CONTEXT_WINDOW:-200000" agents/context/checkpoint.sh
grep -q "75 / 100" agents/context/budget-gate.sh
grep -q "85 / 100" agents/context/budget-gate.sh
grep -q "95 / 100" agents/context/budget-gate.sh
grep -q "150K" CLAUDE.md

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

### 2026-03-24T07:31:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-596-fix-context-budget-thresholds--anthropic.md
- **Context:** Initial task creation

### 2026-03-24T07:34:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-53efaa59
- **Timestamp:** 2026-06-02T15:03:47Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
