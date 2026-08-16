---
id: T-252
name: "Fix unresolved C-XXX/F-XXX IDs in filtered fabric graph"
description: >
  Fix unresolved C-XXX/F-XXX IDs in filtered fabric graph

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [web/blueprints/fabric.py]
related_tasks: []
created: 2026-02-22T16:13:38Z
last_update: '2026-08-16T22:25:08Z'
date_finished: 2026-02-22T16:16:53Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-252: Fix unresolved C-XXX/F-XXX IDs in filtered fabric graph

## Context

When filtering the fabric dependency graph by subsystem, cross-subsystem dependency targets showed as raw IDs (C-008, F-001) with "unknown" type instead of resolved names. Bug: `fabric_graph()` passed the filtered component list as `all_components` to `_build_graph`, so the `id_to_name` map only contained same-subsystem components.

## Acceptance Criteria

### Agent
- [x] Filtered graph resolves cross-subsystem C-XXX/F-XXX IDs to component names
- [x] Dependency target nodes show correct type and subsystem grouping

## Verification

# Audit-filtered graph has no unknown-type nodes
curl -s "http://localhost:3000/fabric/graph?subsystem=audit" | grep -q "learnings-data"
curl -s "http://localhost:3000/fabric/graph?subsystem=audit" | grep -q "checkpoint"

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

### 2026-02-22T16:13:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-252-fix-unresolved-c-xxxf-xxx-ids-in-filtere.md
- **Context:** Initial task creation

### 2026-02-22T16:16:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bef684c5
- **Timestamp:** 2026-06-02T15:01:43Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -s "http://localhost:3000/fabric/graph?subsystem=audit" | grep -q "learnings-data"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `curl -s "http://localhost:3000/fabric/graph?subsystem=audit" | grep -q "checkpoint"`
