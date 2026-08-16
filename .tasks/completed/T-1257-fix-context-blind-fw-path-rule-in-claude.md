---
id: T-1257
name: "Fix context-blind fw path rule in CLAUDE.md — consumers use .agentic-framework/bin/fw"
description: >
  Fix context-blind fw path rule in CLAUDE.md — consumers use .agentic-framework/bin/fw

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
arc_id: project-shape-resilience
created: 2026-04-14T22:00:28Z
last_update: '2026-08-16T22:24:27Z'
date_finished: 2026-04-16T04:41:10Z
bvp_scores_proposed:
  - ts: '2026-05-19T17:56:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 4
      D4: 2
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:43Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 4
      D4: 4
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=4 (body:cross-machine); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 4
      D4: 4
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=4 (body:cross-machine); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1257: Fix context-blind fw path rule in CLAUDE.md — consumers use .agentic-framework/bin/fw

## Context

Cross-session report: agent on `/003-NTB-ATC-Plugin` (consumer project) told
user to run `cd /003-NTB-ATC-Plugin && bin/fw inception decide T-006 go ...`.
User got `bash: bin/fw: No such file or directory`. Consumer's fw is at
`.agentic-framework/bin/fw`, not `bin/fw`. Root cause: CLAUDE.md §
"Copy-Pasteable Commands" (T-609) says *"Use `bin/fw` not `fw`"* — generic rule
that's correct for the framework repo but wrong for consumer projects.

Related bug observed in the same transcript: agent tried to save a memory
note about the wrong path — blocked by onboarding gate ("T-001-T-005 must
finish first"). Memory writes should not be gated by task onboarding —
memory is the exact mechanism that would prevent this recurrence. Captured
as separate concern (see §Decisions).

## Acceptance Criteria

### Agent
- [x] CLAUDE.md § "Copy-Pasteable Commands" rule 3 rewritten to be context-aware: in framework repo → `bin/fw`; in consumer project → `.agentic-framework/bin/fw`; shim-resolved bare `fw` acceptable when shim is installed
- [x] CLAUDE.md § "Human AC Format Requirements" (T-325) "Full-path commands" bullet matches the new rule
- [x] Memory file `feedback_full_path_commands.md` updated with the same context-aware rule
- [x] New memory file or append clarifying how to detect context (check for `FRAMEWORK.md` → framework repo, `.agentic-framework/` → consumer)
- [x] Observation filed about memory-gate-blocks-during-onboarding (separate concern register entry)

## Verification

grep -qi "consumer project.*\.agentic-framework/bin/fw" CLAUDE.md
grep -qi "context-aware" /root/.claude/projects/-opt-999-Agentic-Engineering-Framework/memory/feedback_full_path_commands.md

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

### 2026-04-14T22:00:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1257-fix-context-blind-fw-path-rule-in-claude.md
- **Context:** Initial task creation

### 2026-04-16T04:41:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-05-02T10:07:10Z — status-update [task-update-agent]
- **Change:** tags: +arc:project-shape-resilience

## Reviewer Verdict (v1.5)

- **Scan ID:** R-397fcc48
- **Timestamp:** 2026-06-02T14:56:16Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `consumer project`
