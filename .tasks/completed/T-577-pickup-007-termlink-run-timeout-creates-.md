---
id: T-577
name: "PICKUP-007: TermLink run timeout creates orphaned processes"
description: >
  From 150-skills-manager via TermLink. HIGH. termlink run deregisters session on
  timeout but does not kill process. Orphaned process keeps running invisibly. No
  reattach, no timed_out state, no kill flag. Discovered when claude -p wrote output
  65min after 900s timeout. This is a TermLink upstream bug. Pickup: /opt/150-skills-manager/.context/handovers/pickup-007-termlink-timeout-orphans.md.
  Learnings: L-019b, L-019c, L-019d.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-03-23T20:58:41Z
last_update: '2026-06-11T22:24:24Z'
date_finished: 2026-03-24T18:11:39Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 1
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=1 
      (body:hand-wired-dispatch); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-577: PICKUP-007: TermLink run timeout creates orphaned processes

## Context

TermLink upstream bug: `termlink run --timeout` deregisters the session on timeout but doesn't kill the process. Orphaned processes run invisibly. Discovered in 150-skills-manager when `claude -p` wrote output 65min after 900s timeout.

The framework's `fw termlink dispatch` is NOT affected — it uses spawn + its own kill watchdog. This task adds defensive measures to the framework wrapper and documents the pitfall. The upstream fix belongs in the TermLink Rust repo.

Pickup: /opt/150-skills-manager/.context/handovers/pickup-007-termlink-timeout-orphans.md

## Acceptance Criteria

### Agent
- [x] `fw termlink cleanup` detects orphaned dispatch processes (running but no TermLink session)
- [x] `fw termlink cleanup` kills orphaned processes with SIGTERM
- [x] `fw termlink cleanup` reports orphaned process count
- [x] CLAUDE.md TermLink section warns about `termlink run` timeout orphan risk

## Verification

grep -q "orphan" agents/termlink/termlink.sh
grep -q "termlink run.*orphan\|orphan.*timeout" CLAUDE.md

## Decisions

## Updates

### 2026-03-23T20:58:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-577-pickup-007-termlink-run-timeout-creates-.md
- **Context:** Initial task creation

### 2026-03-24T18:09:41Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-24T18:11:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-97574165
- **Timestamp:** 2026-06-02T15:03:40Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
