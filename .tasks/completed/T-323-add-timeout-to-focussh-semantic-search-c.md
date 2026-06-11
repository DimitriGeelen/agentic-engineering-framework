---
id: T-323
name: "Add timeout to focus.sh semantic search calls"
description: >
  focus.sh memory-recall.py and ask.py calls lack timeouts, causing fw work-on to
  hang when Ollama/Qdrant is slow. Add 10s timeout.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/context/lib/focus.sh]
related_tasks: []
created: 2026-03-04T23:02:41Z
last_update: '2026-06-11T22:24:18Z'
date_finished: 2026-03-04T23:04:51Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:18Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-323: Add timeout to focus.sh semantic search calls

## Context

`fw work-on` and `fw context focus` hang when Ollama/Qdrant is slow. Root cause: `memory-recall.py` and `ask.py` calls in focus.sh have no timeout.

## Acceptance Criteria

### Agent
- [x] `memory-recall.py` call wrapped with `timeout 10`
- [x] `ask.py` call wrapped with `timeout 15`
- [x] Graceful degradation — timeout exits silently (existing `|| true`)

## Verification

# Both timeout commands present in focus.sh
grep -q "timeout 10 python3" agents/context/lib/focus.sh
grep -q "timeout 15 python3" agents/context/lib/focus.sh

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

### 2026-03-04T23:02:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-323-add-timeout-to-focussh-semantic-search-c.md
- **Context:** Initial task creation

### 2026-03-04T23:04:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-73076f16
- **Timestamp:** 2026-06-02T15:02:09Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
