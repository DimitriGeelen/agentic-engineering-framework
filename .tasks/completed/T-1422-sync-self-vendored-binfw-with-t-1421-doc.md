---
id: T-1422
name: "Sync self-vendored bin/fw with T-1421 doctor regex fix"
description: >
  Sync self-vendored bin/fw with T-1421 doctor regex fix

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-24T11:38:55Z
last_update: '2026-08-16T22:24:32Z'
date_finished: 2026-04-24T11:40:18Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:32Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1422: Sync self-vendored bin/fw with T-1421 doctor regex fix

## Context

T-1421 landed a doctor doc-drift regex fix in `bin/fw` (35→5 missing commands, -86%). The self-vendored copy at `.agentic-framework/bin/fw` predates the fix and still runs the brittle regex. Sync it so any consumer or tooling that routes through the vendored shim picks up the fix.

## Acceptance Criteria

### Agent
- [x] `.agentic-framework/bin/fw` contains the T-1421 marker `extract the verb from any`
- [x] `.agentic-framework/bin/fw` contains the `_prose_list` secondary pass
- [x] `diff bin/fw .agentic-framework/bin/fw` is empty (full sync)
- [x] Commit references T-1422

## Verification

grep -q "T-1421: extract the verb from any" .agentic-framework/bin/fw
grep -q "_prose_list" .agentic-framework/bin/fw
diff -q bin/fw .agentic-framework/bin/fw

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

### 2026-04-24T11:38:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1422-sync-self-vendored-binfw-with-t-1421-doc.md
- **Context:** Initial task creation

### 2026-04-24T11:40:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-60b2e940
- **Timestamp:** 2026-06-02T14:57:22Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
