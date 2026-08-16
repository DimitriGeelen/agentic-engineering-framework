---
id: T-039
name: Add observation inbox (fw note)
description: >
  Lightweight capture for bugs, improvements, requirements, and design debt noticed
  during work. Fills the gap between too-heavy task creation and losing observations.
status: work-completed
workflow_type: build
owner: claude-code
priority: high
tags: [observation, inbox, capture, usability]
agents:
  primary: claude-code
  supporting: []
created: 2026-02-14T09:20:55Z
last_update: '2026-08-16T22:24:17Z'
date_finished: 2026-02-14T09:20:55Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:36Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-039: Add observation inbox (fw note)

## Design Record

**Problem:** Framework had no lightweight capture for in-the-moment observations. Tasks too heavy (4 required fields), learnings wrong semantics (backward-looking), session capture too late (end of session).

**Solution:** `fw note "text"` — one required argument, auto-detected context, persistent YAML inbox.

**Key patterns borrowed:** GTD (zero-classification inbox), Zettelkasten (fleeting → permanent), IDE TODO (in-situ speed), bug bounty (structural triage SLA).

**Core insight:** Separate the moment of observation from the moment of classification.

## Updates

### 2026-02-14T09:20:55Z — build-completed [claude-code]
- **Action:** Built agents/observe/observe.sh and wired into fw CLI
- **Commands:** note (capture), list, count, triage, promote, dismiss
- **Validated:** 5-agent review unanimously recommended this approach
- **Deferred:** Audit/handover/session-capture integration (next session)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d3afbce0
- **Timestamp:** 2026-06-02T14:54:11Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
