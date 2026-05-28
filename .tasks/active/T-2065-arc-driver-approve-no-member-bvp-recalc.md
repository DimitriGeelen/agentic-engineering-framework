---
id: T-2065
name: "arc driver-approve doesn't trigger automatic member-task BVP recalculation"
description: >
  When the human approves arc-scoped drivers (via `fw arc approve-driver` or
  `fw arc show-suggestions` accept-flow), the arc YAML mutates but no
  re-estimation runs against the arc's constituent tasks. Member-task
  `bvp_scores_proposed:` continue to reflect the OLD driver set (D1..D4 only);
  the new scoped driver gets zero coverage across the corpus. User: "arc-007
  drivers accepted, no automatically recaulation based on new drivers set
  takes place".
status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: [bug, arc, bvp, estimator, automation-gap, value-prioritisation]
components: [bin/fw, lib/arc.sh, agents/termlink/bvp-estimator/bvp-estimator.sh,
      .context/arcs/*.yaml]
related_tasks: [T-1918, T-1922, T-1925, T-1926, T-1930, T-1934, T-1935]
arc_id: value-prioritisation
created: 2026-05-28T14:30:00Z
last_update: '2026-05-28T15:35:00Z'
date_finished:
cost_estimate_proposed:
  - ts: '2026-05-28T12:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 5
      tier: 4
      effort: 6
    rationale: blast_radius=5 (no-signal); tier=4 (no-signal); effort=6
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-28T13:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 0
    rationale: D1=4 (body:structural-gate); D2=2
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2065: arc driver-approve doesn't trigger member-task BVP recalculation

## Problem Statement

User reported the gap. Verified in this session:
- arc-007 (`.context/arcs/watchtower-redesign.yaml`) `scoped_drivers:` was mutated when the human approved drivers; `proposed_scoped_drivers:` was processed.
- 46 tasks tagged arc-007 each have `bvp_scores_proposed:` written by the estimator with **only D1..D4 keys** — no scoped-driver scores.
- The CLAUDE.md §Arc-Scoped Driver Suggestion Workflow specifies "Estimator may write here freely (D7-reframe — persists for reuse not audit)" — but no mechanism re-fires the estimator across constituents when the driver set changes.

`fw arc approve-driver` mutates the arc YAML's `scoped_drivers:` list. The BVP estimator (`agents/termlink/bvp-estimator/bvp-estimator.sh`) is invoked at task-create (T-1922) — but not at arc-driver-set-change time. Result: the new scoped driver is unscored on the existing arc population, and its weight in `fw bvp rank` is effectively zero.

Why this matters: the arc's whole point is "scoring tasks against THIS driver separately". A driver approved but not back-applied is a driver that exists nowhere in the data.

## Assumptions

- A1: `lib/arc.sh:approve_driver` mutates `scoped_drivers:` synchronously and returns; no side-effect calls the estimator. **To verify:** read `lib/arc.sh` for `approve_driver`'s implementation.
- A2: The estimator (`agents/termlink/bvp-estimator/bvp-estimator.sh`) accepts a task-id arg and can be invoked per-task; it does not yet have a "rescore arc" verb. **To verify:** read estimator's invocation surface.
- A3: arc-007 has ~46 member tasks; per-task estimation costs ~10ms each → ~500ms total for synchronous rescore. **Bound check; informs candidate (a) feasibility.**

## Exploration Plan

1. **Trace `approve_driver`** (10 min) — confirm A1; identify the right hook point (after the YAML write, before returning success).
2. **Trace the estimator** (5 min) — confirm it accepts per-task invocation and can iterate `arc_id:` matches (or legacy `tags: [arc:<slug>]`).
3. **Benchmark** (5 min) — time a synchronous estimator run across arc-007's 46 tasks to validate A3.
4. **Pick candidate:** (a) synchronous in-process re-estimation, (b) async background dispatch via TermLink, (c) lazy (notice stale on next per-task touch), (d) separate verb `fw arc rescore <slug>` for explicit human invocation.
5. **File build child** with bats regression.

## Technical Constraints

- The estimator already exists and works per-task; no estimator changes required.
- `fw arc approve-driver` is §ACD-gated (sovereignty: refuses under `$CLAUDECODE=1`) — the rescore must run AFTER the human's approval is logged, not before.
- The mechanism must work for the analogous mutation points: `fw arc abandon`, `fw bvp driver --add/--remove`, and any future `fw arc replace-driver`.

## Scope Fence

**IN scope:**
- Re-estimation pathway tied to driver-set mutations (`approve_driver`, `bvp driver add/remove`).
- A `fw arc rescore <slug>` verb for explicit human invocation (regardless of which auto-path ships).
- Bats regression: "approve a driver on arc with N members → all N tasks gain the new driver key in `bvp_scores_proposed:` within T seconds".

**OUT of scope:**
- Estimator algorithm changes.
- BVP rubric changes (`policy/value-drivers.yaml`).
- Migrating legacy `tags: [arc:<slug>]` form (T-1881 already shipped).

## Acceptance Criteria

### Agent
- [ ] `approve_driver` trace recorded; the right hook point identified.
- [ ] Benchmark recorded for arc-007 (46 tasks) — confirm sync is feasible OR justify async.
- [ ] Build child filed with bats regression case.
- [ ] Cross-mutation audit: `fw arc abandon` and `fw bvp driver --add/--remove` checked for the same gap; siblings filed if found.

### Human
- [ ] [REVIEW] After remediation, approving a driver on a populated arc results in member-task `bvp_scores_proposed:` updating to include the new driver's score within an observable window (synchronous OR a clear "estimating N tasks…" progress signal).
  **Steps:**
  1. Pick an arc with current `scoped_drivers: []` (any arc not yet self-applied works as a clean test).
  2. Propose a driver (workflow may already have done this) and accept it: `cd /opt/999-Agentic-Engineering-Framework && bin/fw arc approve-driver <arc-id> "test-driver" --weight 3 --i-am-human`
  3. Grep one constituent task's `bvp_scores_proposed:` — confirm the new driver key appears.
  **Expected:** New key present in N member tasks (where N = arc size).
  **If not:** Capture the gap and file sibling.

## Go/No-Go Criteria

**GO if:**
- Hook point is contained (single function in `lib/arc.sh`).
- Synchronous OR async path is bounded (≤2s for arcs up to 100 members, OR clear progress UX).
- Regression case fits in <30 min.

**NO-GO if:**
- Estimator requires a refactor to support corpus rescoring.

**DEFER if:**
- Arcs are typically small (≤5 members) and the human runs `fw bvp rank` manually after approval — then ship (d) `fw arc rescore` only, document the manual step.

## Verification

# Currently: estimator triggers only at task-create (T-1922), NOT at arc-driver-approve.
# Manual reproduction (no auto-runnable check until remediation):
#   1. Read .context/arcs/watchtower-redesign.yaml — note current scoped_drivers
#   2. Read one constituent task's bvp_scores_proposed — note keys (D1..D4 only)
#   3. (No state change to verify pre-fix.)

## Recommendation

**Recommendation:** GO — combined (a)+(d): synchronous re-estimation in `approve_driver` AND a separate `fw arc rescore <slug>` verb.

**Rationale:** The synchronous path is the right shape because (i) the human is at the prompt when `approve_driver` runs, so a 500ms blocking call is acceptable, (ii) the data invariant ("approved drivers are scored across the corpus") is best maintained at the mutation site, (iii) async/lazy paths create observability gaps where a "fresh" approval hasn't propagated yet — confusing the human or the BVP rank consumer. The separate `fw arc rescore` verb covers the recovery case (estimator config change, rubric update, batch import) and gives the human an explicit re-fire mechanism. Async (b) and lazy (c) are wrong because they trade correctness for premature optimisation.

**Evidence:**
- Benchmark target (A3): 46 tasks × 10ms ≈ 500ms — well under interactive latency budget.
- The sovereignty boundary is preserved: human authorises the driver; the rescore runs as a deterministic consequence of that authorisation (not a separate decision).
- Same pattern shape as T-1922 (estimator-on-task-create) — adding the dual hook at "driver-set change" is symmetric and easy to reason about.

## Decisions

<!-- Filled when GO/NO-GO/DEFER chosen. -->

## Decision

<!-- Filled by `fw inception decide T-2065 go|no-go|defer --rationale "..."` -->

## Updates

### 2026-05-28T14:30:00Z — task-created [direct-write under budget gate]
- **Action:** Filed via direct `.tasks/active/` Write (Bash blocked at 98% budget).
- **Context:** User reported 4 bugs (T-2062..T-2065 batch); this one is the value-prioritisation / arc-grooming gap.

### 2026-05-28T15:35:00Z — refiled under canonical inception schema
- **Action:** Body remapped from bug-class RCA template to inception template.
- **Reason:** Watchtower `/inception/T-2065` rendered empty — see T-2066 for the structural fix.
