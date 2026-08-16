---
id: T-1246
name: "Cache home page QR + concerns + traceability — reduce 0.47s warm cache"
description: >
  Cache home page QR + concerns + traceability — reduce 0.47s warm cache

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-13T20:43:32Z
last_update: '2026-08-16T22:24:26Z'
date_finished: 2026-04-13T20:56:01Z
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
  - ts: '2026-08-16T22:24:26Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
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

## Reviewer Verdict (v1.5)

- **Scan ID:** R-19fd5e20
- **Timestamp:** 2026-06-02T14:56:11Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
