---
id: T-318
name: "Write AGENT.md for onboarding test interpretation"
description: >
  Write agents/onboarding-test/AGENT.md with AI interpretation criteria for test-onboarding
  output. Covers: day-1 noise vs real failures, CLAUDE.md quality assessment, partial
  failure diagnosis, focus state verification. From T-307 GO decision.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-03-04T21:22:54Z
last_update: '2026-06-11T22:24:18Z'
date_finished: 2026-03-04T21:44:54Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:18Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-318: Write AGENT.md for onboarding test interpretation

## Context

From T-307 inception GO. Companion to T-317 (deterministic script). See `docs/reports/T-307-hybrid-onboarding-test.md`.

## Acceptance Criteria

### Agent
- [x] `agents/onboarding-test/AGENT.md` exists
- [x] Covers all 8 checkpoints (C1-C8) with interpretation criteria
- [x] Distinguishes day-1 noise from real failures for each checkpoint
- [x] Includes diagnostic patterns for cascading failures
- [x] Includes quality assessment criteria beyond pass/fail
- [x] Provides structured output format for agent reports

## Verification

test -f agents/onboarding-test/AGENT.md
grep -q "C1: Project Scaffold" agents/onboarding-test/AGENT.md
grep -q "C8: Handover" agents/onboarding-test/AGENT.md
grep -q "Day-1 noise" agents/onboarding-test/AGENT.md
grep -q "Cascading Failures" agents/onboarding-test/AGENT.md
grep -q "Quality Assessment" agents/onboarding-test/AGENT.md

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

### 2026-03-04T21:22:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-318-write-agentmd-for-onboarding-test-interp.md
- **Context:** Initial task creation

### 2026-03-04T21:41:19Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-04T21:44:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c4c0a009
- **Timestamp:** 2026-06-02T15:02:07Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
