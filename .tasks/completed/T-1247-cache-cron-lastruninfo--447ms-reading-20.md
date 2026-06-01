---
id: T-1247
name: "Cache /cron _last_run_info — 447ms reading 200 YAML files per request"
description: >
  Cache /cron _last_run_info — 447ms reading 200 YAML files per request

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-13T20:48:28Z
last_update: 2026-04-13T20:52:57Z
date_finished: 2026-04-13T20:52:57Z
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
