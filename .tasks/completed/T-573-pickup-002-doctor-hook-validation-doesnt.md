---
id: T-573
name: "PICKUP-002: Doctor hook validation doesnt recognize vendored fw paths"
description: >
  From 150-skills-manager via TermLink. HIGH. Doctor inline Python checks script_path
  == fw but hooks use .agentic-framework/bin/fw hook name. All 5 expected hooks report
  as not found. Consumer patch validated. RCA: /opt/150-skills-manager/.context/handovers/rca-002-doctor-hook-validation.md.
  Pickup: /opt/150-skills-manager/.context/handovers/pickup-002-doctor-hook-validation.md.
  Learning: L-006.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-23T20:58:34Z
last_update: '2026-06-11T22:24:24Z'
date_finished: 2026-03-24T10:59:59Z
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

# T-573: PICKUP-002: Doctor hook validation doesnt recognize vendored fw paths

## Context

Doctor inline Python checks `script_path == 'fw'` but consumer projects use `.agentic-framework/bin/fw hook <name>`. All expected hooks report "not found" on consumer projects. From 150-skills-manager via TermLink.

## Acceptance Criteria

### Agent
- [x] Doctor hook validation recognizes paths ending in `/fw` (not just bare `fw`)
- [x] Doctor resolves relative fw paths against PROJECT_ROOT for existence check
- [x] `fw doctor` passes on this project (framework repo)
- [x] Vendored copy synced

## Verification

fw doctor > /tmp/fw-doctor-t573.txt 2>&1 || true; grep -q "Hook path validation" /tmp/fw-doctor-t573.txt

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

### 2026-03-23T20:58:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-573-pickup-002-doctor-hook-validation-doesnt.md
- **Context:** Initial task creation

### 2026-03-24T10:59:28Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-24T10:59:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-edfd2f01
- **Timestamp:** 2026-06-02T15:03:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
