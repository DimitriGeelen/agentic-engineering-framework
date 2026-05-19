---
id: T-1918
name: "BVP T-NEW-3: task and arc frontmatter schema extensions (bvp_scores, bvp_scores_proposed, cost_estimate, scoped_drivers, proposed_scoped_drivers)"
description: >
  Add BVP fields to task template and lib/arc.sh arc-creation defaults; document in CLAUDE.md. Verifies assumption A2 (audit YAML-parse accepts unknown fields).

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [bvp, build, slice-3, schema]
components: [.tasks/templates/zzz-default.md, lib/arc.sh, CLAUDE.md]
related_tasks: [T-1915, T-1916, T-1917, T-1849]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-19T07:00:00Z
date_finished: null
---

# T-1918: BVP T-NEW-3 — task + arc frontmatter schema extensions

## Context

Adds the YAML fields BVP scoring reads/writes. The TermLink estimator (T-1922) writes to `bvp_scores_proposed:` on tasks; `fw bvp confirm` (T-1924) moves to `bvp_scores:`. Arc YAMLs gain `scoped_drivers:` (max 3, weight ≤6 per M2) and `proposed_scoped_drivers:` (uncapped, persistent per D7 reuse-not-audit framing).

**Source:** Handoff §7 T-NEW-3; artefact §6 row 2; §4 D7-reframe; §7 M2 (scoped-driver weight ≤6).

**Q2 default applied:** `cost_estimate` accepts T-shirt fallback (S/M/L/XL) when blast_radius is not yet computable.

**A2 verification lands here** — first task to add unknown frontmatter fields; `fw audit` must accept silently.

## Acceptance Criteria

### Agent
- [ ] `.tasks/templates/zzz-default.md` adds 3 commented frontmatter fields: `bvp_scores:` (4-driver scores), `bvp_scores_proposed:` (estimator output), `cost_estimate:` (composite + T-shirt fallback)
- [ ] Each new field has an inline comment pointing to docs/reports/T-1915-bvp-inception.md for semantics
- [ ] `lib/arc.sh arc_create` writes 3 new arc-YAML fields with defaults: `bvp_scores: {}`, `scoped_drivers: []`, `proposed_scoped_drivers: []`
- [ ] CLAUDE.md §Task System section documents the new task fields with one paragraph
- [ ] CLAUDE.md §Arc System section (or 012-ArcSystem.md if separately edited) documents the new arc fields with one paragraph
- [ ] A2 verified: create a test task with `bvp_scores: {D1: 3}` and a test arc with `scoped_drivers: []`; run `fw audit`; both pass without WARN/FAIL on the unknown fields

## Verification

grep -q "bvp_scores:" .tasks/templates/zzz-default.md
grep -q "cost_estimate:" .tasks/templates/zzz-default.md
grep -q "bvp_scores_proposed:" .tasks/templates/zzz-default.md
grep -q "scoped_drivers" lib/arc.sh
grep -q "bvp_scores" CLAUDE.md

## Decisions

## Updates
