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
components: [bin/fw, lib/arc.sh, agents/termlink/bvp-estimator/bvp-estimator.sh, .context/arcs/*.yaml]
related_tasks: [T-1918, T-1922, T-1925, T-1926, T-1930, T-1934, T-1935]
arc_id: value-prioritisation
created: 2026-05-28T14:30:00Z
last_update: 2026-05-28T14:30:00Z
date_finished: null
---

# T-2065: arc driver-approve doesn't trigger member-task BVP recalculation

## Context

User reported the gap. Verified in this session:
- arc-007 (`.context/arcs/watchtower-redesign.yaml`) currently shows `scoped_drivers:` is empty (or unread) AND `proposed_scoped_drivers: []` — proposals were either accepted-as-none OR moved to scoped_drivers but the YAML I'm reading shows scoped_drivers also empty
- 46 tasks tagged arc-007 each have `bvp_scores_proposed:` written by the estimator with **only D1..D4 keys** (no scoped-driver scores)
- The CLAUDE.md §Arc-Scoped Driver Suggestion Workflow specifies "Estimator may write here freely (D7-reframe — persists for reuse not audit)" — but no mechanism re-fires the estimator across constituents when the driver set changes

`fw arc approve-driver` mutates the arc YAML's `scoped_drivers:` list. The BVP estimator (`agents/termlink/bvp-estimator/bvp-estimator.sh`) is invoked at task-create (T-1922) — but not at arc-driver-set-change time. Result: the new scoped driver is unscored on the existing arc population.

Why this matters: the arc's whole point is "scoring tasks against THIS driver separately". A driver approved but not back-applied is a driver that exists nowhere in the data.

## Acceptance Criteria

### Agent
- [ ] Confirm symptom: `fw arc approve-driver arc-007 "..." --weight N --i-am-human` mutates the arc YAML but does NOT trigger re-estimation. Verify by reading a member task's `bvp_scores_proposed:` before and after a synthetic approval — assert no change.
- [ ] Identify the right trigger point: `lib/arc.sh:approve_driver` (the verb that mutates `scoped_drivers:`) — should it conditionally invoke the estimator on the arc's constituent tasks (matched by `arc_id:` OR legacy `tags: [arc:<slug>]`)?
- [ ] Decide GO/NO-GO/DEFER on remediation candidates:
  - (a) Synchronous re-estimation in `approve_driver` (slow for arcs with many members; arc-007 has 46 tasks × ~10ms each ≈ 500ms — acceptable)
  - (b) Asynchronous background dispatch (via TermLink worker or `disown &`) — same pattern as T-1922's task-create estimator trigger
  - (c) Lazy: estimator notices stale scores on next per-task touch (low cost, slow propagation across the corpus)
  - (d) Separate verb `fw arc rescore <slug>` the human can invoke explicitly (preserves §ACD-gated approval boundary)
- [ ] Audit `fw arc abandon` and `fw bvp driver --add/--remove` for the same gap class — anywhere the driver set mutates, the estimator should know.

### Human
- [ ] [REVIEW] After remediation, approving a driver on a populated arc (e.g. arc-007) results in member-task `bvp_scores_proposed:` updating to include the new driver's score within an observable window (synchronous OR a clear "estimating N tasks..." progress signal).

## Verification

# Currently: estimator triggers only at task-create (T-1922 lifecycle hook), NOT at arc-driver-approve. Confirm by:
# 1. Read .context/arcs/watchtower-redesign.yaml — note current scoped_drivers
# 2. Read one constituent task's bvp_scores_proposed — note keys (D1..D4 only)
# 3. (Manual reproduction step — not auto-runnable until remediation lands)

## RCA

**Symptom:** Human approves a new scoped driver for an arc. The arc YAML records the approval; the arc's 46 member tasks continue to be scored against the OLD 4-driver set. The new driver's contribution to BVP-rank is invisible.

**Root cause hypothesis:** The BVP estimator (T-1922) was wired into the task-create lifecycle hook (`update-task.sh --status started-work`). It was NOT wired into the arc-driver-mutation lifecycle. The two lifecycles intersect at "scope of valid driver set" but the wiring is one-way (task → estimator); there's no edge from (arc-driver-set-change → re-estimate-arc-members).

**Why structurally allowed:** arc-006 (value-prioritisation) shipped the driver-set + estimator infrastructure; the per-task trigger was the priority slice. The corpus-wide rescore was deferred or unfiled. CLAUDE.md §Arc-Scoped Driver Suggestion Workflow describes the human-approval step as the sovereignty boundary; it doesn't describe what happens to existing data after approval. The agent (this session, S-2026-0528) proposed 3 drivers for arc-007 and surfaced them to the human; the human approved (or rejected) them; the next propagation step was missing.

**Prevention:** Add a re-estimation pathway tied to `approve_driver` AND a "rescore corpus" verb for explicit human invocation. Pin with a bats test asserting "approve-driver on arc with N member tasks results in N tasks gaining the new driver key in bvp_scores_proposed within T seconds". Audit covers the analogous `bvp driver --add` / `bvp driver --remove` paths.

## Evolution

## Decisions

## Decision

<!-- Filled by `fw inception decide T-2065 go|no-go|defer --rationale "..."` -->

## Updates

### 2026-05-28T14:30:00Z — task-created [direct-write under budget gate]
- **Action:** Filed via direct .tasks/active/ Write (Bash blocked at 98% budget).
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2065-arc-driver-approve-no-member-bvp-recalc.md
- **Context:** User reported 4 bugs (T-2062..T-2065 batch); this one is the value-prioritisation / arc-grooming gap.
