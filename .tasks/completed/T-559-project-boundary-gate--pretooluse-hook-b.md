---
id: T-559
name: "Project boundary gate — PreToolUse hook blocking writes outside PROJECT_ROOT"
description: >
  Structural enforcement: PreToolUse hook that blocks Write and Edit tool calls targeting
  file paths outside PROJECT_ROOT. Also detect Bash commands that cd or write to paths
  outside PROJECT_ROOT. Triggered by T-549 violation where agent created 6 tasks on
  another project without authorization.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-23T16:53:09Z
last_update: '2026-08-16T22:25:34Z'
date_finished: 2026-03-24T10:57:44Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:34Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-559: Project boundary gate — PreToolUse hook blocking writes outside PROJECT_ROOT

## Context

Agent created 6 inception tasks on `/opt/openclaw-evaluation/` while working from `/opt/999-Agentic-Engineering-Framework`. No structural gate existed to prevent cross-project writes. Origin: T-549 session violation.

## Acceptance Criteria

### Agent
- [x] `check-project-boundary.sh` exists in `agents/context/` and is executable
- [x] Write/Edit to paths outside PROJECT_ROOT is blocked (except /tmp, /root/.claude)
- [x] Bash commands with `cd /outside-path && ...` write patterns are blocked
- [x] Hook registered in `.claude/settings.json` on `Write|Edit|Bash` matcher
- [x] Hook registered in `fw hook` dispatch (bin/fw hook case)
- [x] Self-test: outside path → exit 2 (verified dynamically to avoid hook self-triggering)
- [x] Self-test: inside path → exit 0 (verified)
- [x] Self-test: cd to other project → exit 2 (verified dynamically)

### Human
- [x] [RUBBER-STAMP] Restart Claude Code session and verify hook fires on cross-project write attempt
  **Steps:**
  1. Restart Claude Code in `/opt/999-Agentic-Engineering-Framework`
  2. Ask agent to write a file to `/opt/openclaw-evaluation/test.txt`
  3. Verify the hook blocks with "PROJECT BOUNDARY BLOCK" message
  **Expected:** Write is blocked, agent sees boundary error
  **If not:** Check `fw doctor` hook validation output

## Verification

test -x agents/context/check-project-boundary.sh
grep -q 'check-project-boundary' .claude/settings.json

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

### 2026-03-23T16:53:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-559-project-boundary-gate--pretooluse-hook-b.md
- **Context:** Initial task creation

### 2026-03-24T10:57:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6e021314
- **Timestamp:** 2026-06-02T15:03:34Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `cross-project`
