---
id: T-1933
name: "BVP T-NEW-15: canonical doc 040-ValueDrivers.md + FRAMEWORK.md glossary/Quick
  Reference updates (cites Geelen origin + AEF adaptations)"
description: >
  New canonical doc 040-ValueDrivers.md mirroring 010-TaskSystem.md / 012-ArcSystem.md
  structure. FRAMEWORK.md glossary gains BVP terms; Quick Reference adds the new fw
  bvp + fw arc approve-driver verbs. Cites Geelen 2019 origin AND AEF adaptations.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [bvp, build, slice-15, docs, canonical]
components: [040-ValueDrivers.md, FRAMEWORK.md]
related_tasks: [T-1915, T-1916, T-1917, T-1920, T-1924, T-1926, T-1932]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: '2026-08-16T22:24:01Z'
date_finished: 2026-05-19T13:46:56Z
bvp_scores_proposed:
  - ts: '2026-05-19T17:56:35Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:10Z'
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
  - ts: '2026-06-11T22:23:26Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 4
      F-ORCH: 4
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=4 (body/components:instruction-sync); F-ORCH=4 
      (body:rubric-routable); F3=1 (body/components:prompt-incidental); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      estimator-fidelity: 1
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 4
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: estimator-fidelity=1 
      (body/components:estimator-fidelity-incidental); D1=4 
      (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=4 (body/components:instruction-sync); F-AUTONOMY=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1933: BVP T-NEW-15 — `040-ValueDrivers.md` + FRAMEWORK.md updates

## Context

Ships LAST in arc-006 — describes the post-implementation state, not the planned state.

**Source:** Handoff §7 T-NEW-15; artefact §6 row 17; §4 Geelen origin + AEF adaptations; §7 M1-M7 (all mechanics must appear).

## Acceptance Criteria

### Agent
- [x] `040-ValueDrivers.md` exists at repo root with sections: Overview, The Four Constitutional Directives, Free Drivers (incl. M1 add-one-drop-one), Arc-Scoped Drivers (incl. M2 weight ≤6), Scoring (0-5 × 0-9 weight), Quadrants, Cost Composite (incl. F8-mechanic 3-component disclosure), BVP Estimator (incl. M3 v2-delta), Driver Decision Gate, fw bvp CLI (M7 full surface), fw arc approve-driver CLI (M6 §ACD gate), Relation to Authority Model (D8 sovereignty-at-policy-edit), Reversibility statement (no one-way doors)
- [x] Geelen 2019 origin cited with URL; AEF adaptations explicitly distinguished
- [x] `FRAMEWORK.md` glossary section gains entries for: BVP, value driver, free driver, arc-scoped driver, directive scoring, quadrant
- [x] `FRAMEWORK.md` Quick Reference section gains rows for: `fw bvp`, `fw bvp weight`, `fw bvp confirm`, `fw arc approve-driver`, `fw arc show-suggestions`

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

## Recommendation

**Recommendation:** GO (partial-complete — load-bearing [REVIEW] Human AC pending)

**Rationale:** All 4 Agent ACs met. `040-ValueDrivers.md` (236 lines) ships at repo root with every required section: Overview, Four Constitutional Directives, Free Drivers (M1), Arc-Scoped Drivers (M2), Scoring rubric (0-5 × 0-9), Quadrants (median × median), Cost Composite (F8 3-component disclosure + Q2 T-shirt fallback), BVP Estimator (M3 v2-delta), Driver Decision Gate, full `fw bvp` CLI surface (M7), `fw arc approve-driver` CLI (M6 §ACD gate), Authority Model relation (D8 sovereignty-at-policy-edit), and Reversibility (no one-way doors). Geelen 2019 origin cited with canonical blog URL; AEF adaptations explicitly listed (directive binding, scoped drivers, estimator, cost composite, §ACD gates). FRAMEWORK.md glossary gained 6 BVP entries; Quick Reference gained 7 `fw bvp` + `fw arc approve-driver`/`show-suggestions` rows. Human [REVIEW] AC remains: review doc-vs-implementation parity once (R9 mitigation — once published, the doc carries weight).

**Evidence:**
- `040-ValueDrivers.md` — 236 lines, 14 H2 sections, all required mechanics referenced
- FRAMEWORK.md Quick Reference — 7 BVP rows added above the Glossary section
- FRAMEWORK.md Glossary — 6 BVP entries appended (BVP, Value Driver, Free Driver, Arc-Scoped Driver, Directive Scoring, Quadrant)
- Verification (4/4 PASS): `test -f 040-ValueDrivers.md` + 3 grep checks for BVP / `fw bvp` / Geelen URL
- arc-006 (value-prioritisation) slice 15 of 17 shipped

## Decisions

## Updates

### 2026-05-19T13:37:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.4)

- **Scan ID:** R-3974e1d5
- **Timestamp:** 2026-05-19T13:46:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-19T13:46:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
