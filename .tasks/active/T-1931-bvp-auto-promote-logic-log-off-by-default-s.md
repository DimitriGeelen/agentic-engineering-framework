---
id: T-1931
name: "BVP T-NEW-14a: auto-promote logic + log, off by default (split parent T-NEW-14, novel_mechanism)"
description: >
  Auto-promote logic reading auto_promote.* from policy/value-drivers.yaml. When enabled and a task is HV/LC (bvp_norm ≥ bvp_norm_min and cost ≤ cost_max), promote captured → started-work. Respects max_concurrent. Logs every promotion to .context/bvp-auto-promote-log.yaml. R4 detection metadata captured.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bvp, build, slice-14a, novel-mechanism]
components: [lib/bvp.sh, .context/bvp-auto-promote-log.yaml]
related_tasks: [T-1915, T-1916, T-1917, T-1924]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-19T13:47:44Z
date_finished: null
---

# T-1931: BVP T-NEW-14a — auto-promote logic + log (off by default)

## Context

First split-child of T-NEW-14 (handoff `novel_mechanism: yes` — first framework-driven status transition without per-event human approval). This slice = the logic and log, with `enabled: false` default. T-1932 covers enabling + cron.

**Source:** Handoff §7 T-NEW-14 (needs-split); artefact §6 row 15; §4 D8 (sovereignty at policy-edit time); §2 R4 (detection metadata), R7 (escalation drift mitigation).

**R4 detection lands here** — log must capture enough metadata to reconstruct the cost formula's reasoning post-hoc.

## Acceptance Criteria

### Agent
- [ ] Logic in `lib/bvp.sh` reads `auto_promote.*` from `policy/value-drivers.yaml`
- [ ] When `enabled: false` (the default), no auto-promotion occurs — this is the ship-state default
- [ ] When `enabled: true`, tasks satisfying both thresholds (`bvp_norm ≥ bvp_norm_min` AND `cost ≤ cost_max`) get promoted captured → started-work
- [ ] Respects `max_concurrent` — never promotes more than N tasks at once
- [ ] No promotion of tasks with unconfirmed `bvp_scores_proposed:` only — confirmation (`bvp_scores:` set by T-1924) is the sovereignty boundary
- [ ] Every auto-promotion writes to `.context/bvp-auto-promote-log.yaml` with: task_id, bvp_norm, cost, blast_radius, tier, effort, ts (R4 metadata)

## Verification

grep -q "auto_promote" lib/bvp.sh
# Default off — running the logic on a synthetic HV/LC task with enabled=false produces no log entry
# (covered by integration test, not a single-line shell check)

## Decisions

## Evolution

### 2026-05-19 — Filing
- **What changed:** Filed as split-child of T-NEW-14 — novel_mechanism (first framework-driven status transition without per-event human approval).
- **Plan impact:** Default OFF is non-negotiable (D8). T-1932 handles enabling-path; this slice MUST ship with enabled:false default and zero promotion on test.

## Updates

### 2026-05-19T13:47:44Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
