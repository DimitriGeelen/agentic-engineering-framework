---
id: T-576
name: "PICKUP-006: CLAUDECODE env var blocks TermLink agent spawning"
description: >
  From 150-skills-manager via TermLink. HIGH. CLAUDECODE env var inherited by TermLink-spawned
  sessions blocks nested Claude Code. Requires env -u CLAUDECODE workaround. Framework
  TermLink integration should handle this automatically (claude-fw wrapper or termlink
  spawn). Already hit during T-549 eval session. Pickup: /opt/150-skills-manager/.context/handovers/pickup-006-termlink-claudecode-nesting.md.
  Learning: L-015.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/termlink/termlink.sh]
related_tasks: []
created: 2026-03-23T20:58:40Z
last_update: '2026-06-11T22:24:24Z'
date_finished: 2026-03-24T11:53:36Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 2
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=2 
      (components:substrate-edit); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-576: PICKUP-006: CLAUDECODE env var blocks TermLink agent spawning

## Context

Fix already applied in T-586 session: `unset CLAUDECODE` in `agents/termlink/termlink.sh:243`. Learning L-015 and pattern captured. Task just needs formal closure.

## Acceptance Criteria

### Agent
- [x] `unset CLAUDECODE` present in termlink.sh worker script (line 243)
- [x] Learning captured in learnings.yaml
- [x] Pattern captured in patterns.yaml

## Verification

grep -q "unset CLAUDECODE" agents/termlink/termlink.sh

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

### 2026-03-23T20:58:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-576-pickup-006-claudecode-env-var-blocks-ter.md
- **Context:** Initial task creation

### 2026-03-24T11:53:36Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-24T11:53:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9ad49bc6
- **Timestamp:** 2026-06-02T15:03:40Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
