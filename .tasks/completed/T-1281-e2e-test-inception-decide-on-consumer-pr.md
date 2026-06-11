---
id: T-1281
name: "E2E: Test inception decide on consumer project via Watchtower"
description: >
  E2E: Test inception decide on consumer project via Watchtower

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-17T10:16:32Z
last_update: '2026-06-11T22:23:44Z'
date_finished: 2026-04-23T19:05:30Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:44Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=4
      (body:cross-machine); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1281: E2E: Test inception decide on consumer project via Watchtower

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Pytest fixture creates a temp consumer project (`.tasks/`, `.context/`, `.framework.yaml`) with a real inception task containing Recommendation + Go/No-Go Criteria + research artifact
- [x] Test POSTs to `/inception/T-XXX/decide` via Flask test client (using PROJECT_ROOT pointing at temp consumer) for go, no-go, and defer outcomes
- [x] After each POST, test asserts: HTTP 302/200, decision recorded in task body, task auto-moves to completed/
- [x] Test covers Watchtower → fw inception decide → task body update full chain (no mocking of `run_fw_command`)
- [x] `tests/web/test_inception_decide_e2e.py` runs and all 6 cases pass

## Verification

bash -c 'out=$(python3 -m pytest tests/web/test_inception_decide_e2e.py -q 2>&1); echo "$out" | tail -8; echo "$out" | grep -qE "passed"'

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

### 2026-04-17T10:16:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1281-e2e-test-inception-decide-on-consumer-pr.md
- **Context:** Initial task creation

### 2026-04-22T11:14:06Z — status-update [task-update-agent]
- **Change:** status: started-work → captured
- **Change:** horizon: now → later
- **Reason:** placeholder ACs (G-020) — needs real scoping before build; demoted pending proper inception

### 2026-04-23T16:46:49Z — status-update [task-update-agent]
- **Change:** horizon: later → next

### 2026-04-23T18:58:51Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-23T19:05:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7a614c33
- **Timestamp:** 2026-06-02T14:56:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `consumer project`
