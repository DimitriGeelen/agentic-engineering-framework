---
id: T-1933
name: "BVP T-NEW-15: canonical doc 040-ValueDrivers.md + FRAMEWORK.md glossary/Quick Reference updates (cites Geelen origin + AEF adaptations)"
description: >
  New canonical doc 040-ValueDrivers.md mirroring 010-TaskSystem.md / 012-ArcSystem.md structure. FRAMEWORK.md glossary gains BVP terms; Quick Reference adds the new fw bvp + fw arc approve-driver verbs. Cites Geelen 2019 origin AND AEF adaptations.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bvp, build, slice-15, docs, canonical]
components: [040-ValueDrivers.md, FRAMEWORK.md]
related_tasks: [T-1915, T-1916, T-1917, T-1920, T-1924, T-1926, T-1932]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-19T13:37:48Z
date_finished: null
---

# T-1933: BVP T-NEW-15 — `040-ValueDrivers.md` + FRAMEWORK.md updates

## Context

Ships LAST in arc-006 — describes the post-implementation state, not the planned state.

**Source:** Handoff §7 T-NEW-15; artefact §6 row 17; §4 Geelen origin + AEF adaptations; §7 M1-M7 (all mechanics must appear).

## Acceptance Criteria

### Agent
- [ ] `040-ValueDrivers.md` exists at repo root with sections: Overview, The Four Constitutional Directives, Free Drivers (incl. M1 add-one-drop-one), Arc-Scoped Drivers (incl. M2 weight ≤6), Scoring (0-5 × 0-9 weight), Quadrants, Cost Composite (incl. F8-mechanic 3-component disclosure), BVP Estimator (incl. M3 v2-delta), Driver Decision Gate, fw bvp CLI (M7 full surface), fw arc approve-driver CLI (M6 §ACD gate), Relation to Authority Model (D8 sovereignty-at-policy-edit), Reversibility statement (no one-way doors)
- [ ] Geelen 2019 origin cited with URL; AEF adaptations explicitly distinguished
- [ ] `FRAMEWORK.md` glossary section gains entries for: BVP, value driver, free driver, arc-scoped driver, directive scoring, quadrant
- [ ] `FRAMEWORK.md` Quick Reference section gains rows for: `fw bvp`, `fw bvp weight`, `fw bvp confirm`, `fw arc approve-driver`, `fw arc show-suggestions`

### Human
- [ ] [REVIEW] Document reads accurately and matches the shipped implementation (R9 mitigation — once published, the rubric/doc carry weight; check before merge)
  **Steps:**
  1. Read `040-ValueDrivers.md` end-to-end
  2. Verify each claim against `lib/bvp.sh`, `policy/value-drivers.yaml`, `policy/bvp-scoring-rubric.md`
  3. Spot-check 3 CLI examples actually work as documented
  **Expected:** No discrepancies between doc and implementation
  **If not:** Edit before merging

## Verification

test -f 040-ValueDrivers.md
grep -q "Business Value Points\|BVP" FRAMEWORK.md
grep -q "fw bvp" FRAMEWORK.md
grep -qi "blog.dimitrigeelen" 040-ValueDrivers.md

## Decisions

## Updates

### 2026-05-19T13:37:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
