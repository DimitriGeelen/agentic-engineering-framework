---
id: T-1923
name: "BVP T-NEW-7b: bvp-estimator scheduled sweep + fw resume SLA fallback (split
  parent T-NEW-7)"
description: >
  Periodic sweep for stale-scored tasks; fw resume synchronous fallback with 10s hard
  cap (Q4 default); on timeout flag task `unscored: true` and let async sweep handle
  later. Resume itself never blocked by estimator.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [bvp, build, slice-7b, termlink, cron]
components: [agents/termlink/bvp-estimator/, bin/fw, .context/cron-registry.yaml]
related_tasks: [T-1915, T-1916, T-1922]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: '2026-05-19T17:56:35Z'
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T17:56:35Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1923: BVP T-NEW-7b — scheduled sweep + `fw resume` fallback

## Context

Second split-child of T-NEW-7. Depends on T-1922 (worker harness must exist with determinism proven).

**Source:** Handoff §7 T-NEW-7 (needs-split); artefact §6 row 7; §1 Q4 (10s SLA default), §7 M3 (v2-delta).

**Q4 default applied:** 10s hard cap during `fw resume`; task gets `unscored: true` if estimator times out; async sweep picks it up later.

## Acceptance Criteria

### Agent
- [ ] Periodic sweep (cron-registered) runs every N minutes — N configurable, default 15
- [ ] Sweep scores tasks whose status is started-work/captured AND `bvp_scores:` is empty AND `bvp_scores_proposed:` is older than configured staleness threshold (default 24h)
- [ ] `fw resume` synchronous path calls estimator with 10s hard cap (Q4)
- [ ] On timeout, task frontmatter gets `unscored: true` field; resume completes normally (never blocked)
- [ ] After async sweep scores an `unscored: true` task, the field is removed
- [ ] Cron entry registered in `.context/cron-registry.yaml`; `fw doctor` reports cron-registry-in-sync after the change

## Verification

grep -q "bvp-estimator" .context/cron-registry.yaml
bin/fw doctor 2>&1 | grep -q "Cron registry in sync"

## Decisions

## Updates
