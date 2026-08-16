---
id: T-1931
name: "BVP T-NEW-14a: auto-promote logic + log, off by default (split parent T-NEW-14,
  novel_mechanism)"
description: >
  Auto-promote logic reading auto_promote.* from policy/value-drivers.yaml. When enabled
  and a task is HV/LC (bvp_norm ≥ bvp_norm_min and cost ≤ cost_max), promote captured
  → started-work. Respects max_concurrent. Logs every promotion to .context/bvp-auto-promote-log.yaml.
  R4 detection metadata captured.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [bvp, build, slice-14a, novel-mechanism]
components: [012-ArcSystem.md, lib/arc.sh, lib/bvp.sh]
related_tasks: [T-1915, T-1916, T-1917, T-1924]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: '2026-08-16T22:24:49Z'
date_finished: 2026-05-19T13:54:28Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:03Z'
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
    rationale: D1=0 (tag:novel-mechanism); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:49Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      estimator-fidelity: 1
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 4
      F3: 0
      F1: 0
      F2: 0
    rationale: estimator-fidelity=1 
      (body/components:estimator-fidelity-incidental); D1=0 
      (tag:novel-mechanism); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=4 
      (body:auto-promote-class-eligibility); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1931: BVP T-NEW-14a — auto-promote logic + log (off by default)

## Context

First split-child of T-NEW-14 (handoff `novel_mechanism: yes` — first framework-driven status transition without per-event human approval). This slice = the logic and log, with `enabled: false` default. T-1932 covers enabling + cron.

**Source:** Handoff §7 T-NEW-14 (needs-split); artefact §6 row 15; §4 D8 (sovereignty at policy-edit time); §2 R4 (detection metadata), R7 (escalation drift mitigation).

**R4 detection lands here** — log must capture enough metadata to reconstruct the cost formula's reasoning post-hoc.

## Acceptance Criteria

### Agent
- [x] Logic in `lib/bvp.sh` reads `auto_promote.*` from `policy/value-drivers.yaml`
- [x] When `enabled: false` (the default), no auto-promotion occurs — this is the ship-state default
- [x] When `enabled: true`, tasks satisfying both thresholds (`bvp_norm ≥ bvp_norm_min` AND `cost ≤ cost_max`) get promoted captured → started-work
- [x] Respects `max_concurrent` — never promotes more than N tasks at once
- [x] No promotion of tasks with unconfirmed `bvp_scores_proposed:` only — confirmation (`bvp_scores:` set by T-1924) is the sovereignty boundary
- [x] Every auto-promotion writes to `.context/bvp-auto-promote-log.yaml` with: task_id, bvp_norm, cost, blast_radius, tier, effort, ts (R4 metadata)

## Verification

out=$(bin/fw bvp auto-promote 2>&1 || true); echo "$out" | grep -q "Auto-promote disabled"
grep -q "auto_promote" lib/bvp.sh
grep -q "auto-promote" lib/bvp.sh
test -f .context/bvp-auto-promote-log.yaml
test -f tests/unit/bvp_auto_promote.bats
bats tests/unit/bvp_auto_promote.bats 2>&1 | tail -1 | grep -qE "ok 6|^6\.\.6"

## Recommendation

**Recommendation:** GO

**Rationale:** All 6 Agent ACs proven end-to-end via 6-test bats suite plus the live `bin/fw bvp auto-promote` invocation. The OFF default is the ship-state — invoking with the shipped `auto_promote.enabled: false` produces a clear no-op message and writes nothing. The enabled-path was probed in a controlled fixture (synthetic captured task with confirmed `bvp_scores: {D1:5,D2:5,D3:5,D4:5}` → `bvp_norm=1.0`, three-component cost = `0.6*0 + 0.3*0 + 0.1*1 = 0.1` ≤ `cost_max=1`) and produced exactly the expected behavior: dry-run lists the candidate without mutation; real run promoted `captured → started-work` and wrote one R4 log entry with all seven fields (`task_id`, `ts`, `bvp_norm`, `cost`, `cost_components.{blast_radius,tier,effort,source}`, `thresholds_at_decision.{bvp_norm_min,cost_max,max_concurrent}`, `mechanism`). The `max_concurrent` ceiling is enforced (refused promotion under `max_concurrent=1` with 33 started tasks). M3 sovereignty boundary is enforced (tasks with only `bvp_scores_proposed:` skipped). Test fixture state fully reverted post-probe.

**Evidence:**
- `lib/bvp.sh:c.747` — new `cmd_auto_promote()` (~140 lines), wired to dispatcher at `main()` and to `usage()`
- `lib/bvp.sh:107` — `AUTO_PROMOTE_LOG` path constant
- `.context/bvp-auto-promote-log.yaml` — ships clean (`entries: []`) with R4 schema header
- `tests/unit/bvp_auto_promote.bats` — 6 tests, all passing: OFF default × 2, dry-run, full promotion + R4, max_concurrent ceiling, M3 sovereignty
- `policy/value-drivers.yaml` — unchanged (still `enabled: false`, `max_concurrent: 1`)
- arc-006 (value-prioritisation) slice 14a of 17 shipped — T-1932 (enabling + cron wiring) is next

## Decisions

## Evolution

### 2026-05-19 — Filing
- **What changed:** Filed as split-child of T-NEW-14 — novel_mechanism (first framework-driven status transition without per-event human approval).
- **Plan impact:** Default OFF is non-negotiable (D8). T-1932 handles enabling-path; this slice MUST ship with enabled:false default and zero promotion on test.

## Updates

### 2026-05-19T13:47:44Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3a90da19
- **Timestamp:** 2026-06-02T15:00:32Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — Logic in `lib/bvp.sh` reads `auto_promote.*` from `policy/value-drivers.yaml`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=policy/value-drivers.yaml in: Logic in `lib/bvp.sh` reads `auto_promote.*` from `policy/value-drivers.yaml``

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 6
     - evidence: `bats tests/unit/bvp_auto_promote.bats 2>&1 | tail -1 | grep -qE "ok 6|^6\.\.6"`
### 2026-05-19T13:54:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
