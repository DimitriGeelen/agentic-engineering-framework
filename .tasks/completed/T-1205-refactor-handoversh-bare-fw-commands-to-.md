---
id: T-1205
name: "Refactor handover.sh bare fw commands to use _emit_user_command (T-1146 GO)"
description: >
  Refactor handover.sh bare fw commands to use _emit_user_command (T-1146 GO)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/handover/handover.sh, 
      tests/lint/no-bare-fw-in-gate-scripts.bats]
related_tasks: []
created: 2026-04-13T08:24:08Z
last_update: '2026-06-11T22:23:42Z'
date_finished: 2026-04-13T08:26:01Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:42Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1205: Refactor handover.sh bare fw commands to use _emit_user_command (T-1146 GO)

## Context

handover.sh has 2 terminal-output sites with bare `fw` commands (lines 277, 779). Markdown content
sites (backtick-quoted inside handover file) are documentation and don't need refactoring.
Part of T-1146 GO (command amnesia remediation).

## Acceptance Criteria

### Agent
- [x] Terminal-output bare `fw` commands replaced with `_emit_user_command()` or `_fw_cmd()`
- [x] Handover still generates successfully

## Verification

# Invariant test passes
bats tests/lint/no-bare-fw-in-gate-scripts.bats

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

### 2026-04-13T08:24:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1205-refactor-handoversh-bare-fw-commands-to-.md
- **Context:** Initial task creation

### 2026-04-13T08:26:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c193c681
- **Timestamp:** 2026-06-02T14:55:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
