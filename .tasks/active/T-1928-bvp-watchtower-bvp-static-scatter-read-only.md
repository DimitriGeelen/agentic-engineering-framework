---
id: T-1928
name: "BVP T-NEW-12a: Watchtower /bvp static scatter read-only (split parent T-NEW-12)"
description: >
  New Watchtower tab /bvp. Static quadrant scatter — arcs as larger dots, tasks as smaller, axes BVP_norm × cost. Read-only — no weight mutation yet (12b adds sliders). Render-surface, [REVIEW] Human AC required (T-1766 P-013).

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [bvp, build, slice-12a, web, render-surface]
components: [web/blueprints/bvp.py, web/templates/bvp.html, web/app.py]
related_tasks: [T-1915, T-1916, T-1919]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-19T07:00:00Z
date_finished: null
---

# T-1928: BVP T-NEW-12a — `/bvp` static scatter (read-only)

## Context

First split-child of T-NEW-12 (handoff `needs-split` because novel-mechanism: live weight sliders). This slice = static scatter only; T-1929 adds live sliders + commit.

**Source:** Handoff §7 T-NEW-12 (needs-split); artefact §6 row 12; §4 F8-mechanic (3-component cost MUST be diagnosable).

**Render-surface gate (T-1766 P-013):** any task touching web/templates or web/blueprints requires at least one `[REVIEW]` Human AC.

**R4 detection lands here** via the Human AC spot-check.

## Acceptance Criteria

### Agent
- [ ] `web/blueprints/bvp.py` exists; registered in `web/app.py`
- [ ] `/bvp` route returns HTTP 200 and renders the page without error
- [ ] Scatter plot shows current tasks and arcs in their quadrant positions (Plotly or Cytoscape — match the codebase's existing graph stack)
- [ ] Cost composite shown with 3 sub-components visible on hover (blast_radius, tier, effort)
- [ ] No client-side state mutation — page is purely read-only (no sliders yet)

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
grep -q "bvp" web/app.py
out=$(curl -sf "$(bin/fw watchtower url)/bvp" 2>&1); echo "$out" | grep -qi "quadrant\|scatter"

## Decisions

## Updates
