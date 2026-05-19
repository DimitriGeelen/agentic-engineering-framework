---
id: T-1930
name: "BVP T-NEW-13: Watchtower /arcs/<id> extensions — arc-level BVP, coherence warnings, proposed_scoped_drivers render with approve buttons"
description: >
  Extend existing /arcs/<id> page with arc-level BVP near top, per-driver coherence warnings inline, proposed_scoped_drivers rendered with timestamps and approve action buttons (calls fw arc approve-driver via --from-watchtower).

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [bvp, build, slice-13, web, render-surface]
components: [web/blueprints/arcs.py, web/templates/arc_detail.html]
related_tasks: [T-1915, T-1916, T-1926, T-1927]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-19T07:00:00Z
date_finished: null
---

# T-1930: BVP T-NEW-13 — `/arcs/<id>` extensions

## Context

Brings BVP signals into the existing arc detail page. Render-surface, [REVIEW] Human AC required.

**Source:** Handoff §7 T-NEW-13; artefact §6 row 14; §4 D3 (coherence), D7-reframe (`fw arc show-suggestions` discoverable).

## Acceptance Criteria

### Agent
- [ ] `/arcs/<id>` shows arc-level BVP near the top (numeric + per-driver breakdown collapsible)
- [ ] T-1927 coherence WARNs surface inline with the arc's metadata (per-driver, not aggregated)
- [ ] `proposed_scoped_drivers:` entries render with their event timestamps (D7) — newest first
- [ ] Each proposed driver has an Approve button that POSTs to a route shelling `fw arc approve-driver <arc> "<name>" --from-watchtower`
- [ ] An "Approve none" form is also present, requiring justification ≥30 chars, posting `--none --justification "..." --from-watchtower`
- [ ] After approve/none, page reloads to show the updated `scoped_drivers:` and `status: in-progress`

### Human
- [ ] [REVIEW] Approval flow is unambiguous and the page reads cleanly without competing CTAs
  **Steps:**
  1. Open `/arcs/value-prioritisation` (arc-006 if/when it has proposed drivers)
  2. Verify BVP display, coherence area (may be empty), proposed-drivers section
  3. Try approving one (or `--none`); verify the arc flips to in-progress and reload reflects it
  **Expected:** Single clear approve action per proposal; no surprise state mutations
  **If not:** Note the specific UX issue

## Verification

grep -q "approve-driver\|approve_driver" web/blueprints/arcs.py
grep -q "scoped_drivers\|proposed_scoped" web/blueprints/arcs.py

## Decisions

## Updates
