---
id: T-1922
name: "BVP T-NEW-7a: TermLink bvp-estimator worker — harness + ready-status trigger (split parent T-NEW-7, novel_mechanism)"
description: >
  TermLink worker that scores tasks on ready-status transition. Writes to bvp_scores_proposed: only, never to confirmed bvp_scores:. v2-delta semantics (M3). A3 measurement — <5s, <2k tokens per task. Determinism AC (±1 over 20 historical tasks) blocks merge.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [bvp, build, slice-7a, termlink, novel-mechanism]
components: [agents/termlink/bvp-estimator/]
related_tasks: [T-1915, T-1916, T-1918, T-1921]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-19T07:00:00Z
date_finished: null
---

# T-1922: BVP T-NEW-7a — `bvp-estimator` worker harness + ready-trigger

## Context

First split-child of T-NEW-7 (handoff verdict: `novel_mechanism: yes` forces split). This slice covers the worker harness and ready-status trigger. T-1923 covers sweep + `fw resume` SLA fallback.

**Source:** Handoff §7 T-NEW-7 (needs-split); artefact §6 row 6; §2 R3 (determinism), §4 F4-deep (classifier framing — rubric application, not reasoning), §7 M3 (v2-delta semantics).

**A3 measurement happens HERE** (handoff §4a). Determinism AC is ship-blocking.

## Acceptance Criteria

### Agent
- [ ] `agents/termlink/bvp-estimator/` exists with worker script (Python or Rust per TermLink convention)
- [ ] Worker can be started via `fw termlink start bvp-estimator` (or analogue from `fw termlink dispatch` family)
- [ ] On task transition to "ready" status, worker scores task within target SLA (<5s avg)
- [ ] Worker writes ONLY to `bvp_scores_proposed:` block on task frontmatter — never to `bvp_scores:` (verified by hand-test: pre-set `bvp_scores: {D1: 3}` confirmed, run worker, verify untouched)
- [ ] v2-delta semantics: if estimator's score differs from confirmed `bvp_scores:` by ≥2 on ANY driver, write delta entry to `bvp_scores_proposed:`; if difference <2 everywhere, stay silent (M3)
- [ ] Re-running on the same task body produces scores within ±1 (determinism — R3 mitigation, ship-blocking)
- [ ] Worker reads rubric from `policy/bvp-scoring-rubric.md` at preload time (D4 reusable-state)
- [ ] A3 measurement: ran worker against 20 historical tasks from `.tasks/completed/`; per-task latency mean <5s, token mean <2k; results captured in `docs/reports/T-1922-a3-measurement.md`

## Verification

test -d agents/termlink/bvp-estimator
bin/fw termlink --help 2>&1 | grep -qi "bvp-estimator" || bin/fw termlink list 2>&1 | grep -qi "bvp-estimator"
test -f docs/reports/T-1922-a3-measurement.md

## Decisions

## Evolution

### 2026-05-19 — Filing
- **What changed:** Filed as split-child of T-NEW-7 (parent had `novel_mechanism: yes`).
- **Plan impact:** This slice (7a) MUST land determinism measurement before T-1923 (7b sweep) attaches. T-1923 is blocked on this.

## Updates
