---
id: T-248
name: "Implement remaining discovery jobs D6 D9 D10 D11 D12"
description: >
  5 of 12 discoveries from T-200 not yet implemented. D10 decision-without-dialogue
  is highest value - the T-151 pattern detector. Research: docs/reports/T-200-discovery-layer-design.md.
  Related: T-200, T-239, T-240.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [C-004]
related_tasks: []
created: 2026-02-22T09:41:52Z
last_update: '2026-06-11T22:24:17Z'
date_finished: 2026-02-22T15:10:37Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=4 (body:fw-audit-or-doctor); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-248: Implement remaining discovery jobs D6 D9 D10 D11 D12

## Context

Completes the full T-200 discovery catalog (12/12). D10 (decision-without-dialogue) is the T-151 sovereignty pattern detector. D11 (gap staleness) catches forgotten gaps. D6/D9/D12 are trend detectors.

## Acceptance Criteria

### Agent
- [x] D6 (completion velocity trends) implemented — 7-day rolling average comparison
- [x] D9 (control effectiveness drift) implemented — detects always-fire controls
- [x] D10 (decision-without-dialogue) implemented — flags human tasks without AC checks
- [x] D11 (gap register staleness) implemented — flags gaps watching >30 days
- [x] D12 (bypass log growth) implemented — tracks bypass rate over 7 days
- [x] All 12 discoveries run without errors in fw audit

## Verification

# All 5 new discoveries appear in audit output
grep -q "D6:" agents/audit/audit.sh
grep -q "D9:" agents/audit/audit.sh
grep -q "D10:" agents/audit/audit.sh
grep -q "D11:" agents/audit/audit.sh
grep -q "D12:" agents/audit/audit.sh

## Updates

### 2026-02-22T09:41:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-248-implement-remaining-discovery-jobs-d6-d9.md
- **Context:** Initial task creation

### 2026-02-22T15:07:15Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-22T15:10:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5633ddcc
- **Timestamp:** 2026-06-02T15:01:42Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
