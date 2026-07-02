---
id: T-535
name: "Build onboarding gate — tag-based PreToolUse enforcement + SessionStart injection"
description: >
  Build onboarding gate — tag-based PreToolUse enforcement + SessionStart injection

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [agents/context/check-active-task.sh, 
      agents/context/post-compact-resume.sh, agents/task-create/update-task.sh, 
      bin/fw]
related_tasks: []
created: 2026-03-23T09:08:56Z
last_update: '2026-06-11T22:24:24Z'
date_finished: 2026-03-23T09:19:10Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:24Z'
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
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-535: Build onboarding gate — tag-based PreToolUse enforcement + SessionStart injection

## Context

Inception T-532 → GO. Design: tag-based gate in check-active-task.sh + SessionStart injection. See docs/reports/T-532-onboarding-gate-research.md.

## Acceptance Criteria

### Agent
- [x] check-active-task.sh blocks Write/Edit on non-onboarding tasks when incomplete onboarding tasks exist
- [x] check-active-task.sh allows Write/Edit when focused task is tagged onboarding
- [x] check-active-task.sh allows Write/Edit when no onboarding tasks exist (backward compat)
- [x] Cache marker `.context/working/.onboarding-complete` skips expensive check
- [x] update-task.sh writes cache marker when last onboarding task completes
- [x] SessionStart hook surfaces onboarding directive when incomplete onboarding tasks exist
- [x] `fw onboarding skip` escape hatch writes marker + logs to bypass-log
- [x] `fw onboarding status` shows remaining onboarding tasks

### Human
- [x] [RUBBER-STAMP] Run `fw init` in a temp project and verify onboarding gate activates
  **Steps:**
  1. `mkdir /tmp/test-onboarding && cd /tmp/test-onboarding && git init && fw init`
  2. Try `fw work-on "something else" --type build` and attempt to edit a file
  **Expected:** Blocked with "ONBOARDING REQUIRED" message listing remaining tasks
  **If not:** Check if seed tasks have `tags: [onboarding]` and check-active-task.sh has the gate

## Verification

# Gate blocks non-onboarding work (grep for the gate code)
grep -q 'onboarding' agents/context/check-active-task.sh
# SessionStart injection has onboarding check
grep -q 'onboarding' agents/context/post-compact-resume.sh
# Escape hatch exists
grep -q 'onboarding' bin/fw
# Seed tasks have onboarding tag
grep -q 'onboarding' lib/seeds/tasks/existing-project/T-001-*.md
grep -q 'onboarding' lib/seeds/tasks/greenfield/T-001-*.md

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

### 2026-03-23T09:08:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-535-build-onboarding-gate--tag-based-pretool.md
- **Context:** Initial task creation

### 2026-03-23T09:19:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a62aac4d
- **Timestamp:** 2026-06-02T15:03:26Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
