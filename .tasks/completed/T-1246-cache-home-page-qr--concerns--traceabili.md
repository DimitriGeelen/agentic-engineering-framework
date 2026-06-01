---
id: T-1246
name: "Cache home page QR + concerns + traceability — reduce 0.47s warm cache"
description: >
  Cache home page QR + concerns + traceability — reduce 0.47s warm cache

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-13T20:43:32Z
last_update: 2026-04-13T20:56:01Z
date_finished: 2026-04-13T20:56:01Z
---

# T-1246: Cache home page QR + concerns + traceability — reduce 0.47s warm cache

## Context

Home page profile: QR (163ms), concerns (77ms), traceability (40ms). Add 60s TTL caches.

## Acceptance Criteria

### Agent
- [x] Add TTL caches to _get_approval_qr, _get_concerns_summary, _get_traceability
- [x] Home page warm cache improved (0.47s → 0.26s)
- [x] Web tests pass (142/142)

## Verification

python3 -c "import time,urllib.request; [urllib.request.urlopen('http://localhost:3000/') for _ in range(2)]; t0=time.time(); urllib.request.urlopen('http://localhost:3000/'); t=time.time()-t0; print(f'{t:.3f}s'); exit(0 if t<0.5 else 1)"

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

### 2026-04-13T20:43:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1246-cache-home-page-qr--concerns--traceabili.md
- **Context:** Initial task creation

### 2026-04-13T20:56:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
