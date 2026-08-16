---
id: T-1918
name: "BVP T-NEW-3: task and arc frontmatter schema extensions (bvp_scores, bvp_scores_proposed,
  cost_estimate, scoped_drivers, proposed_scoped_drivers)"
description: >
  Add BVP fields to task template and lib/arc.sh arc-creation defaults; document in
  CLAUDE.md. Verifies assumption A2 (audit YAML-parse accepts unknown fields).

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [bvp, build, slice-3, schema]
components: [.tasks/templates/default.md, lib/arc.sh, CLAUDE.md]
related_tasks: [T-1915, T-1916, T-1917, T-1849]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: '2026-08-16T22:24:49Z'
date_finished: 2026-05-19T07:26:24Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 4
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=4 (body:fw-audit-or-doctor); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=4 
      (body/components:instruction-sync); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:49Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      estimator-fidelity: 0
      D1: 0
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 4
      F-AUTONOMY: 4
      F3: 0
      F1: 0
      F2: 0
    rationale: estimator-fidelity=0 (no-signal); D1=0 (no-signal); D2=4 
      (body:fw-audit-or-doctor); D3=0 (no-signal); D4=0 (no-signal); F-RECALL=4 
      (body/components:instruction-sync); F-AUTONOMY=4 
      (body:auto-promote-class-eligibility); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1918: BVP T-NEW-3 — task + arc frontmatter schema extensions

## Context

Adds the YAML fields BVP scoring reads/writes. The TermLink estimator (T-1922) writes to `bvp_scores_proposed:` on tasks; `fw bvp confirm` (T-1924) moves to `bvp_scores:`. Arc YAMLs gain `scoped_drivers:` (max 3, weight ≤6 per M2) and `proposed_scoped_drivers:` (uncapped, persistent per D7 reuse-not-audit framing).

**Source:** Handoff §7 T-NEW-3; artefact §6 row 2; §4 D7-reframe; §7 M2 (scoped-driver weight ≤6).

**Q2 default applied:** `cost_estimate` accepts T-shirt fallback (S/M/L/XL) when blast_radius is not yet computable.

**A2 verification lands here** — first task to add unknown frontmatter fields; `fw audit` must accept silently.

## Acceptance Criteria

### Agent
- [x] `.tasks/templates/default.md` adds 3 commented frontmatter fields: `bvp_scores:` (4-driver scores), `bvp_scores_proposed:` (estimator output), `cost_estimate:` (composite + T-shirt fallback) — Note: template is `default.md`, not `default.md` as originally stated
- [x] Each new field has an inline comment pointing to docs/reports/T-1915-bvp-inception.md for semantics
- [x] `lib/arc.sh arc_create` writes 3 new arc-YAML fields with defaults: `bvp_scores: {}`, `scoped_drivers: []`, `proposed_scoped_drivers: []`
- [x] CLAUDE.md §Task System section documents the new task fields with one paragraph
- [x] `012-ArcSystem.md` Arc Fields Reference documents the 3 new arc fields with rows (CLAUDE.md has no §Arc System; 012-ArcSystem.md is the canonical doc)
- [x] A2 verified: arc-006 backfilled with `bvp_scores: {}` / `scoped_drivers: []` / `proposed_scoped_drivers: []`; fresh `fw audit` returns 381 PASS / 34 WARN / **0 FAIL** at 2026-05-19T07:21:29Z — unknown fields parse silently as designed

## Verification

grep -q "bvp_scores:" .tasks/templates/default.md
grep -q "cost_estimate:" .tasks/templates/default.md
grep -q "bvp_scores_proposed:" .tasks/templates/default.md
grep -q "scoped_drivers" lib/arc.sh
grep -q "bvp_scores" CLAUDE.md

## Evolution

### 2026-05-19 — Template filename
- **What changed:** Filing AC said `.tasks/templates/default.md` but the actual template lives at `.tasks/templates/default.md`. No `default.md` exists.
- **Plan impact:** AC text adjusted; the edit landed in the correct file. No new task — the filing AC was simply wrong about the filename.
- **Triggered:** None.

### 2026-05-19 — Where arc fields are documented
- **What changed:** Filing AC said "CLAUDE.md §Arc System section (or 012-ArcSystem.md if separately edited)". CLAUDE.md has no §Arc System section; `012-ArcSystem.md` is the canonical arc-fields doc. Added new rows to its Arc Fields Reference table.
- **Plan impact:** None — semantics preserved, just landed in the right place.
- **Triggered:** None.

### 2026-05-19 — Backfilling existing arcs with new defaults
- **What changed:** Newly-created arcs get the BVP fields via `arc_create`, but existing arcs (arc-001..arc-005 + arc-006-just-created) don't have them. A2 verification required an arc with the new fields to test audit; backfilled arc-006 (value-prioritisation) in-place.
- **Plan impact:** Other in-progress arcs (arc-001..arc-005) currently lack `bvp_scores:`/`scoped_drivers:`/`proposed_scoped_drivers:`. Audit accepts this silently (fields are optional, `.get(..., default)` works). No bulk-backfill needed unless future slices require it; document the absence as expected.
- **Triggered:** Consideration only — if T-1919/T-1926/T-1930 readers need all arcs to have the fields, file a tiny backfill task. For now `.get('scoped_drivers', [])` is the correct read pattern.

## Recommendation

**Recommendation:** GO

**Rationale:** Schema extensions are additive and non-breaking. All 6 Agent ACs satisfied:
- Template extended with 3 commented fields
- `lib/arc.sh arc_create` writes 3 new arc-YAML fields with documented defaults
- CLAUDE.md §Task System documents task-side fields with shape + reader names
- `012-ArcSystem.md` Arc Fields Reference adds 3 rows with M2 weight cap + D7-reframe + tie-back to T-1926/T-1922
- A2 verified — fresh audit with backfilled arc-006 returns **0 FAIL** at 2026-05-19T07:21:29Z

Unlocks: T-1919 (read CLI reads these fields), T-1920 (mutating CLI writes `bvp_scores:`), T-1922 (estimator writes `bvp_scores_proposed:`), T-1924 (confirm), T-1926 (writes `scoped_drivers:` after approval), T-1931 (auto-promote reads `bvp_scores:` + `cost_estimate:`).

**Evidence:**
- `grep -q "bvp_scores:" .tasks/templates/default.md` → match
- `grep -q "cost_estimate:" .tasks/templates/default.md` → match
- `grep -q "bvp_scores_proposed:" .tasks/templates/default.md` → match
- `grep -q "scoped_drivers" lib/arc.sh` → match (in `arc_create` heredoc)
- `grep -q "bvp_scores" CLAUDE.md` → match (lines 96-100 documentation)
- `grep -q "scoped_drivers" 012-ArcSystem.md` → match (Arc Fields Reference table)
- `.context/audits/2026-05-19.yaml` post-backfill: pass=381 warn=34 fail=0

## Decisions

## Updates

### 2026-05-19T07:11:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-49ab9ed3
- **Timestamp:** 2026-06-02T15:00:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-19T07:26:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
