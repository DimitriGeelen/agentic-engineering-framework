---
id: T-558
name: "Build task risk signal detection — PreToolUse gate requiring inception for
  high-impact builds"
description: >
  Apply structural risk signals as PreToolUse gate on BUILD tasks (not inception creation).
  When a build task edits files that trigger risk signals (new subsystem via fabric,
  cross-subsystem impact >3 dependents, external system files in deploy/infrastructure/,
  governance layer files, irreversible operations), warn or block: 'This build touches
  3 subsystems — did you do inception first?' Signals are observable at build time
  (unlike inception creation time where future is unknown). Extends check-active-task.sh
  with ~60 lines. Precedent: budget gate, task gate, build readiness gate. Origin:
  T-549 steelman/strawman analysis — steelman signals valid but apply to builds not
  inceptions.

status: captured
workflow_type: inception
owner: human
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-23T16:36:06Z
last_update: '2026-05-28T22:54:12Z'
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-558: Build task risk signal detection — PreToolUse gate requiring inception for high-impact builds

## Problem Statement

Agents sometimes create build tasks for work that should have gone through inception first — complex, cross-subsystem changes that commit resources without validating assumptions. Should we add a PreToolUse gate that detects "risk signals" at build time and warns/blocks?

Origin: T-549 steelman/strawman analysis concluded risk signals are valid but apply to builds (not inception creation, since future scope is unknown at that point).

## Assumptions

1. Build tasks sometimes touch high-blast-radius areas without prior inception
2. Risk signals are detectable at write-time (file path, fabric dependents, subsystem count)
3. The gap is not already covered by existing guards
4. The benefit outweighs the performance cost and false positive noise

## Exploration Plan

1. **Audit existing guards** — What does check-active-task.sh already catch? (30 min)
2. **Identify uncovered gap** — What specific incident would this have prevented? (30 min)
3. **Recommend** — GO if clear gap exists, NO-GO/DEFER if existing guards suffice

## Technical Constraints

- check-active-task.sh runs on EVERY Write/Edit call — must be fast (<50ms)
- Fabric queries require Python + YAML parsing — adds latency
- False positives degrade trust in the enforcement system

## Scope Fence

**IN:** Whether to build a risk signal gate for build tasks
**OUT:** Changes to inception creation flow, changes to fabric advisory

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read the analysis below
  2. Evaluate whether the uncovered gap warrants a new gate
  3. Run: `fw inception decide T-558 go|no-go|defer --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Clear evidence of incidents where existing guards failed to prevent unscoped high-impact builds
- Performance impact acceptable (<50ms per hook invocation)

**NO-GO if:**
- Existing guards already cover the gap adequately
- Benefit is marginal compared to added complexity and false positive risk

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Recommendation

**Recommendation:** DEFER
**Rationale:** Existing 7 guards cover proposed risk signals, no concrete gap identified

## Decisions

**Decision**: DEFER

**Rationale**: Existing 7 guards cover proposed risk signals, no concrete gap identified

**Date**: 2026-03-25T15:54:38Z

## Findings

### Existing Guards (check-active-task.sh, 340 lines)

| Guard | What it catches | Lines |
|-------|----------------|-------|
| B-005 | Agent modifying settings.json (disabling enforcement) | 42-56 |
| Task gate | No active task → block | 107-118 |
| Status validation | Task not started-work → block | 169-204 |
| Onboarding gate | Incomplete onboarding → block non-onboarding work | 206-254 |
| Inception awareness | Active inception task → warn (advisory) | 256-263 |
| Build readiness G-020 | Placeholder ACs on build task → block | 265-293 |
| Fabric advisory | File has N dependents → warn (advisory) | 296-336 |

### What T-558 Would Add

Proposed signals at write-time:
1. File in `deploy/` or `infrastructure/` → warn "infrastructure change"
2. File has >3 fabric dependents → warn "high-blast-radius"
3. File creates new subsystem directory → warn "new subsystem"
4. Cross-subsystem edits (3+ subsystems in one task) → warn

### Gap Analysis

- **Signal #1 (infrastructure):** No `deploy/` or `infrastructure/` directories exist in this project. Speculative.
- **Signal #2 (high dependents):** Already covered by the **fabric advisory** (lines 296-336) which warns "$FILE has N downstream dependent(s)".
- **Signal #3 (new subsystem):** Hard to detect at write-time — a new file doesn't mean a new subsystem until it's registered.
- **Signal #4 (cross-subsystem):** Would require tracking edits across the session — statefulness adds complexity. Also, many legitimate build tasks touch 3+ subsystems (e.g., adding a new fw route touches `bin/fw`, `lib/`, `CLAUDE.md`).

### Recommendation: DEFER

The existing guards cover the most impactful cases:
- **G-020** blocks builds with no real ACs (the #1 cause of unscoped builds from pickup messages)
- **Fabric advisory** warns about high-dependent files
- **Inception awareness** warns when building under an inception task
- **CLAUDE.md rules** (pickup message handling, inception discipline) govern agent behavior

The remaining uncovered gap — a properly-scoped build task that should have been inception — is narrow. No incident in project history was caused by this specific failure mode. The T-549 analysis that motivated this task validated the concept but did not identify a concrete incident.

Adding ~60 lines and Python-based fabric queries to every Write/Edit call for a gap that hasn't manifested would be over-engineering. If we see a real incident, we should revisit.

## Decision

**Decision**: DEFER

**Rationale**: Existing 7 guards cover proposed risk signals, no concrete gap identified

**Date**: 2026-03-25T15:54:38Z

## Updates

### 2026-03-25T10:30:00Z — inception-exploration [agent]
- **Action:** Audited existing guards in check-active-task.sh, identified 7 active gates
- **Finding:** Proposed risk signals are either already covered (fabric advisory, G-020) or speculative (infrastructure paths, cross-subsystem tracking)
- **Recommendation:** DEFER — no evidence of the specific failure mode this would prevent

### 2026-03-25T09:53:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-25T15:16:19Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Existing 7 guards cover proposed risk signals, no  
  concrete gap identified

### 2026-03-25T15:54:38Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Existing 7 guards cover proposed risk signals, no concrete gap identified

### 2026-03-27 — artifact-reference [audit-fix]
- **Research artifact:** docs/reports/T-558-risk-signal-gate-analysis.md

### 2026-04-06T22:23:16Z — status-update [task-update-agent]
- **Change:** horizon: next → later

### 2026-04-23T16:46:50Z — status-update [task-update-agent]
- **Change:** horizon: later → next

### 2026-04-28T16:09:25Z — status-update [task-update-agent]
- **Change:** horizon: next → next
