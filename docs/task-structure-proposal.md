# Task Structure Proposal: Sprechloop Onboarding Experiment

**Date:** 2026-02-17
**Source:** T-124 (current), docs/onboarding-observations.md

## 1. What Should T-124 Become?

**Current:** `workflow_type: build`, name "Document new-project onboarding tutorial"
**Problem:** Wrong type and scope. We're running a live experiment to discover and fix onboarding failures. That's inception, not build.

**Decision: Re-scope T-124 as inception.**

```yaml
id: T-124
name: Validate framework new-project onboarding via live sprechloop experiment
workflow_type: inception
description: >
  Multi-cycle live experiment using /opt/001-sprechloop as test bed.
  Protocol: fresh session → observe → document O-XXX → analyze → fix → verify → repeat.
  Done when two consecutive cycles produce zero new P0/P1 observations.
  Tutorial documentation is a downstream task, spawned only on GO decision.
related_tasks: [T-125, T-126, T-127, T-128, T-129]
```

**T-124 owns:** experiment protocol, observation log, cycle log, go/no-go decision, spawning child tasks.
**T-124 does NOT own:** implementing fixes (T-125–T-129) or writing the tutorial (post-GO).

## 2. Child Tasks

| Task | Name | Observations | Horizon |
|------|------|-------------|---------|
| T-125 | First-session orientation: detect empty state, guide new users | O-001, O-004 | now |
| T-126 | Inception gate: block build commits before `fw inception decide` | O-003, O-005 | now |
| T-127 | CLAUDE.md template sync + behavioral rules | O-002, O-006, O-007, O-009 | now (partially done) |
| T-128 | Circuit breaker: consecutive-commit guardrail | O-008 | next |
| T-129 | Inception template: Technical Constraints section | O-010 | next |

**Dependency:** T-125, T-126, T-127 must complete before Cycle 2. T-128, T-129 can be Cycle 2/3.

## 3. Experiment Protocol (Per Cycle)

### Step 1 — Reset
Prepare test environment. Record starting conditions.

### Step 2 — Observe (10-15 min)
New Claude session in sprechloop. Do NOT intervene except for data loss or regressions.

### Step 3 — Document
Stop session. Add O-XXX entries to observations log with severity.

### Step 4 — Analyze and Fix
Map to existing tasks. Work highest priority fix. Verify. Commit.

### Step 5 — Record Cycle
Update `docs/onboarding-cycles.md`. Restart from Step 1.

## 4. Go/No-Go Criteria

### GO (all must be met)
1. Two consecutive PASS cycles (zero new P0/P1)
2. All P0 fixes completed and verified (T-126, T-127)
3. Regression-clean (no fixed observation re-occurs)
4. Fresh `fw init` project includes all governance sections

### NO-GO (any triggers)
1. After 7 cycles, still generating new P0 observations
2. O-003/O-005 re-occurs after T-126 complete
3. Template drift re-occurs within one session of T-127

### On GO
```bash
fw inception decide T-124 go
fw task create --name "Write new-project onboarding tutorial" --type build --horizon now
```

## 5. Observation-to-Task Map

| Obs | Sev | Task | Status |
|-----|-----|------|--------|
| O-001 | P1 | T-125 | Pending |
| O-002 | P1 | T-127 | Pending |
| O-003 | P0 | T-126 | Pending |
| O-004 | P1 | T-125 | Pending |
| O-005 | P0 | T-126 | Pending |
| O-006 | P1 | T-127 | Pending |
| O-007 | P1 | T-127 | Pending |
| O-008 | P1 | T-128 | Pending |
| O-009 | P0 | T-127 | Partial (template synced) |
| O-010 | P1 | T-129 | Pending |
