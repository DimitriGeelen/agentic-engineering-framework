---
id: T-1218
name: "Add lint test for upgrade.sh self-vendor mechanism"
description: >
  Add lint test for upgrade.sh self-vendor mechanism

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-13T10:11:23Z
last_update: '2026-06-11T22:23:42Z'
date_finished: 2026-04-13T10:13:22Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:42Z'
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

# T-1218: Add lint test for upgrade.sh self-vendor mechanism

## Context

T-1217 added a self-vendor step to upgrade.sh that syncs `lib/*.sh` to `.agentic-framework/lib/`
before upgrading consumers. Add lint tests to guard this mechanism against removal or regression.

## Acceptance Criteria

### Agent
- [x] Lint test verifies self-vendor code exists in upgrade.sh
- [x] Lint test verifies self-vendor syncs lib/*.sh (not hardcoded list)
- [x] All lint tests pass

## Verification

bats tests/lint/single-vendor-writer.bats

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

### 2026-04-13T10:11:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1218-add-lint-test-for-upgradesh-self-vendor-.md
- **Context:** Initial task creation

### 2026-04-13T10:13:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cdf09880
- **Timestamp:** 2026-06-02T14:55:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
