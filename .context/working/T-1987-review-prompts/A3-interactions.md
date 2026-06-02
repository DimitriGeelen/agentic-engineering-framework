# T-1987 review-A3 — interactions architecture reviewer

You are an isolated TermLink-dispatched worker reviewing the cross-cutting interactions dimension of arc-007 (watchtower-redesign) inception T-1987. Parent runs from `/opt/999-Agentic-Engineering-Framework`. You produce ONE review artifact and post a fw bus summary. You do NOT transition T-1987 or any child task.

## Setup (run first, in order)

1. Confirm `pwd` is `/opt/999-Agentic-Engineering-Framework`.
2. Read inception body and research artifact (paths in T-1987).
3. Read design mockups of interactions:
   - `docs/design/watchtower-redesign-2026-05-13/project/direction-calm.jsx` (⌘K palette + shortcuts overlay + side-panel docking)
   - `docs/design/watchtower-redesign-2026-05-13/project/direction-cockpit.jsx` (dense tasks list + bulk actions)
   - `docs/design/watchtower-redesign-2026-05-13/project/direction-editorial.jsx` (saved-view chips)
4. Read current Watchtower JS surface: `web/static/js/`, `web/templates/base.html`, any HTMX usage in `web/templates/`. Identify any existing keyboard handlers, modal patterns, palette-like code.

## Your dimension: cross-cutting interactions (S6 / T-1993)

You are reviewing **S6 (T-1993)** scope plus S4 (T-1992) interaction patterns. Specifically: ⌘K command palette, `?`-shortcuts overlay, bulk-action contract, side-panel docking, inline edit, drag-to-reorder, filter chips, live activity ticker.

## Deliverable

Write to `docs/reports/T-1987-reviews/A3-interactions-architecture.md`.

Required sections:

1. **⌘K palette — concrete architecture.**
   - What entities are searchable? List them concretely (tasks, arcs, learnings, decisions, files, pages, fw commands, watchers, ...).
   - Index source: file-system scan at request? Pre-built JSON? SQLite FTS? Trade-offs and pick one.
   - Fuzzy match: in-browser (fuse.js, fzy.js, custom)? Bundle size impact? Server-roundtrip alternative?
   - Keyboard contract: ⌘K to open, Escape to close, Tab/arrows to navigate, Enter to select. Cite any conflicts with browser defaults or HTMX.
   - Recency: where does the "recent-first" data live? Per-user (link to A2)? Session-only?

2. **`?`-shortcuts overlay — registry pattern.**
   - Static (hard-coded list)? Dynamic (data-shortcut attribute on every interactive element, scanned on `?`)?
   - Per-page contextual shortcuts vs global?
   - Accessibility: screen-reader behaviour for the overlay?

3. **Side-panel docking — state machine.**
   - States: closed, right (default), left, bottom, fullscreen.
   - Persist dock preference per-user (link to A2)? Or per-session?
   - Animation: CSS transitions or JS-driven? What blocks during animation?
   - Click-row → open: HTMX-loaded partial or full client render? Trade-off?
   - Keyboard: Escape closes; what else?

4. **Inline edit contract.**
   - Which cells: status, owner, horizon, tags, title?
   - Activation: click, double-click, F2?
   - Persistence: optimistic (write to DOM then POST) vs pessimistic (POST first, then update)?
   - Validation: client-side or round-trip to server?
   - Failure UX: revert + toast? Banner? Inline error?

5. **Drag-to-reorder on board.**
   - Library: Sortable.js, dragula, native HTML5 drag, custom?
   - Bundle-size and accessibility trade-offs.
   - Persistence: what field on the task gets updated? Order index? Or just status (column)?

6. **Bulk-action contract.**
   - Selection model: shift-click range? cmd-click toggle? select-all checkbox?
   - Floating action bar position: bottom-center? bottom-right?
   - Visible actions vs overflow menu?
   - Bulk API surface: one endpoint per action vs batch endpoint?

7. **Live activity ticker.**
   - Source: SSE (Flask `Response(generator, mimetype='text/event-stream')`), short-poll, long-poll, websocket?
   - Cost analysis: idle browser + 10 watchers + activity every 30s.
   - Subtle animations: where do they live, and what triggers them (filesystem watcher? git hook?).
   - Quiet mode toggle (link to A2 — appearance preference?).

8. **Filter / saved-view chips.**
   - State: URL query params (shareable) or per-user saved views (link to A2)?
   - "All / mine / starred / recent" pre-baked vs user-created?
   - Multi-select facets vs single chip-at-a-time?

9. **HTMX coexistence** — Inline edit + partial swaps + ⌘K-loaded partial all need to play nice. Is there a conflict (e.g., ⌘K opens a partial that contains nested HTMX hx-* attributes)? List concrete coexistence rules.

10. **Recommendation** — KEEP / ADJUST / CHALLENGE the inception's S6 scope. If you think S6 should be split (e.g., ⌘K is its own slice), say so.

## Constraints

- **No source edits** — you produce analysis only.
- **Do not edit T-1987 or T-1988-T-1994 task bodies.**
- **Path isolation**: stay in `/opt/999-Agentic-Engineering-Framework`.
- **Banned tools**: TaskCreate etc.

## Reporting

1. Commit: `git add docs/reports/T-1987-reviews/A3-interactions-architecture.md && bin/fw git commit -m "T-1987: review-A3 interactions architecture"`.
2. Post: `bin/fw bus post --task T-1987 --agent reviewer-A3-interactions --summary "..." --blob docs/reports/T-1987-reviews/A3-interactions-architecture.md`
3. Final ≤ 5 lines: DONE | path | verdict | ⌘K index source picked | one biggest risk

Begin.
