---
id: T-1156
name: "T-1141 build: Gate scripts emit_review instead of bare commands — PL-007 structural
  enforcement"
description: >
  T-1141 build: Gate scripts emit_review instead of bare commands — PL-007 structural
  enforcement

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [agents/context/check-tier0.sh, agents/task-create/update-task.sh, 
      lib/inception.sh]
related_tasks: []
created: 2026-04-12T11:50:54Z
last_update: '2026-06-11T22:23:41Z'
date_finished: 2026-04-12T11:54:03Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:41Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 1
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=1 (body:hard-coded-removed); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1156: T-1141 build: Gate scripts emit_review instead of bare commands — PL-007 structural enforcement

## Context

Build from T-1141 GO decision (consolidated with T-1146). Gate scripts output bare CLI commands (`fw inception decide`, `fw task update --force`) instead of invoking `fw task review` which shows Watchtower URL + QR code. Agents relay these verbatim, violating PL-007. See `docs/reports/T-1141-pl-007-enforcement.md`.

Sites to fix per research artifact:
1. `update-task.sh` sovereignty gate — prints "run: fw task update ... --skip-sovereignty"
2. `inception.sh` review gate — prints "run: cd PROJECT_ROOT && bin/fw task review"  
3. `check-tier0.sh` approval gate — prints "./bin/fw tier0 approve" with hardcoded URL

## Acceptance Criteria

### Agent
- [x] `update-task.sh` sovereignty gate calls `emit_review` instead of printing bare command
- [x] `check-tier0.sh` uses `_watchtower_url` for approval URL (not hardcoded port)
- [x] No gate script outputs bare `fw task update --skip-*` commands
- [x] `inception.sh` guidance text points to `fw task review` instead of bare `fw inception decide`

## Verification

# Sovereignty gate uses emit_review instead of bare commands
bash -c 'grep -q "emit_review" agents/task-create/update-task.sh'
# check-tier0.sh uses _watchtower_url not hardcoded port
bash -c 'grep -q "_watchtower_url" agents/context/check-tier0.sh'
# No inline port detection in check-tier0.sh
bash -c '! grep -q "WT_PORT:-3000" agents/context/check-tier0.sh'

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

### 2026-04-12T11:50:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1156-t-1141-build-gate-scripts-emitreview-ins.md
- **Context:** Initial task creation

### 2026-04-12T11:54:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0cd33098
- **Timestamp:** 2026-06-02T14:55:33Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
