---
id: T-2027
name: "arc-007 S5a — arcs pages semantic colour tokenisation"
description: >
  arc-007 S5a — convert the hardcoded semantic status colours on the Arcs section
  templates (arcs_index, arc_detail, arc_close, arc_review) to --wt-* foundation
  tokens so they honour the live /settings/appearance palette. First T-1994 slice.

status: started-work
workflow_type: build
owner: agent
horizon: now
arc_id: watchtower-redesign
tags: [arc:watchtower-redesign, ui, watchtower, arcs]
components: []
related_tasks: [T-1994, T-1987, T-2023, T-2025, T-2026]
created: 2026-05-24T11:49:08Z
last_update: 2026-05-24T11:49:08Z
date_finished: null
---

# T-2027: arc-007 S5a — arcs pages semantic colour tokenisation

## Context

First slice of T-1994 (Fabric + Arcs redesign). The Arcs section templates carry
hardcoded semantic status hexes and `var(--pico-<semantic>, #hex)` fallbacks that do
not follow the live `/settings/appearance` palette. Per the 2026-05-24 "honour the
selected preset" decision (and the convention proven in S3a/S3a2/S3c/S3c2 —
T-2023/T-2024/T-2025/T-2026), every **semantic** status colour (success/warn/danger)
maps to a `--wt-*` foundation token; **neutral** pico vars (`--pico-secondary`,
`--pico-card-sectioning-background-color`, `--pico-muted-*`) stay as-is, matching the
shipped siblings (which retain neutral pico vars but converted every semantic one).

Scope = 9 sites across 4 files:
- `arcs_index.html`: `.badge-warn #c97a00`→warn; `.badge-ok #1e6a2a`→success (×2); closed-column border `var(--pico-form-element-valid-active-border-color, #2e7d32)`→success
- `arc_detail.html`: `.badge-ok #1e6a2a`→success; `.badge-warn #c97a00`→warn
- `arc_close.html`: error banner + `.verdict-NO-GO` `var(--pico-del-color, #c62828)`→danger (×2)
- `arc_review.html`: `.verdict-NO-GO` `var(--pico-del-color, #c62828)`→danger

Restyle-only. `arc_close`/`arc_review` are sovereignty surfaces — no closure logic,
buttons, or decision flow touched, only the verdict/banner background colour (same
boundary applied to the approvals restyle in T-2025/T-2026).

## Acceptance Criteria

### Agent
- [x] `.badge-ok`/`.badge-warn` in arcs_index.html + arc_detail.html use `var(--wt-success)`/`var(--wt-warn)`; no `#1e6a2a`/`#c97a00` remain
- [x] arcs_index.html closed-column border uses `var(--wt-success)`; no `#2e7d32` remains
- [x] arc_close.html + arc_review.html `.verdict-NO-GO` (and arc_close error banner) use `var(--wt-danger)`; no `#c62828` remains
- [x] Neutral pico vars (`--pico-secondary`, `--pico-card-sectioning-background-color`) are preserved (not over-converted)
- [x] All four templates still compile (jinja `get_template`)
- [x] Unit test `tests/unit/test_arcs_pages_tokens.py` passes (token presence + no residual semantic hexes)
- [x] Playwright test `tests/playwright/test_arcs_pages_tokens.py` passes (a badge re-themes paper↔console)

### Human
- [ ] [REVIEW] Arc badges (OK/WARN) and the NO-GO verdict pill stay legible across all five palettes
  **Steps:**
  1. Open the Watchtower `/arcs` page (base from `bin/fw watchtower url`)
  2. Cycle each palette at `/settings/appearance` (linen, stone, paper, bone, console)
  3. On `/arcs` check the OK (green) and WARN (amber) badges; open an arc with a NO-GO anchor recommendation and check the red NO-GO verdict
  **Expected:** text stays readable on every palette; green/amber/red read as success/warn/danger, none washes out (esp. amber on the light `bone`/`paper` palettes)
  **If not:** note which palette + badge; a dark-text-on-light-amber tweak (the `#1a1a1a` DEFER precedent from T-2024) may be needed

## Verification

out=$(cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/unit/test_arcs_pages_tokens.py -q 2>&1); echo "$out" | tail -3; echo "$out" | grep -q "passed"
python3 -c "import sys; sys.path.insert(0,'.'); from web.app import app; [app.jinja_env.get_template(t) for t in ('arcs_index.html','arc_detail.html','arc_close.html','arc_review.html')]; print('templates compile')"

## Evolution

### 2026-05-24 — S5a scope confirmed from sibling convention
- **What changed:** Confirmed (by grepping shipped siblings) that the established rule is "convert semantic pico vars + bare semantic hexes to `--wt-*`, keep neutral pico vars" — siblings had zero residual `--pico-del/valid/*` but retained `--pico-muted/card/secondary`. This pinned which of the arcs `var(--pico-*, #hex)` cases are in scope (the `del`/`valid` ones) vs out (`secondary`, `card-sectioning`).
- **Plan impact:** None — clarified scope before editing rather than after.
- **Triggered:** Fabric cluster (fabric.html / fabric_detail.html / fabric_explorer.html — 16/15/116 hexes) deferred to subsequent T-1994 slices; fabric_explorer is a cytoscape graph (28 unique) needing its own slice.

## Decisions

### 2026-05-24 — semantic-only conversion, neutral pico vars retained
- **Chose:** Convert only semantic status colours (success/warn/danger) to `--wt-*`; leave neutral pico vars (`--pico-secondary` draft, `--pico-card-sectioning-background-color` draft badge) untouched.
- **Why:** Matches the shipped siblings exactly (cockpit/approvals kept neutral pico vars, converted all semantic ones). Over-converting neutrals would diverge from the established convention and re-tint structural chrome.
- **Rejected:** Convert every `var(--pico-*)` to `--wt-*` — would re-tint neutral chrome and break consistency with S3 siblings.

### 2026-05-24 — arc_close/arc_review treated as restyle-only sovereignty surfaces
- **Chose:** Touch only the verdict/banner background colour on the closure/review templates.
- **Why:** Same boundary as the approvals restyle (T-2025/T-2026) — a sovereignty surface may be re-themed but its decision logic/buttons must not change.
- **Rejected:** Any markup/button/closure-flow change — out of scope, sovereignty-reserved.

## Recommendation

**Recommendation:** GO
**Rationale:** Mechanical semantic-colour tokenisation following the proven S3 pattern; restyle-only on the Arcs section; neutral pico vars preserved per sibling convention. Agent ACs cover token presence, no-residual-hex, compile, and per-palette re-theme (unit + Playwright). The one Human [REVIEW] is the cross-palette legibility judgment (esp. amber on light palettes).
**Evidence:**
- 9 semantic sites across arcs_index/arc_detail/arc_close/arc_review → `--wt-success/warn/danger`
- Unit + Playwright tests green; templates compile
- Neutral pico vars retained (no over-conversion)

## Updates

### 2026-05-24T11:49:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2027-arc-007-s5a--arcs-pages-semantic-colour-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0e616017
- **Timestamp:** 2026-05-24T11:52:24Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
