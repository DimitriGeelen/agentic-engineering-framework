---
id: T-1436
name: "Enrich 14 edgeless fabric cards with dependency edges"
description: >
  Enrich 14 edgeless fabric cards with dependency edges

status: work-completed
workflow_type: refactor
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-24T16:26:01Z
last_update: '2026-06-11T22:23:48Z'
date_finished: 2026-04-24T16:31:59Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1436: Enrich 14 edgeless fabric cards with dependency edges

## Context

The latest audit flags 14/428 fabric cards as having no edges (no `depends_on`
and no `depended_by`). `fw fabric enrich --dry-run` found zero auto-detectable
edges, meaning these need manual enrichment.

**6 bats test cards** (each tests a specific source file):
- tests/unit/audit_null_timestamp.bats → agents/audit/audit.sh
- tests/unit/task_reid.bats → tasks re-id logic
- tests/unit/hook_absolute_paths.bats → .claude/settings.json hook paths
- tests/unit/task_id_race.bats → task-create race condition fix
- tests/unit/update_task_episodic_gen.bats → update-task.sh episodic generation
- tests/unit/add_learning_id_allocator.bats → agents/context/lib/learning.sh

**8 script/lib cards** (each called by hooks, cron, CLI, or other scripts):
- agents/context/subagent-stop.sh (SubagentStop hook)
- agents/context/pl007-scanner.sh (cron)
- agents/context/session-silent-scanner.sh (T-1222 hook)
- agents/context/session-end.sh
- agents/context/stop-guard.sh (Stop hook)
- bin/hook-enable.sh (CLI)
- lib/pickup-channel-bridge.sh
- lib/prompt.sh (fw prompt command)

## Acceptance Criteria

### Agent
- [x] All 14 cards have at least one edge (either `depends_on` or `depended_by`)
- [x] Verification python script reports "all 14 enriched"
- [x] Global edgeless count drops from 14/428 to 0/428

## Verification

python3 -c "import yaml,glob,sys; t={'tests/unit/audit_null_timestamp.bats','tests/unit/task_reid.bats','tests/unit/hook_absolute_paths.bats','tests/unit/task_id_race.bats','tests/unit/update_task_episodic_gen.bats','tests/unit/add_learning_id_allocator.bats','agents/context/subagent-stop.sh','agents/context/pl007-scanner.sh','agents/context/session-silent-scanner.sh','agents/context/session-end.sh','agents/context/stop-guard.sh','bin/hook-enable.sh','lib/pickup-channel-bridge.sh','lib/prompt.sh'}; bad=[d.get('location') for f in glob.glob('.fabric/components/*.yaml') for d in [yaml.safe_load(open(f))] if d and d.get('location') in t and not (d.get('depends_on') or d.get('depended_by'))]; sys.exit(1) if bad else print('all 14 enriched')"

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

### 2026-04-24T16:26:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1436-enrich-14-edgeless-fabric-cards-with-dep.md
- **Context:** Initial task creation

### 2026-04-24T16:31:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-21db7bef
- **Timestamp:** 2026-06-02T14:57:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
