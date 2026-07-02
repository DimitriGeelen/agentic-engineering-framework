---
id: T-615
name: "Fix fw upgrade hook count bug — enumerate by type not count"
description: >
  upgrade.sh expects 10 hooks but init.sh generates 13. Detection is by count only,
  not type. Fix: enumerate required hooks by name, compare against consumer settings.json,
  report missing/extra. From T-614 investigation.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [lib/init.sh, lib/upgrade.sh]
related_tasks: []
created: 2026-03-25T20:17:00Z
last_update: '2026-06-11T22:24:25Z'
date_finished: 2026-03-25T22:16:00Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 1
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=1
      (body:hard-coded-removed); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-615: Fix fw upgrade hook count bug — enumerate by type not count

## Context

upgrade.sh line 294: `expected_hooks=10` — compares count only. init.sh generates 12, framework settings.json has 13. Missing hooks invisible. Source of truth: framework's own `.claude/settings.json`.

## Acceptance Criteria

### Agent
- [x] upgrade.sh compares hooks by name (event+hook_name), not count
- [x] Missing hooks reported individually with event and name
- [x] Stale hardcoded paths still detected (G-021 backward compat)
- [x] `fw upgrade --dry-run` on a consumer with 11/13 hooks shows the 2 missing by name
- [x] `fw upgrade` on a consumer regenerates settings.json with all hooks
- [x] No hardcoded expected count in upgrade.sh

## Verification

bash -n lib/upgrade.sh
grep -q 'extract_hooks' lib/upgrade.sh
! grep -q 'expected_hooks=10' lib/upgrade.sh

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

### 2026-03-25T20:17:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-615-fix-fw-upgrade-hook-count-bug--enumerate.md
- **Context:** Initial task creation

### 2026-03-25T22:16:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-57190d0f
- **Timestamp:** 2026-06-02T15:03:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
