---
id: T-322
name: "Register 16 unregistered components in fabric"
description: >
  Fabric drift shows 16 unregistered: 3 web files, 9 context/project YAMLs, 3 lib
  scripts, 1 bin script. Register all with proper purpose and dependencies.

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-03-04T22:52:41Z
last_update: '2026-06-11T22:24:18Z'
date_finished: 2026-03-04T22:56:40Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:18Z'
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
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-322: Register 16 unregistered components in fabric

## Context

Fabric drift showed 16 unregistered: 3 web, 9 context/project YAMLs, 3 lib, 1 bin. All registered with purpose and dependencies.

## Acceptance Criteria

### Agent
- [x] All 16 components registered with fabric cards
- [x] All cards have filled purpose (no TODO)
- [x] `fw fabric drift` shows 0 unregistered

## Verification

# Zero unregistered components
fw fabric drift 2>&1 | grep -q "unregistered: 0"
# Spot-check: context-project cards exist
test -f .fabric/components/context-project-assumptions.yaml
test -f .fabric/components/context-project-gaps.yaml
# Spot-check: lib cards have purpose
grep -q "preflight" .fabric/components/lib-preflight.yaml
grep -q "First-run" .fabric/components/lib-first-run.yaml

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

### 2026-03-04T22:52:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-322-register-16-unregistered-components-in-f.md
- **Context:** Initial task creation

### 2026-03-04T22:56:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0b11a8e4
- **Timestamp:** 2026-06-02T15:02:09Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `fw fabric drift 2>&1 | grep -q "unregistered: 0"`
