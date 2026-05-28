---
id: T-1928
name: "BVP T-NEW-12a: Watchtower /bvp static scatter read-only (split parent T-NEW-12)"
description: >
  New Watchtower tab /bvp. Static quadrant scatter — arcs as larger dots, tasks as
  smaller, axes BVP_norm × cost. Read-only — no weight mutation yet (12b adds sliders).
  Render-surface, [REVIEW] Human AC required (T-1766 P-013).

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [bvp, build, slice-12a, web, render-surface]
components: [bin/fw, lib/bvp.sh]
related_tasks: [T-1915, T-1916, T-1919]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: '2026-05-28T22:54:10Z'
date_finished: 2026-05-19T16:52:32Z
bvp_scores_proposed:
  - ts: '2026-05-19T17:56:35Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 3
      D4: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 3
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F1=0 (no-signal); F2=0
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1928: BVP T-NEW-12a — `/bvp` static scatter (read-only)

## Context

First split-child of T-NEW-12 (handoff `needs-split` because novel-mechanism: live weight sliders). This slice = static scatter only; T-1929 adds live sliders + commit.

**Source:** Handoff §7 T-NEW-12 (needs-split); artefact §6 row 12; §4 F8-mechanic (3-component cost MUST be diagnosable).

**Render-surface gate (T-1766 P-013):** any task touching web/templates or web/blueprints requires at least one `[REVIEW]` Human AC.

**R4 detection lands here** via the Human AC spot-check.

## Acceptance Criteria

