---
id: T-1884
name: "promote CTL-026 sovereignty-gate check to compliance section — third twin of detection-window pattern"
description: >
  promote CTL-026 sovereignty-gate check to compliance section — third twin of detection-window pattern

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc-grooming, audit, prevention, governance]
components: []
related_tasks: [T-1882, T-1883, T-1846, T-1687, T-1870]
arc_id: arc-grooming
created: 2026-05-17T19:38:03Z
last_update: 2026-05-17T19:42:00Z
date_finished: null
---

# T-1884: promote CTL-026 sovereignty-gate check to compliance section — third twin of detection-window pattern

## Context

L-390 meta-lesson (recorded after T-1882 + T-1883): *detective-only audit checks placed in slow-cadence sections create proportional detection-window gaps; the check should live in the highest-frequency section appropriate to its detection class*.

CTL-026 verifies that the **Human Sovereignty Gate** (R-033) is wired in `agents/task-create/update-task.sh`. It currently lives inside the `oe-daily` block (audit.sh:2343-2356), so a commit that accidentally removes the gate (e.g. during a refactor of `update-task.sh`) is not caught until the daily cron — up to 24h after push.

Detection class is *different* from T-1882/T-1883: CTL-026 is a **framework-source presence check** (grep), not a corpus scan. But the detection-window gap is the same — and arguably more severe, because the gate-source can be regressed by the very commit being pushed.

Promotion is mechanically identical to T-1882/T-1883: extract from `oe-daily`, gate with `compliance || oe-daily`, add regression tests (firing-path + negative gate-granularity).

## Acceptance Criteria

### Agent
- [x] CTL-026 block extracted from `oe-daily` and gated by `compliance || oe-daily`
- [x] `bin/fw audit --section compliance` emits a CTL-026 line (PASS in clean repo)
- [x] `bin/fw audit --section oe-daily` still emits CTL-026 (no regression)
- [x] Pre-push profile (`--section structure,compliance,quality,discovery`) emits CTL-026
- [x] `--section structure` alone does NOT emit CTL-026 (gate granularity)
- [x] New bats test file `tests/unit/audit_ctl026_compliance_section.bats` with 4 cases, all PASS
- [ ] L-390 amended to note third instance (CTL-026) of the meta-lesson

### Human
<!-- All ACs above are deterministic shell-runnable; no Human AC needed. -->

## Verification

# Pre-push path emits CTL-026
out=$(bin/fw audit --section compliance 2>&1); echo "$out" | grep -q "CTL-026"
# oe-daily path still emits CTL-026 (no regression)
out=$(bin/fw audit --section oe-daily 2>&1); echo "$out" | grep -q "CTL-026"
# structure-only does NOT emit CTL-026
out=$(bin/fw audit --section structure 2>&1); ! echo "$out" | grep -q "CTL-026"
# Regression tests pass
bats tests/unit/audit_ctl026_compliance_section.bats

## Evolution

### 2026-05-17 — third twin of L-390 meta-lesson
- **What changed:** Confirmed L-390 generalises beyond AC/status side. CTL-026 is a *framework-source* presence check rather than a corpus scan, but suffers the same detection-window proportionality. Pattern now has three independent instances (CTL-028 status, CTL-012 AC, CTL-026 framework-source).
- **Plan impact:** Sweep candidates list from T-1883 amendment narrows — CTL-027 (inception template per-task scan) is the last twin candidate. After this, the L-390 sweep is exhausted.
- **Triggered:** No new sub-task. L-390 receives a third-instance amendment.

## Decisions

### 2026-05-17 — Promotion target = compliance (not structure)
- **Chose:** Gate with `compliance || oe-daily`, matching T-1882/T-1883.
- **Why:** Structure is intentionally lean for fast pre-push (file-presence, ID uniqueness). Compliance is the correct home for "is the framework's enforcement actually wired" checks. Pre-push profile already includes compliance, so this gets the desired detection-window collapse without bloating structure.
- **Rejected:** Promote to structure (too broad, slows pre-push); keep in oe-daily and rely on cron (24h gap, original problem).
