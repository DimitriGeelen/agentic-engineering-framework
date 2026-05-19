---
id: T-1929
name: "BVP T-NEW-12b: Watchtower /bvp live weight sliders + commit (split parent T-NEW-12)"
description: >
  Adds live client-side weight sliders to /bvp — moving a slider previews re-rank without committing. Separate Commit button writes via fw bvp weight (T-1920) so audit-trail (D9) is preserved. Render-surface, [REVIEW] Human AC required.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [bvp, build, slice-12b, web, render-surface, novel-mechanism]
components: [web/blueprints/bvp.py, web/templates/bvp.html, web/static/bvp.js]
related_tasks: [T-1915, T-1916, T-1920, T-1928]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-19T07:00:00Z
date_finished: null
---

# T-1929: BVP T-NEW-12b — `/bvp` live sliders + commit

## Context

Second split-child of T-NEW-12. Depends on T-1928 (static scatter) + T-1920 (`fw bvp weight` mutating CLI for commit-through).

**Source:** Handoff §7 T-NEW-12; artefact §6 row 13; §4 D9 (reactive weights, audit-trail preserved).

## Acceptance Criteria

### Agent
- [ ] Weight sliders appear next to the scatter, one per driver (4 protected + free)
- [ ] Moving a slider triggers client-side recompute and re-renders the scatter (no server roundtrip per drag)
- [ ] Commit button posts to a server endpoint that shells `fw bvp weight --set Dn=N --rationale "..."` via the `--from-watchtower` path so the audit-trail entry is written
- [ ] Commit button refuses to post without a rationale text input (≥30 chars) — UI-side enforcement plus server-side §ACD
- [ ] Cancel/reset button restores sliders to current policy weights without committing

### Human
- [ ] [REVIEW] Slider responsiveness feels live (no janky lag on drag); commit flow is unambiguous
  **Steps:**
  1. Open `/bvp`; drag the D2 slider from 7 to 8
  2. Observe live re-ranking
  3. Enter rationale "Q2 reliability focus, validating BVP slider commit path"; click Commit
  4. Reload page; verify the new weight persisted
  **Expected:** Live drag is smooth; commit succeeds; weight history has the entry
  **If not:** Note specific UX/perf issue; file a follow-up

## Verification

grep -q "slider\|range" web/templates/bvp.html
test -f web/static/bvp.js || grep -q "fetch\|XMLHttpRequest" web/templates/bvp.html

## Decisions

## Updates
