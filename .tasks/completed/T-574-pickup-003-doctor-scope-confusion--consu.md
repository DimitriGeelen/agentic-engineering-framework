---
id: T-574
name: "PICKUP-003: Doctor scope confusion — consumer vs framework context"
description: >
  From 150-skills-manager via TermLink. MEDIUM. Doctor checks FRAMEWORK_ROOT for tests/unit
  and other resources that only exist in framework-as-project context. Consumer projects
  get false warnings. RCA: /opt/150-skills-manager/.context/handovers/rca-003-doctor-scope-confusion.md.
  Pickup: /opt/150-skills-manager/.context/handovers/pickup-003-doctor-scope-confusion.md.
  Learning: L-007.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-03-23T20:58:36Z
last_update: '2026-06-11T22:24:24Z'
date_finished: 2026-03-24T11:49:41Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:24Z'
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

# T-574: PICKUP-003: Doctor scope confusion — consumer vs framework context

## Context

Doctor checks `FRAMEWORK_ROOT/tests/unit` for bats tests and other framework-development resources. Consumer projects (where `FRAMEWORK_ROOT != PROJECT_ROOT`) don't have these — producing false WARN. From 150-skills-manager via TermLink.

## Acceptance Criteria

### Agent
- [x] Framework-development checks (bats tests, shellcheck) skip with SKIP on consumer projects
- [x] Checks still fire on framework-as-project context (`FRAMEWORK_ROOT == PROJECT_ROOT`)
- [x] `fw doctor` passes on this project
- [x] Vendored copy synced

## Verification

fw doctor > /tmp/fw-doctor-t574.txt 2>&1 || true; grep -q "Hook path validation" /tmp/fw-doctor-t574.txt

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

### 2026-03-23T20:58:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-574-pickup-003-doctor-scope-confusion--consu.md
- **Context:** Initial task creation

### 2026-03-24T11:48:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-24T11:49:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4cc3b518
- **Timestamp:** 2026-06-02T15:03:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
