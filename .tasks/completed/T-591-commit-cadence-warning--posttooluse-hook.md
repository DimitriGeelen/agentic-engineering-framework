---
id: T-591
name: "Commit cadence warning — PostToolUse hook counting edits since last commit"
description: >
  Agents make many edits without committing, risking work loss on context exhaustion.
  Build PostToolUse commit-cadence.sh hook: counts edits via .edit-counter, warns
  at 10, strong warns at 20. Exempt paths: .context/, .tasks/, .claude/. Reset via
  post-commit git hook. Follows existing counter patterns (.tool-counter, .budget-gate-counter)
  and PostToolUse advisory patterns (checkpoint.sh, error-watchdog.sh). Source: T-024
  comparative analysis.

status: work-completed
workflow_type: build
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-03-23T21:50:55Z
last_update: '2026-06-11T22:24:25Z'
date_finished: 2026-03-24T21:25:05Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-591: Commit cadence warning — PostToolUse hook counting edits since last commit

## Context

Agents make many edits without committing, risking work loss on context exhaustion. PostToolUse hook counts edits since last commit, warns when count is high. Follows existing patterns: `.tool-counter`, `error-watchdog.sh`.

## Acceptance Criteria

### Agent
- [x] `commit-cadence.sh` PostToolUse hook exists in `agents/context/`
- [x] Hook increments `.context/working/.edit-counter` on Write/Edit tool calls
- [x] Hook skips exempt paths (`.context/`, `.tasks/`, `.claude/`)
- [x] Hook warns at 10 edits, strong warns at 20
- [x] Post-commit git hook resets `.edit-counter` to 0
- [x] Hook registered in settings.json PostToolUse on `Write|Edit` matcher

### Human
- [x] [RUBBER-STAMP] Restart Claude Code session and make 10+ edits without committing — verify warning appears
  **Steps:**
  1. Restart session to pick up new hook
  2. Make 10+ Write/Edit calls without a git commit
  3. Check for commit cadence warning in tool output
  **Expected:** Warning about uncommitted edits after ~10 edits
  **If not:** Check `.context/working/.edit-counter` value and hook registration

## Verification

test -f agents/context/commit-cadence.sh
grep -q "edit-counter" agents/context/commit-cadence.sh
grep -q "edit-counter" agents/git/lib/hooks.sh

## Decisions

## Updates

### 2026-03-23T21:50:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-591-commit-cadence-warning--posttooluse-hook.md
- **Context:** Initial task creation

### 2026-03-24T21:22:06Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-24T21:25:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-606889e7
- **Timestamp:** 2026-06-02T15:03:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
