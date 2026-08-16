---
id: T-1204
name: "Refactor hooks.sh inception gate messages to use _emit_user_command (T-1146
  GO)"
description: >
  Refactor hooks.sh inception gate messages to use _emit_user_command (T-1146 GO)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-13T08:13:04Z
last_update: '2026-08-16T22:24:25Z'
date_finished: 2026-04-13T08:16:19Z
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
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1204: Refactor hooks.sh inception gate messages to use _emit_user_command (T-1146 GO)

## Context

hooks.sh generates git hook scripts (commit-msg, post-commit, pre-push) that contain bare `fw` commands
in guidance messages. These hooks already resolve FRAMEWORK_ROOT and source config.sh, so they can also
source paths.sh to get `_emit_user_command()`. 9 bare `fw` sites across inception gate, fabric advisory,
and handover staleness messages. Part of T-1146 GO (command amnesia remediation).

## Acceptance Criteria

### Agent
- [x] hooks.sh generated hooks source paths.sh for `_emit_user_command` availability
- [x] All bare `fw` commands in hook echo statements use `_emit_user_command()` or `_fw_cmd()`
- [x] Hooks reinstall successfully (`fw git install-hooks --force`)
- [x] Invariant test extended to cover hooks.sh

## Verification

# Hooks install without error
bin/fw git install-hooks --force 2>&1 | grep -ci 'installed' > /dev/null
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

### 2026-04-13T08:13:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1204-refactor-hookssh-inception-gate-messages.md
- **Context:** Initial task creation

### 2026-04-13T08:16:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8ac94e27
- **Timestamp:** 2026-06-02T14:55:53Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw git install-hooks --force 2>&1 | grep -ci 'installed' > /dev/null`
