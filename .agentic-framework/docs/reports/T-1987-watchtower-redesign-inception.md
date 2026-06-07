# T-1987 — Watchtower redesign inception (arc-007)

**Status:** companion research artifact (C-001). Updated as the arc progresses.
**Anchor task:** [T-1987](../tasks/T-1987-watchtower-redesign--apply-claude-design.md)
**Arc:** [arc-007 watchtower-redesign](../../.context/arcs/watchtower-redesign.yaml)
**Source bundle:** [docs/design/watchtower-redesign-2026-05-13/](../design/watchtower-redesign-2026-05-13/)

## Source

A Claude Design exploration (2026-05-13) was commissioned by the human with the brief *"i want to greatly improve the visual aesthetic, the user interactions, navigation structure and consistent display of this tool."*

The handoff bundle arrived as a gzipped tar (200 KB compressed, 488 KB extracted) containing:

| Path | Role |
|------|------|
| `README.md` | Claude Design's coding-agent handoff instructions ("read the chat first, ask before implementing if ambiguous") |
| `chats/chat1.md` | Full design dialogue (load-bearing — direction lock-in lives here) |
| `project/index.html` | Single-page React canvas, pulls 10 JSX modules |
| `project/foundations.jsx` | 6 type pairings + 6 palettes × light+dark token sets |
| `project/nav-patterns.jsx` | 3 navigation patterns |
| `project/direction-calm.jsx` | Direction A — stone/olive, Inter, calm UX |
| `project/direction-editorial.jsx` | Direction B — linen/terracotta, Newsreader serif, editorial cockpit |
| `project/direction-cockpit.jsx` | Direction C — near-black/neon, IBM Plex, monitoring-style console |
| `project/appearance-settings.jsx` | The pivot — runtime-pickable Settings → Appearance screen |
| `project/live-preview.jsx` | Sticky live cockpit preview that re-themes from selection |
| `project/shared.jsx`, `tweaks-panel.jsx`, `design-canvas.jsx`, `app.jsx` | Canvas chrome and helpers |

## Dialogue Log

Verbatim from `chats/chat1.md`, structured for traceability.

### Phase 1 — Brief (1 exchange)

**Human:** *"i want to greatly improve the visual aesthetic, the user interactions, navigation structure and consistent display of this tool."*

**Designer:** Inspected the codebase, classified Watchtower as "a dense, internal control-plane app for an agentic engineering framework," then issued focused scoping questions before designing anything.

### Phase 2 — Scoping (answered all-in-one by human)

| Question | Answer |
|----------|--------|
| Deliverable | Explore a few options |
| Aesthetic | Explore a few options |
| Theme priority | Both equally — show both |
| Density | Compact — maximize info per screen, small type, tight rows |
| Nav structure | Pinned/favorited pages · Breadcrumbs everywhere · Top-bar primary + contextual sub-nav per section |
| Priority pages | Approvals queue · Tasks (board + list) · Cockpit/Dashboard · Fabric/Architecture/Arcs · Settings/Config |
| Ambient strip | Decide for me |
| Color system | Asked for visual examples |
| Typography | Asked for visual examples |
| Interactions | Inline edit · Bulk actions · Keyboard shortcuts overlay (?) · Drag-to-reorder on board · Side-panel detail · Filter/saved-view chips · Live activity feed · Inline approve/reject · Command palette (⌘K) · Side panel moveable to both sides or bottom |
| Variations | Three (Calm / Editorial / Cockpit) |
| Tweaks | A few essentials (theme, accent, density) |
| Pain points | **Menu navigation** |

### Phase 3 — Three directions shipped

The designer built the canvas with foundations (6 type pairings + 6 palettes) + 3 nav patterns + 3 directions × {Cockpit, Tasks Board, Tasks Side-Panel, Approvals, ⌘K Palette, Shortcuts Overlay}. Verifier agent passed clean.

**Designer:** *"To pick a direction: tell me which palette + type + nav you want, and I'll consolidate into one polished, deeper spec…"*

### Phase 4 — The pivot (load-bearing)

**Human:** *"idea can the styles, colors, navigation pattern be selectable?"*

The designer immediately reshaped: foundation cards became clickable + a parameterized live preview cockpit + a new `Settings → Appearance` screen was added at the top of the canvas. Then a row of **six one-click presets** was added (Calm · Editorial · Console · Paper · Bone · Midnight), each with its own preset of font + palette + nav + mode + density.

This is the implementation target. The "three directions" became three of the six presets; the system is now an Appearance picker, not a curated visual identity.

### Phase 5 — Discoverability friction

**Human:** *"why am i not seeing the preview anymore"* / *"it not rendering"*

Verifier confirmed both previews were rendering — the issue was zoom level. Designer pivoted the live preview to a **sticky bar at the top of the Appearance screen** so it stays visible regardless of zoom or scroll. This is a UX learning to honor in S1: the preview must be discoverable without depending on the user finding the right scroll position.

### Phase 6 — Chat ends without a direction lock-in

The chat ends mid-iteration. The handoff bundle was exported at this point. **No single direction was committed.** The human's intent is the Appearance screen, not Calm-vs-Editorial-vs-Cockpit.

## Framework integration decisions (2026-05-22 session)

The agent ingested the bundle and posed two questions to the human:

### Q1 — Arc scoping

**Options offered:** (1) full-scope inception arc, (2) foundation-only (S0+S1), (3) single-direction build task, (4) capture and defer.

