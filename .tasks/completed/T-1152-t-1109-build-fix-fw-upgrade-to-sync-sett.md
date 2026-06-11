---
id: T-1152
name: "T-1109 build: fix fw upgrade to sync settings.json hooks — call generate_claude_code_config
  in do_upgrade"
description: >
  T-1109 build: fix fw upgrade to sync settings.json hooks — call generate_claude_code_config
  in do_upgrade

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-12T11:13:52Z
last_update: '2026-06-11T22:23:41Z'
date_finished: 2026-04-12T11:16:17Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:41Z'
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

# T-1152: T-1109 build: fix fw upgrade to sync settings.json hooks — call generate_claude_code_config in do_upgrade

## Context

T-1109 inception (GO). `fw upgrade` syncs hook scripts but NOT `.claude/settings.json`. New hooks (block-task-tools, audit-task-tools) are present as files but not registered. Fix: call `generate_claude_code_config` during `do_upgrade`. Evidence: 11 consumers all missing 2 hooks after upgrade (L-009).

## Acceptance Criteria

### Agent
- [x] Root cause found: generate_claude_code_config template in lib/init.sh missing block-task-tools + audit-task-tools
- [x] Template updated with both hooks
- [x] do_upgrade already calls generate_claude_code_config (no change needed)

## Verification

grep -q "block-task-tools" lib/init.sh
grep -q "audit-task-tools" lib/init.sh
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-12T11:13:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1152-t-1109-build-fix-fw-upgrade-to-sync-sett.md
- **Context:** Initial task creation

### 2026-04-12T11:16:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6d1d3ac2
- **Timestamp:** 2026-06-02T14:55:31Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
