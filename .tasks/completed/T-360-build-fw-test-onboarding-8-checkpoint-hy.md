---
id: T-360
name: "Build fw test-onboarding: 8-checkpoint hybrid onboarding test"
description: >
  Build agents/onboarding-test/test-onboarding.sh with 8 checkpoints (scaffold, hooks,
  task, gate, commit, audit, self-audit, handover). Creates temp dir, runs fw init,
  exercises full onboarding flow. Structured PASS/WARN/FAIL output. Wire into bin/fw
  as fw test-onboarding. No fw dependency (standalone). Based on T-307 GO decision
  and docs/reports/T-307-hybrid-onboarding-test.md.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [testing, onboarding, cli]
components: []
related_tasks: []
created: 2026-03-08T20:41:29Z
last_update: '2026-08-16T22:25:28Z'
date_finished: 2026-03-08T20:43:29Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:28Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-360: Build fw test-onboarding: 8-checkpoint hybrid onboarding test

## Context

Build task from T-307 inception GO. Script and AGENT.md already existed from prior work. Verified all 8 checkpoints pass (27/27 PASS).

## Acceptance Criteria

### Agent
- [x] `agents/onboarding-test/test-onboarding.sh` exists and is executable
- [x] Script runs 8 checkpoints: scaffold, hooks, task, gate, commit, audit, self-audit, handover
- [x] Produces structured PASS/WARN/FAIL output with summary
- [x] `fw test-onboarding` routes correctly
- [x] `agents/onboarding-test/AGENT.md` provides interpretation criteria
- [x] All 8 checkpoints pass on clean run (27/27 PASS)

## Verification

bash -n agents/onboarding-test/test-onboarding.sh
test -x agents/onboarding-test/test-onboarding.sh
grep -q "test-onboarding" bin/fw
test -f agents/onboarding-test/AGENT.md

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

### 2026-03-08T20:41:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-360-build-fw-test-onboarding-8-checkpoint-hy.md
- **Context:** Initial task creation

### 2026-03-08T20:43:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7002f04a
- **Timestamp:** 2026-06-02T15:02:22Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
