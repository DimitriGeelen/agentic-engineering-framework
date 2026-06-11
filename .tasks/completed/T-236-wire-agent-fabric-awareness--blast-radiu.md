---
id: T-236
name: "Wire agent fabric awareness — blast-radius in git hooks, auto-capture learnings
  on completion"
description: >
  Wire Component Fabric and Context Fabric into agent workflows. Priority 1: Add blast-radius
  check to git commit flow (warn when modifying files with many dependents). Priority
  2: Auto-extract decisions/patterns from task file on work-completed. Priority 3:
  Update CLAUDE.md Working with Tasks section to include fabric/context checks. Research:
  docs/reports/T-235-agent-fabric-awareness-vector-db.md, /tmp/fw-agent-fabric-awareness.md

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/git/lib/hooks.sh, agents/task-create/update-task.sh]
related_tasks: []
created: 2026-02-21T21:48:24Z
last_update: '2026-06-11T22:24:16Z'
date_finished: 2026-02-21T22:10:34Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=1 (body/components:context-fabric-incidental); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-236: Wire agent fabric awareness — blast-radius in git hooks, auto-capture learnings on completion

## Context

Research in T-235 found agent fabric awareness is 5/10 — Component Fabric 20% integrated, Context Fabric 60%. This task wires both into core workflows. See `docs/reports/T-235-agent-fabric-awareness-vector-db.md`.

## Acceptance Criteria

### Agent
- [x] Post-commit hook shows blast-radius summary when registered components are modified
- [x] `update-task.sh` work-completed flow auto-extracts decisions from task Decisions section
- [x] CLAUDE.md "When completing" section includes fabric/context check guidance
- [x] Existing hooks/scripts still pass (`fw doctor`)

## Verification

# Post-commit hook has blast-radius check
grep -q "blast.radius\|fabric" .git/hooks/post-commit
# Update-task.sh has decision extraction
grep -q "add-decision\|Decisions" agents/task-create/update-task.sh
# CLAUDE.md has fabric guidance in completing section
grep -q "fabric" CLAUDE.md
# Framework health
fw doctor

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

### 2026-02-21T21:48:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-236-wire-agent-fabric-awareness--blast-radiu.md
- **Context:** Initial task creation

### 2026-02-21T22:06:26Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-21T22:10:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a401e285
- **Timestamp:** 2026-06-02T15:01:37Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
