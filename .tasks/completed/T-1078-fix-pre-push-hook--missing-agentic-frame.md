---
id: T-1078
name: "Fix pre-push hook — missing .agentic-framework audit path for consumer projects"
description: >
  Fix pre-push hook — missing .agentic-framework audit path for consumer projects

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-09T21:24:47Z
last_update: '2026-08-16T22:24:22Z'
date_finished: 2026-04-09T21:30:54Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:39Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 1
      D3: 0
      D4: 4
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=1 (body:log-or-error-line); D3=0 
      (no-signal); D4=4 (body:cross-machine); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:22Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 1
      D3: 0
      D4: 4
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=1 (body:log-or-error-line); D3=0 
      (no-signal); D4=4 (body:cross-machine); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1078: Fix pre-push hook — missing .agentic-framework audit path for consumer projects

## Context

Pre-push hook template in `agents/git/lib/hooks.sh` checks `framework_path` (removed T-498) and `agents/audit/audit.sh` (framework repo only), but never `.agentic-framework/agents/audit/audit.sh` — the actual location in consumer projects. Discovered in 025-WokrshopDesigner where push was blocked with "ERROR: Audit script not found".

## Acceptance Criteria

### Agent
- [x] Pre-push hook template checks `.agentic-framework/agents/audit/audit.sh` path
- [x] Error message lists all 3 checked paths
- [x] Existing pre-push tests pass (no dedicated pre-push tests exist; hook template is embedded)
- [x] Consumer project hook reinstall works via `fw upgrade` (upgrade.sh:308 calls install-hooks)

## Verification

grep -q '.agentic-framework/agents/audit/audit.sh' agents/git/lib/hooks.sh
grep -q '.agentic-framework' agents/git/lib/hooks.sh

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

### 2026-04-09T21:24:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1078-fix-pre-push-hook--missing-agentic-frame.md
- **Context:** Initial task creation

### 2026-04-09T21:30:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1a230ee0
- **Timestamp:** 2026-06-02T14:55:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `Consumer project`
