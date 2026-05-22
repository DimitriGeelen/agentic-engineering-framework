---
id: T-1987
name: "Watchtower redesign — apply Claude Design exploration: foundations + /settings/appearance
  + nav restructure + per-page redesigns + interactions"
description: >
  Inception: Watchtower redesign — apply Claude Design exploration: foundations +
  /settings/appearance + nav restructure + per-page redesigns + interactions

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
arc_id: watchtower-redesign
components: []
related_tasks: []
created: 2026-05-22T10:03:25Z
last_update: 2026-05-22T10:04:03Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-22T10:04:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-1987: Watchtower redesign — apply Claude Design exploration: foundations + /settings/appearance + nav restructure + per-page redesigns + interactions

## Problem Statement

Watchtower has grown organically across 30+ pages on PicoCSS plus inline styles, with four nav groups — the "Govern" group has 16 items, called out by the human as the primary navigation pain point. Color tokens are inconsistent (Material reds/greens layered over Pico vars), interactions are page-redirect heavy (no inline edit, no side-panel detail), and there is no command palette or keyboard-shortcut affordance.

The human commissioned a Claude Design exploration (2026-05-13). The chat surfaced three full design directions (Calm / Editorial / Cockpit), six palettes with full light+dark token sets, six type pairings, three navigation patterns, and a defined interaction inventory (⌘K palette, side-panel docking, inline edit, bulk actions, shortcuts overlay, drag-reorder, filter chips, live activity ticker). **The dialogue ended without a direction lock-in.** Instead, the human pivoted to a runtime-pickable model: a `/settings/appearance` screen with six one-click presets (Calm · Editorial · Console · Paper · Bone · Midnight) and a sticky live cockpit preview that re-themes instantly. That pivot is the implementation target — not any single direction.

**Why now:** the user explicitly framed this as "a complete arc" with the design bundle in hand, and 75+ unrelated tasks are queueing in `/approvals` — a coherent redesign helps human review throughput, which is currently the bottleneck on framework progress.

## Assumptions

Key assumptions, register via `fw assumption add "..." --task T-1987`:

- **A1** — Users want runtime aesthetic control, not a single locked theme. *Evidence:* chat pivot from "pick a direction" to Appearance screen with 6 presets.
- **A2** — Per-user YAML in `.context/user-preferences/<who>.yaml` is sufficient persistence; no multi-device sync required. *Evidence:* explicit human selection in 2026-05-22 AskUserQuestion (vs. cookie or hybrid).
- **A3** — CSS custom properties on `:root` can swap a full palette without layout thrash or visible repaint flash. *Untested* — verify in S0 (foundation tokens) before S1 runtime swapping.
- **A4** — Six presets cover the ergonomic space; additional foundation axes (typography, palette, accent override, nav layout, density) are power-user overrides. *Risk:* presets may be wrong-shaped; user feedback in S1 will tell us.
- **A5** — Three nav layouts (top-bar + sub-nav, persistent sidebar, slim icon rail + ⌘K-primary) solve the 16-item Govern menu pain. *Risk:* the pain may be page count, not navigation shape — measure in S2 by counting clicks to reach the 16 Govern pages before/after.
- **A6** — Cytoscape `/fabric` graph will accept CSS custom property values for node/edge colors. *Untested* — verify in S0 spike before S5 starts.
- **A7** — Existing PicoCSS imports across 30+ templates can coexist with foundation tokens during migration. *Untested* — confirm in S0 by overlaying foundation tokens on one untouched page.

## Exploration Plan

Pre-decision exploration is largely complete; this inception's role is to anchor the arc and stage the build slices.

1. **Bundle ingestion** ✓ — design bundle persisted at `docs/design/watchtower-redesign-2026-05-13/` (488 KB, 16 files including chat transcript and 10 JSX modules).
2. **Direction analysis** ✓ — chat transcript read; pivot to runtime-pickable Appearance screen identified as the real implementation target.
3. **Foundation inventory** ✓ — `foundations.jsx` enumerates 6 palettes × light+dark tokens, 6 type pairings, semantic status colors (success/warn/danger/info).
4. **Slice decomposition** ✓ — 7 build children pre-filed (T-1988 = S1 Appearance, T-1989 = S2 Nav, T-1990 = S3 Cockpit+Approvals, T-1991 = S0 Foundations, T-1992 = S4 Tasks, T-1993 = S6 Interactions, T-1994 = S5 Fabric+Arcs).
5. **Persistence mechanism** ✓ — per-user YAML at `.context/user-preferences/<who>.yaml` selected by human.
6. **Spike work deferred to S0** — verifying A3 (CSS var swap performance), A6 (Cytoscape var compatibility), A7 (Pico coexistence) is done in the S0 build task, not here.

## Technical Constraints

