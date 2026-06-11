---
id: T-1217
name: "Auto-sync .agentic-framework vendor on fw upgrade — prevent stale vendored
  files"
description: >
  Auto-sync .agentic-framework vendor on fw upgrade — prevent stale vendored files

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [lib/upgrade.sh]
related_tasks: []
created: 2026-04-13T09:50:30Z
last_update: '2026-06-11T22:23:42Z'
date_finished: 2026-04-13T09:52:26Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:42Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1217: Auto-sync .agentic-framework vendor on fw upgrade — prevent stale vendored files

## Context

T-1216 found `lib/watchtower.sh` missing from `.agentic-framework/lib/` because `fw vendor` wasn't
rerun after T-1154 added the file. Root cause: the framework repo's vendored copy (`.agentic-framework/`)
goes stale whenever new files are added to `lib/`, `agents/`, etc. No automatic sync exists.

Fix: add a self-vendor step to `lib/upgrade.sh` that syncs `.agentic-framework/` BEFORE pushing to
consumers. This ensures the vendored copy (used by pre-push audit) is always fresh.

## Acceptance Criteria

### Agent
- [x] `lib/upgrade.sh` self-syncs `.agentic-framework/` from source dirs when running in framework repo
- [x] Pre-push audit uses fresh vendored copy (no stale file errors)
- [x] Self-sync only triggers in framework repo (not consumers)

## Verification

# Verify the self-vendor code exists in upgrade.sh
grep -q 'Self-vendor' lib/upgrade.sh
# Verify watchtower.sh is still present
test -f .agentic-framework/lib/watchtower.sh

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

### 2026-04-13T09:50:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1217-auto-sync-agentic-framework-vendor-on-fw.md
- **Context:** Initial task creation

### 2026-04-13T09:52:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-055a2860
- **Timestamp:** 2026-06-02T14:55:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
