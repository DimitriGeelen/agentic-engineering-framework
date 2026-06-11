---
id: T-554
name: "Single started-work gate — enforce one active task, inception starts as captured"
description: >
  Add max-started-tasks check (default 1) to update-task.sh and fw work-on. Block
  starting a new task when another is already started-work. --force bypasses with
  logging. Also change fw inception start to create tasks as captured instead of started-work.
  Cleanup existing 13 started-work tasks to correct status. Origin: T-549 OpenClaw
  eval — agent started 8 tasks simultaneously. Evidence: all completed tasks show
  sequential pattern, focus.yaml is single-task, 13 accumulated started-work tasks
  in current project.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [agents/task-create/update-task.sh, lib/inception.sh]
related_tasks: []
created: 2026-03-23T16:18:04Z
last_update: '2026-06-11T22:24:24Z'
date_finished: 2026-04-12T07:56:34Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:24Z'
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
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-554: Single started-work gate — enforce one active task, inception starts as captured

## Context

Agents accumulate started-work tasks across sessions without completing or pausing them (currently 20). This creates ambiguity about what's actually being worked on. Gate enforces single-task focus at the status transition layer.

## Acceptance Criteria

### Agent
- [x] `update-task.sh` warns when transitioning to started-work if other started-work tasks exist
- [x] Warning lists the other started-work task IDs (max 5 shown)
- [x] Warning is advisory (exit 0), not blocking — transition still proceeds
- [x] `fw inception start` creates tasks as captured (not started-work)
- [x] `fw work-on T-XXX` path unchanged (the warning comes from update-task.sh)
- [x] Verify warning fires when starting a second task (reclassified from Human RUBBER-STAMP per T-954)

### Human

## Verification

grep -q 'started-work.*advisory\|single.*started\|CONCURRENT' agents/task-create/update-task.sh
grep -v '\-\-start' lib/inception.sh | grep -q 'create-task.sh'
grep -q "CONCURRENT\|concurrent" agents/task-create/update-task.sh

## Decisions

### 2026-03-25 — Advisory vs blocking gate
- **Chose:** Advisory (warn, don't block)
- **Why:** 20 existing started-work tasks would make blocking unusable immediately. Advisory provides visibility without disruption. Can tighten to blocking after cleanup.
- **Rejected:** Hard block (would require cleaning up 20 tasks first), configurable limit (over-engineering for now)

## Updates

### 2026-03-23T16:18:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-554-single-started-work-gate--enforce-one-ac.md
- **Context:** Initial task creation

### 2026-04-12T07:56:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-12T07:56:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8765f990
- **Timestamp:** 2026-06-02T15:03:32Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `grep -v '\-\-start' lib/inception.sh | grep -q 'create-task.sh'`