- **Browser-only target** — Watchtower runs in Chromium-class browsers; no native app concerns.
- **Server:** Flask + Werkzeug (dev), gunicorn migration parked in T-1611. No backend changes required for S0-S2.
- **PicoCSS coexistence** — 30+ templates import Pico vars; the migration must allow both stacks side-by-side during S0-S5. PicoCSS removal/replacement is a separate decommission task NOT in arc scope.
- **HTMX present** — partial-update fragments must respect theme tokens (CSS custom properties are inherited correctly; no extra work needed if scoped to `:root`).
- **Cytoscape `/fabric`** — node/edge colors set inline today; must be migrated to read CSS custom properties (S0 spike validates this).
- **Persistence is filesystem** — `.context/user-preferences/<who>.yaml`; concurrent writes resolved by per-user keying (`$USER` from session or basic-auth header).
- **No network at theme-pick** — runtime aesthetic must not require external CSS or font CDN-only resources (Inter, JetBrains Mono, IBM Plex, Geist, Manrope, Newsreader fonts are listed for `https://fonts.googleapis.com` — accept this dependency, or vendor the WOFF2s in S0).
- **Render-surface gate (T-1766)** — every child slice touches `web/templates/` or `web/static/` and so REQUIRES `[REVIEW]` Human ACs per CLAUDE.md §AC Classification.

## Scope Fence

**IN scope:**
- `web/static/css/foundations.css` and any other foundation token files
- A new `/settings/appearance` Flask route + template + blueprint
- Per-user YAML persistence helper in `web/shared.py`
- Replacement of the existing nav across all page headers
- Per-page redesigns: Cockpit (`/`), Approvals (`/approvals`), Tasks (`/tasks` board + list), Fabric (`/fabric`), Arcs (`/arcs`)
- Interactions: ⌘K command palette, `?`-shortcuts overlay, bulk-action contract, live activity ticker

**OUT of scope (this arc):**
- Backend Flask routing changes beyond the new `/settings/appearance` route
- CLI changes (no `fw appearance` verb proposed in S0-S6 — can be added later)
- Database layer (none exists; YAML is the store)
- Authentication / authorization model
- Mobile-specific responsive layouts (compact density assumes desktop)
- PicoCSS removal (separate decommission task post-arc)
- Documentation site rebuild (different surface)

**DEFERRED (catalogue, may become follow-up arc):**
- Per-page redesigns past Cockpit/Tasks/Approvals/Fabric/Arcs (Knowledge, Sessions, Metrics, Settings sub-pages, Terminal, BVP, Orchestrator panels — chat doesn't mock these)
- Drag-to-reorder on board specifically (in S4, but may slip if Sortable.js integration is bigger than expected)
- Multi-device sync of preferences (per-user YAML is single-host)

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Design bundle is persisted in the repo and accessible to future agents (✓ — `docs/design/watchtower-redesign-2026-05-13/`)
- Slice decomposition is reviewable as concrete tasks (✓ — T-1988…T-1994 pre-filed with arc_id)
- Persistence mechanism is committed (✓ — per-user YAML per 2026-05-22 human selection)
- Arc registered with §ACD headline_mechanic (✓ — arc-007 watchtower-redesign)
- S0 spike will validate the three untested assumptions (A3 CSS-var swap, A6 Cytoscape compat, A7 Pico coexistence) before downstream slices commit

**NO-GO if:**
- S0 spike disproves A3 (CSS variable swap causes unacceptable layout thrash)
- S0 spike disproves A6 (Cytoscape cannot read foundation tokens — would require library swap, blows scope)
- S0 spike disproves A7 (PicoCSS overrides break foundation tokens on >5 pages — would require Pico removal first, separate arc)

**DEFER if:**
- Human reviews this inception and prefers foundation-only scope (S0+S1 only) — re-scope without redoing the inception
- A higher-priority arc takes precedence (the 75+ pending review queue is the current bottleneck — this redesign helps unblock it but isn't itself blocking shipped work)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO

**Rationale:**

Human selected full-scope inception arc (vs foundation-only / single-direction / defer) in 2026-05-22 AskUserQuestion. Persistence chosen as per-user YAML. Source: Claude Design bundle 2026-05-13 (chat transcript shows user explored 3 directions then pivoted to a runtime-pickable Appearance settings screen with 6 presets). Arc arc-007 watchtower-redesign created with §ACD headline_mechanic. This inception anchors the arc and feeds 7 child build slices (S0 foundation tokens → S6 interactions). Evidence: docs/design/watchtower-redesign-2026-05-13/ (design bundle to be persisted) + chat shows interaction inventory + foundations.jsx specifies all 6 palettes with light+dark token sets.

**Evidence:**

- Design bundle persisted: `docs/design/watchtower-redesign-2026-05-13/` (488 KB, 16 files — README + chat transcript + 10 JSX modules)
- Chat transcript records human intent inventory: density=compact, nav=top-bar+sub-nav+pinned+breadcrumbs, priority pages = Approvals → Tasks → Cockpit → Fabric/Arcs → Settings, pain point = 16-item Govern menu
- Chat pivot evidence: the design started as "three directions" but ended as "Appearance settings screen with 6 presets + sticky live preview" after the human said *"can the styles, colors, navigation pattern be selectable?"*
- Foundation token enumeration: `foundations.jsx` lines 6-57 (6 type pairings) + lines 131-211 (6 palettes × light+dark)
- Arc registered: `.context/arcs/watchtower-redesign.yaml` (arc-007), headline_mechanic verified §ACD-compliant
- Child slices pre-filed: T-1991 (S0), T-1988 (S1), T-1989 (S2), T-1990 (S3), T-1992 (S4), T-1994 (S5), T-1993 (S6) — all `captured/later`, all carry `arc_id: watchtower-redesign`
- Research artifact: `docs/reports/T-1987-watchtower-redesign-inception.md` (companion document with dialogue log + per-direction comparison + slice rationale)

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-22T10:04:03Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
