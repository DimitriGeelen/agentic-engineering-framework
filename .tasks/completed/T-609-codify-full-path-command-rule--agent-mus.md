---
id: T-609
name: "Codify full-path command rule — agent must give copy-pasteable commands with
  cd and absolute paths"
description: >
  When the agent gives humans commands to run, they must be single-line, copy-pasteable,
  with cd to PROJECT_ROOT and bin/fw not bare fw. Currently only in agent memory —
  needs to be in CLAUDE.md as a structural rule under Agent Behavioral Rules. Also
  update Human AC format to use full paths in Steps blocks. Origin: user friction
  running fw inception decide from wrong directory.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-25T15:27:09Z
last_update: '2026-08-16T22:25:35Z'
date_finished: 2026-03-25T15:34:01Z
bvp_scores_proposed:
  - ts: '2026-05-19T17:56:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 4
      D4: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 4
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:35Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 4
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-609: Codify full-path command rule — agent must give copy-pasteable commands with cd and absolute paths

## Context

User ran `fw inception decide` from `/home/dimitri-mint-dev/` — got "No framework project detected". The global `fw` resolves to a different install. Rule exists only in agent memory. Needs codifying in CLAUDE.md + inception template + Human AC format.

## Acceptance Criteria

### Agent
- [x] CLAUDE.md: New rule under "Agent Behavioral Rules" for copy-pasteable commands
- [x] CLAUDE.md: Human AC Format Requirements updated — Steps must include cd + full paths
- [x] CLAUDE.md: Multi-line commands guidance — use `&&` chaining, avoid bare newlines
- [x] Inception template updated: Human AC uses full path in `fw inception decide` example
- [x] Vendored CLAUDE.md synced (`.agentic-framework/` templates)

## Verification

# Rule exists in CLAUDE.md
grep -q "copy-pasteable" CLAUDE.md
# Inception template has full path
grep -q "cd.*&&.*bin/fw" .tasks/templates/inception.md

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

### 2026-03-25T15:27:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-609-codify-full-path-command-rule--agent-mus.md
- **Context:** Initial task creation

### 2026-03-25T15:31:10Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-25T15:34:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-88ae454f
- **Timestamp:** 2026-06-02T15:03:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
