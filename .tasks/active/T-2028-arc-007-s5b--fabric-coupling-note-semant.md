---
id: T-2028
name: "arc-007 S5b — fabric coupling-note semantic colour (categorical-fixed)"
description: >
  arc-007 S5b — convert the one genuinely-semantic colour on the Fabric pages
  (fabric_detail coupling-note #e53e3e → --wt-danger). Per the human decision,
  the 8-type categorical colour map and the graph's dark canvas stay fixed
  (palette-independent identity encoding). Final T-1994 colour slice.

status: work-completed
workflow_type: build
owner: human
horizon: now
arc_id: watchtower-redesign
tags: [arc:watchtower-redesign, ui, watchtower, fabric]
components: [tests/playwright/test_fabric_coupling_token.py, 
      tests/unit/test_fabric_coupling_token.py, web/templates/fabric_detail.html]
related_tasks: [T-1994, T-1987, T-2027, T-2023]
created: 2026-05-24T12:00:21Z
last_update: '2026-05-28T22:54:11Z'
date_finished: 2026-05-26T06:50:52Z
cost_estimate_proposed:
  - ts: '2026-05-24T12:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-24T12:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2028: arc-007 S5b — fabric coupling-note semantic colour (categorical-fixed)

## Context

Final colour slice of T-1994 (Fabric + Arcs redesign). The Fabric pages carry an
8-type **categorical** colour map (script/route/template/data/hook/config/fragment/else
— distinct hue + light text each, on fabric.html + fabric_detail.html) and a dark-canvas
cytoscape graph (fabric_explorer.html) with its own node/edge colour system. These are
*identity* encoding, not *status* — so they do not map onto the 4 semantic `--wt-*`
tokens.

The human decided (2026-05-24, AskUserQuestion): **keep the categorical type-colours and
the graph fixed and palette-independent** (current dark-chip + light-text is already
legible on every palette), and convert only the one genuinely-semantic site:
`fabric_detail.html:204` coupling-note (`color: #e53e3e`, red warning text under
"Coupling Warning") → `var(--wt-danger)`.

This closes the colour-tokenisation pass of the arc-007 redesign (cockpit, approvals,
arcs, fabric all addressed). Remaining arc-007 work (S3b cockpit density; whether the
graph should ever follow the palette) is design-judgment, tracked separately.

## Acceptance Criteria

### Agent
- [x] fabric_detail.html coupling-note uses `var(--wt-danger)`; `#e53e3e` no longer present
- [x] Categorical type-colour map UNCHANGED on fabric.html + fabric_detail.html (8 type hues preserved — proves the decision was honoured, not over-converted)
- [x] fabric_detail.html still compiles (jinja `get_template`)
- [x] Unit test `tests/unit/test_fabric_coupling_token.py` passes (coupling-note token present + #e53e3e gone + type-map intact)
- [x] Playwright test `tests/playwright/test_fabric_coupling_token.py` passes (`--wt-danger` re-themes paper↔console on /fabric — satisfies T-1575)

### Human
- [ ] [REVIEW] Coupling-warning note reads as a danger/warning colour on the Fabric detail page across palettes
  **Steps:**
  1. Open a Fabric component detail page that has a coupling note, e.g. `bin/fw watchtower url` + `/fabric` → pick a component flagged with a "Coupling Warning"
  2. Cycle palettes at `/settings/appearance` (esp. the light `bone`/`paper` and dark `console`)
  **Expected:** the coupling-warning text reads as a danger/alert colour (red family) and stays legible on every palette background
  **If not:** note the palette; `--wt-danger` may need a contrast tweak on that palette (foundation-token issue, not this template)

## Verification

out=$(cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/unit/test_fabric_coupling_token.py -q 2>&1); echo "$out" | tail -3; echo "$out" | grep -q "passed"
python3 -c "import sys; sys.path.insert(0,'.'); from web.app import app; app.jinja_env.get_template('fabric_detail.html'); print('compiles')"

## Evolution

### 2026-05-24 — categorical-vs-semantic colour boundary established
- **What changed:** Surfaced (and the human confirmed) that the Fabric pages' colour usage is *categorical identity* encoding (component type, graph node/edge kind), not the *semantic status* (success/warn/danger/info) the `--wt-*` token system models. The "honour selected preset" rule applies to semantic colours; categorical/identity colours are intentionally palette-independent.
- **Plan impact:** T-1994 is NOT "tokenise every fabric hex" — it's "tokenise the one semantic site, leave categorical fixed". The earlier assumption that fabric was a large mechanical slice was wrong; it's one hex + a design boundary.
- **Triggered:** Recorded the reusable convention as a framework decision (categorical ≠ semantic for the palette system). fabric_explorer graph palette-following deferred as design-judgment; S3b cockpit density still pending.

## Decisions

### 2026-05-24 — categorical/identity colours stay palette-independent; only semantic follows the palette
- **Chose:** Keep the 8-type fabric colour map and the cytoscape graph's dark canvas fixed; convert only the semantic coupling-note (`#e53e3e` → `--wt-danger`).
- **Why:** Human decision via AskUserQuestion. Categorical colours encode *identity* ("this is a route / a hook"), not *status* — they carry meaning by being distinct and stable, not by matching the mood of the palette. Standard design-system practice separates categorical from semantic colour. Lowest cost; avoids inventing a 40-definition `--wt-type-*` set that would add interpretive load for no semantic gain.
- **Rejected:** (B) per-palette `--wt-type-*` tokens (8 types × 5 palettes ≈ 40 defs + hue design) — large, design-heavy, no semantic payoff; (C) collapse types onto existing semantic tokens — destroys category distinction.

## Recommendation

**Recommendation:** GO
**Rationale:** Single-site semantic conversion authorised by the human; categorical map preserved (gated by a test that fails if the type-hues are touched). Closes the arc-007 colour-tokenisation pass.
**Evidence:**
- fabric_detail coupling-note `#e53e3e` → `var(--wt-danger)`; type-map (8 hues) intact
- Unit test pins both the conversion and the categorical-fixed boundary; template compiles

## Updates

### 2026-05-24T12:00:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c44d7305
- **Timestamp:** 2026-05-26T06:50:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-26T06:50:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
