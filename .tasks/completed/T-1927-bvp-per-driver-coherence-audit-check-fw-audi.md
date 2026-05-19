---
id: T-1927
name: "BVP T-NEW-11: per-driver coherence audit check (fw audit warns when arc claims D_n≥4 but ≥70% constituents score D_n≤1)"
description: >
  Audit-side coherence check. Per-driver, not aggregated (D3 rejected aggregation). Non-blocking — fw audit exit code unaffected. Thresholds (4/70%/1) configurable. R2 detection — rubric bias surfaces here.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [bvp, build, slice-11, audit]
components: [agents/audit/audit.sh]
related_tasks: [T-1915, T-1916, T-1924, T-1850]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-19T07:00:00Z
date_finished: null
---

# T-1927: BVP T-NEW-11 — per-driver coherence audit

## Context

D3 — coherence is a per-driver sanity check, NOT an aggregation input to arc BVP. Enumerates constituents via `arc_id:` (arc-grooming T-NEW-3 migration must have landed, which it has — T-1850).

**Source:** Handoff §7 T-NEW-11; artefact §6 row 11; §4 D3; §7 M4 (thresholds: 4/70%/1).

**R2 detection:** systematic single-driver warnings indicate rubric bias, not arc mis-scoring.

## Acceptance Criteria

### Agent
- [ ] `agents/audit/audit.sh` gains a new section emitting `coherence: arc <id> claims D<n>=<x> but tasks don't support it (Y of Z constituents score ≤1)` warnings when applicable
- [ ] Check is per-driver — separate WARN per mismatched driver, not aggregated
- [ ] Check is non-blocking — `fw audit` exit code unaffected by coherence WARNs (compliance section still drives exit)
- [ ] Thresholds defined as constants at top of audit.sh: `BVP_COHERENCE_ARC_MIN=4`, `BVP_COHERENCE_TASK_MAX=1`, `BVP_COHERENCE_FRACTION=0.7`
- [ ] Test fixture: construct an arc claiming D1=5 with 5 constituents scoring D1=0; run `fw audit`; verify the WARN appears

## Verification

grep -q "BVP_COHERENCE" agents/audit/audit.sh
grep -q "coherence" agents/audit/audit.sh

## Decisions

## Updates