**Human chose:** **(1) full-scope inception arc.**

Rationale: the design pivoted to a runtime-pickable system — committing to one direction loses the load-bearing aspect, and capturing without an arc would lose momentum on a "complete arc" the human explicitly framed.

### Q2 — Persistence

**Options offered:** (1) per-user YAML in `.context/user-preferences/<who>.yaml`, (2) localStorage only, (3) cookie + per-user YAML hybrid.

**Human chose:** **(1) per-user YAML.**

Rationale: reuses the framework's per-user pattern, survives session restart, no new dependency. The mockup used localStorage, but localStorage is per-browser-profile — for a tool used across machines via Watchtower's HTTP surface, per-user filesystem persistence is the right durability tier.

## Slice rationale

The arc decomposes into 7 build slices. Each slice is filed as a captured/later child task with `arc_id: watchtower-redesign`. Dependency chain shown below.

```
S0 (T-1991) Foundation tokens          ──┐
                                          ├─► S2 (T-1989) Nav restructure
S1 (T-1988) /settings/appearance       ──┤              │
                                          │              ▼
                                          ├─► S3 (T-1990) Cockpit + Approvals
                                          │
                                          ├─► S4 (T-1992) Tasks board + list
                                          │              │
                                          │              ▼
                                          └─► S6 (T-1993) Interactions (⌘K · ?-overlay · bulk · live)
                                          │
                                          └─► S5 (T-1994) Fabric + Arcs
```

| Slice | Task | Why this slice exists | Risk |
|-------|------|----------------------|------|
| S0 | T-1991 | Token layer must land before any consumer can use it. Also the spike for A3/A6/A7 (CSS-var swap perf, Cytoscape compat, Pico coexistence). | Low — purely additive CSS. |
| S1 | T-1988 | The Appearance screen is the load-bearing deliverable of the arc. Without it, the foundation tokens have no human-facing surface. | Medium — new route + persistence layer + live preview. |
| S2 | T-1989 | Nav is the human's stated pain point. Must be selectable from Appearance (touches every page header). | Medium — touches every layout. |
| S3 | T-1990 | Cockpit + Approvals are the top two priority pages per chat. Ship them first as a coherence test of S0+S1+S2. | Low per-page but high blast radius. |
| S4 | T-1992 | Tasks is the highest-interaction surface (side panel, drag, inline edit). Larger than any other page slice. | Medium — Sortable.js integration risk, inline-edit contract. |
| S5 | T-1994 | Fabric uses Cytoscape; Arcs uses custom templates. Smaller than S4 but depends on S0's Cytoscape-var validation. | Low if A6 verified in S0. |
| S6 | T-1993 | ⌘K palette and ?-overlay are cross-cutting — they observe S0 tokens and S2 nav layout, and S4 board/list patterns inform their UX. Last because dependencies must settle. | Medium — first time the framework has a global keyboard layer. |

## Open questions for S0

These must be answered (spike-tested) at the start of S0 before downstream slices commit:

1. **A3 — CSS-var swap performance:** Toggle palette tokens on `:root` and measure paint cost across `/cockpit`, `/tasks`, `/approvals`. Acceptable threshold: no visible flash, no layout thrash within 100 ms.
2. **A6 — Cytoscape compatibility:** Set node `background-color` to `var(--wt-accent)` instead of hex literal. Confirm hot-swap on `:root` repaints the graph without restarting layout.
3. **A7 — PicoCSS coexistence:** Import `foundations.css` on one untouched template; confirm Pico defaults still render correctly elsewhere. If conflicts, document the Pico class collisions for the eventual decommission task.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Cytoscape doesn't read CSS vars (A6 fails) | Low | Blocks S5 | S0 spike validates; fallback is computed style reads in cytoscape init |
| Preset count wrong (A4 fails — users want fewer/more) | Medium | Re-flow S1 | Ship 6 to start; collect human feedback in S1 review |
| 16-item Govern pain isn't navigation shape (A5 fails) | Medium | S2 doesn't solve user's actual issue | S2 includes a click-count measurement before/after |
| Pico removal becomes load-bearing for S2-S5 | Low | New decommission arc required | S0 verifies coexistence; document conflicts as we hit them |
| Sortable.js integration on board (S4) | Medium | S4 slips | Defer drag-reorder to follow-up task if needed; ship inline-edit + side panel first |
| Render-surface gate (T-1766) blocks every slice close | Certain | Every child needs `[REVIEW]` Human ACs | Already accounted for — each slice carries 1+ Human AC by design |

## Forward references

- Per-user YAML helper location candidate: `web/shared.py` — add `load_user_preferences(user)` + `save_user_preferences(user, prefs)`.
- Foundation token namespace: `--wt-*` to avoid collision with PicoCSS `--pico-*`.
- Preset persistence shape (proposed, refined in S1):
  ```yaml
  preset: console
  typography: plex
  palette: console
  accent_override: null
  nav_layout: sidebar
  density: compact
  theme_mode: dark
  custom: {}    # future power-user overrides
  ```

## Updates

<!-- Append below as the arc progresses. Each child task close should add an entry here citing slice + commit. -->

- **2026-05-22** — Inception filed (T-1987). Arc arc-007 created. Bundle persisted. 7 child slices pre-filed (T-1988–T-1994). Recommendation GO. Awaiting human decision via `fw task review T-1987`.
