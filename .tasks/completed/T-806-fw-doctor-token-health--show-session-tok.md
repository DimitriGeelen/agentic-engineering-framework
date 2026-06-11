---
id: T-806
name: "fw doctor token health — show session token usage in health check"
description: >
  Add token usage line to fw doctor output. Show current session tokens and cache
  hit rate as an informational line. Quick integration using lib/costs.sh.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [tokens, doctor, observability]
components: [bin/fw]
related_tasks: []
created: 2026-04-03T19:42:49Z
last_update: '2026-06-11T22:24:29Z'
date_finished: 2026-04-12T07:55:19Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:29Z'
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

# T-806: fw doctor token health — show session token usage in health check

## Context

Extends `fw doctor` with token health info line. Uses `fw costs current` parsing from lib/costs.sh (T-801).

## Acceptance Criteria

### Agent
- [x] `fw doctor` output includes a token usage informational line
- [x] Shows current session total tokens and turns
- [x] Graceful: if no JSONL transcript found, line is omitted

## Verification

bin/fw doctor 2>&1 | grep -qi "token"

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

### 2026-04-03T19:42:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-806-fw-doctor-token-health--show-session-tok.md
- **Context:** Initial task creation

### 2026-04-12T07:55:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f04b1405
- **Timestamp:** 2026-06-02T15:04:58Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `bin/fw doctor 2>&1 | grep -qi "token"`
