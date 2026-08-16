---
id: T-553
name: "Fix enrich.py line 586 — undefined framework_root should be project_root"
description: >
  enrich.py:586 calls compute_forward_edges with framework_root which is undefined
  in main() scope. Should be project_root (defined on line 550). One-line fix. Blocks
  all fabric edge enrichment. Origin: T-549 OpenClaw eval, confirmed by path isolation
  investigation.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-23T16:13:28Z
last_update: '2026-08-16T22:25:33Z'
date_finished: 2026-03-24T08:52:18Z
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
  - ts: '2026-08-16T22:25:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-553: Fix enrich.py line 586 — undefined framework_root should be project_root

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] enrich.py line 586 uses `project_root` (not undefined `framework_root`)
- [x] `python3 agents/fabric/lib/enrich.py --dry-run` runs without NameError — 292 edges detected across 162 cards

## Verification

grep -q 'compute_forward_edges(targets, loc_to_id, project_root)' agents/fabric/lib/enrich.py
python3 agents/fabric/lib/enrich.py --dry-run 2>&1 | grep -q "Fabric Enrichment"

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

### 2026-03-23T16:13:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-553-fix-enrichpy-line-586--undefined-framewo.md
- **Context:** Initial task creation

### 2026-03-24T08:51:16Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-24T08:52:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-196456b4
- **Timestamp:** 2026-06-02T15:03:32Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `python3 agents/fabric/lib/enrich.py --dry-run 2>&1 | grep -q "Fabric Enrichment"`
