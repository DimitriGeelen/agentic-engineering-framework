---
id: T-1247
name: "Cache /cron _last_run_info — 447ms reading 200 YAML files per request"
description: >
  Cache /cron _last_run_info — 447ms reading 200 YAML files per request

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-13T20:48:28Z
last_update: '2026-06-11T22:23:43Z'
date_finished: 2026-04-13T20:52:57Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:43Z'
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

# T-1247: Cache /cron _last_run_info — 447ms reading 200 YAML files per request

## Context

`_last_run_info()` reads up to 200 YAML files per /cron request (447ms). Add count-based + TTL cache.

## Acceptance Criteria

### Agent
- [x] Add TTL cache with file-count invalidation to _last_run_info()
- [x] /cron warm cache <0.1s (achieved: 0.036s, was 0.54s)

## Verification

python3 -c "import time,urllib.request; [urllib.request.urlopen('http://localhost:3000/cron') for _ in range(2)]; t0=time.time(); urllib.request.urlopen('http://localhost:3000/cron'); t=time.time()-t0; print(f'{t:.3f}s'); exit(0 if t<0.2 else 1)"

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

### 2026-04-13T20:48:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1247-cache-cron-lastruninfo--447ms-reading-20.md
- **Context:** Initial task creation

### 2026-04-13T20:52:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-35784f88
- **Timestamp:** 2026-06-02T14:56:11Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
