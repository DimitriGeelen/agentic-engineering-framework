---
id: T-500
name: "Migrate existing consumer projects to vendored model"
description: >
  Migrate Bilderkarte and Sprechloop from global-dependent to vendored model. Run
  fw vendor in each project, update settings.json hooks to .agentic-framework/bin/fw
  path, remove framework_path from .framework.yaml, verify fw doctor passes. Also
  update this framework repo's own settings.json hooks. From T-482 GO.

status: work-completed
workflow_type: build
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-03-15T14:01:29Z
last_update: '2026-06-11T22:24:23Z'
date_finished: 2026-03-15T20:56:02Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:23Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 1
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=1 
      (body:hard-coded-removed); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-500: Migrate existing consumer projects to vendored model

## Context

Migrate Bilderkarte and Sprechloop from global-dependent to vendored model. From T-482 GO.

## Acceptance Criteria

### Agent
- [x] Bilderkarte has `.agentic-framework/` with VERSION file
- [x] Sprechloop has `.agentic-framework/` with VERSION file
- [x] Both projects' hooks use `.agentic-framework/bin/fw hook` (no hardcoded paths)
- [x] Both projects' `.framework.yaml` has no `framework_path` field
- [x] Both projects' `.framework.yaml` has `upstream_repo` field

### Human
- [x] [RUBBER-STAMP] Verify `fw doctor` passes in Bilderkarte
  **Steps:**
  1. `cd /opt/3021-Bilderkarte-tool-llm && .agentic-framework/bin/fw doctor`
  **Expected:** No critical failures
  **If not:** Check hook paths in `.claude/settings.json`

## Verification

test -f /opt/3021-Bilderkarte-tool-llm/.agentic-framework/VERSION
test -f /opt/001-sprechloop/.agentic-framework/VERSION
! grep -q "^framework_path:" /opt/3021-Bilderkarte-tool-llm/.framework.yaml
! grep -q "^framework_path:" /opt/001-sprechloop/.framework.yaml
grep -q "upstream_repo" /opt/3021-Bilderkarte-tool-llm/.framework.yaml
grep -q "upstream_repo" /opt/001-sprechloop/.framework.yaml

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

### 2026-03-15T14:01:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-500-migrate-existing-consumer-projects-to-ve.md
- **Context:** Initial task creation

### 2026-03-15T20:53:56Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-15T20:56:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2ec4ffad
- **Timestamp:** 2026-06-02T15:03:13Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