### Agent
- [x] `web/blueprints/bvp.py` exists; registered via `web/blueprints/__init__.py:register_blueprints` (centralised pattern per T-431/A2; `web/app.py:147` calls the centraliser, doesn't import individual blueprints)
- [x] `/bvp` route returns HTTP 200 and renders the page without error (empty state when no `bvp_scores:` set yet, populated when scored — live probe in scored state passed 4/4 checks)
- [x] Scatter plot shows current tasks and arcs in their quadrant positions — uses **d3 v7** (already vendored at `web/static/d3.v7.min.js`, matches `web/templates/fabric_explorer.html` which is the codebase's existing graph stack)
- [x] Cost composite shown with 3 sub-components visible on hover (blast_radius, tier, effort) — see `tipHTML(d)` in `web/templates/bvp.html` rendering `cost = br×0.6 + tier×0.3 + effort×0.1` with each sub-component; T-shirt fallback (Q2) and absent state also disclosed
- [x] No client-side state mutation — page is purely read-only (no sliders, no fetch/post); T-1929 (T-NEW-12b) adds live sliders

### Human
- [ ] [REVIEW] Quadrant placement is intuitive across a 5-task spot-check (R4 mitigation)
  **Steps:**
  1. Open http://192.168.10.107:3000/bvp
  2. Pick 5 random tasks from the scatter
  3. For each, ask: does its quadrant placement match your intuition?
  **Expected:** ≥4/5 placements match
  **If not:** A6 cost formula assumption needs revisiting; file a follow-up for re-weighting

## Verification

test -f web/blueprints/bvp.py
test -f web/templates/bvp.html
grep -q "bvp_bp\|web.blueprints.bvp" web/blueprints/__init__.py
out=$(curl -sf "$(bin/fw watchtower url)/bvp" 2>&1); echo "$out" | grep -qi "quadrant\|scatter"
out=$(bin/fw test playwright -- tests/playwright/test_bvp_scatter.py 2>&1); grep -qE '[0-9]+ passed' <<<"$out" && ! grep -qE '[0-9]+ failed' <<<"$out"

## Recommendation

**Recommendation:** GO

**Rationale:** The /bvp render-surface lands the static read-only quadrant
scatter (T-NEW-12a). Empty-state copy + populated-state scatter both render
HTTP 200; the 4-quadrant frame (HV-LC / HV-HC / LV-LC / LV-HC) appears in
both paths so the human can orient even before scoring lands. The F8
3-component cost (artefact §4 "must remain diagnosable") is exposed in
both the hover tooltip and the raw-data table. T-1929 (live sliders +
commit) is the natural follow-up; T-1930 extends /arcs/<id> with
arc-level BVP, coherence warnings, and proposed_scoped_drivers approve
buttons.

**Evidence:**
- `web/blueprints/bvp.py` (180 LOC) — F8 + Q2 math inlined locally
  (duplicates `lib/bvp.sh:_bvp_python_engine` ~30 LOC, formulas pinned in
  shell tests; unit-checked at probe time: BVP_norm=1.0 on 5/5/5/5,
  composite=8.0 on br=10/tier=5/effort=5, T-shirt L=6.0, absent→None)
- `web/templates/bvp.html` (160 LOC) — pico + d3 v7 (vendored, matches
  `fabric_explorer.html` stack), separate empty/populated branches
- Registered in `web/blueprints/__init__.py:40,49`; nav entry under
  "Work" group in `web/shared.py:105` (alongside Tasks/Arcs/Inception)
- 5/5 Playwright tests pass — heading, 4 quadrant tokens, weights
  section, cost-composite formula reference, nav-under-Work-group
- Live probe (`.context/arcs/value-prioritisation.yaml` temporarily
  scored): scatter div + d3 script + JSON data block + arc-006 in
  data table — all 4 PASS, reverted to clean state

**Human [REVIEW] note (R4 mitigation, prerequisite):** The 5-task
spot-check requires scored tasks. Right now zero tasks carry confirmed
`bvp_scores:`. The scoring pathway lands via T-1922 (estimator,
soft-blocked on T-1921 [REVIEW]) → T-1924 (`fw bvp confirm`, already
shipped). Until at least 5 tasks are scored, the [REVIEW] AC's
prerequisite is unsatisfied. Three paths forward for the human:
  1. Defer [REVIEW] until ≥5 tasks scored (recommended — that's R4's
     intended state).
  2. Manually score 5 tasks now via `fw bvp confirm T-XXX --i-am-human`
     (each requires per-driver scores 0-5 and ≥30-char rationale).
  3. Spot-check the arc-only data (arc-006 will appear once
     `fw bvp confirm` reaches arc YAML — currently agent-CLI only for
     tasks).

## Decisions

### 2026-05-19 — Graph stack: d3 v7 (not Plotly or Cytoscape)

**Choice:** d3 v7 for the scatter rendering.

**Alternatives considered:**
- Plotly — not vendored; would add a new JS dependency tree.
- Cytoscape — used in fabric (graph topology, compound nodes); overkill
  for a flat scatter and has known compound-node issues at scale
  (L-cytoscape-cose-compounds in MEMORY.md).
- d3 v7 — already vendored at `web/static/d3.v7.min.js`, already used by
  `web/templates/fabric_explorer.html`. Zero new dependencies.

**Rationale:** AC says "match the codebase's existing graph stack."
d3 is the existing stack for scatter-style rendering (Cytoscape is
reserved for topology). Reuse beats novelty.

### 2026-05-19 — Math duplication (lib/bvp.sh ↔ web/blueprints/bvp.py)

**Choice:** Inline F8/Q2 formulas in the blueprint rather than
subprocess `fw bvp` or extract a shared module.

**Why not subprocess:** Adds latency to every page load, and `fw bvp`
emits tabular text — parsing would be brittle. JSON output mode would
need adding to `fw bvp` first.

**Why not extract shared module:** Would touch `lib/bvp.sh`'s tested
core; broader scope than T-1928 needs.

**Trade-off accepted:** ~30 LOC of formula duplication. Math is short
(`raw = sum(score*weight)`, `cost = 0.6br + 0.3t + 0.1e`), documented in
040-ValueDrivers.md, and pinned in shell tests. Probe-time unit check
confirms both implementations agree.

**Follow-up if duplication grows:** Extract `lib/bvp_engine.py` and
re-import from both sides — file as a separate task if T-1929 needs
the same math.

## Updates

### 2026-05-19T15:27:49Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.4)

- **Scan ID:** R-a6b81947
- **Timestamp:** 2026-05-19T16:52:59Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `web/blueprints/bvp.py` exists; registered via `web/blueprints/__init__.py:register_blueprints` (centralised pattern per T-431/A2; `web/app.py:147` calls the centraliser, doesn't import individual blu
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/app.py in: `web/blueprints/bvp.py` exists; registered via `web/blueprints/__init__.py:register_blueprints` (centralised pattern per T-431/A2; `web/app.py:147` ca`
- **AC#3 (Agent)** — Scatter plot shows current tasks and arcs in their quadrant positions — uses **d3 v7** (already vendored at `web/static/d3.v7.min.js`, matches `web/templates/fabric_explorer.html` which is the codebas
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/fabric_explorer.html in: Scatter plot shows current tasks and arcs in their quadrant positions — uses **d3 v7** (already vendored at `web/static/d3.v7.min.js`, matches `web/te`

### 2026-05-19T16:52:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
