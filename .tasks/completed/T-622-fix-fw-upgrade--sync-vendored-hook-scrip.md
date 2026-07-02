---
id: T-622
name: "Fix fw upgrade — sync vendored hook scripts to consumers"
description: >
  fw upgrade regenerates settings.json with all hooks but does not copy the backing
  scripts to consumer .agentic-framework/agents/context/. Result: hooks reference
  scripts that don't exist, blocking all tool use in consumer sessions. Discovered
  after T-618 fleet upgrade broke /opt/150-skills-manager.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [lib/upgrade.sh]
related_tasks: []
created: 2026-03-25T22:24:40Z
last_update: '2026-06-11T22:24:26Z'
date_finished: 2026-03-25T22:26:12Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:26Z'
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

# T-622: Fix fw upgrade — sync vendored hook scripts to consumers

## Context

T-618 fleet upgrade added hooks to settings.json but didn't sync the backing scripts to `.agentic-framework/agents/context/`. Missing scripts cause hook errors blocking all tool use. CRITICAL — consumers are broken right now.

## Acceptance Criteria

### Agent
- [x] `fw upgrade` syncs `agents/context/*.sh` to consumer's `.agentic-framework/agents/context/`
- [x] `fw upgrade` syncs `bin/fw` to consumer's `.agentic-framework/bin/fw`
- [x] All 7 consumers have complete hook scripts after re-running upgrade
- [x] `fw upgrade --dry-run` reports vendored script drift

## Verification

bash -n lib/upgrade.sh
grep -q 'agents/context' lib/upgrade.sh

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

### 2026-03-25T22:24:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-622-fix-fw-upgrade--sync-vendored-hook-scrip.md
- **Context:** Initial task creation

### 2026-03-25T22:26:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a467dadd
- **Timestamp:** 2026-06-02T15:03:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
