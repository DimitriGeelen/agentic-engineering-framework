# T-1905 — `/arcs` kanban feature parity with `/tasks`

**Inception artifact (C-001).** Filed 2026-05-18 by agent; awaiting human inception-decide.

## Origin dialogue

After T-1904 shipped (4-column lifecycle kanban replacing T-1853 tabs + Arcs nav moved under Work), user followed up:

> *"ok would expect that teh arc show more staus field and taht these are editable to (samne as in tasks, we want to see them all and have fitering capability etc"*

Two demands, one umbrella:
1. **More fields on the card** — visible status metadata beyond the current id / name / task-count
2. **Inline editing parity** — same UX as `/tasks` (status flip, owner select, etc., via htmx POST-back)
3. **Filtering UI** — query controls
4. **See-all default** — single view of every arc, not slice-by-state

This document inventories `/tasks`'s features, maps each to the arc data model, and proposes 3-4 ordered build slices.

## Inventory: `/tasks` kanban card features (today)

Read from `web/templates/tasks.html:480-518` + `web/blueprints/tasks.py:492-595`:

| Feature | Card location | Endpoint | Notes |
|---------|---------------|----------|-------|
| Inline status select | header right | `POST /api/task/<id>/status` | dropdown over `enum_statuses` |
| Inline type select | meta row | `POST /api/task/<id>/type` | dropdown over `enum_types` |
| Inline horizon select | meta row | `POST /api/task/<id>/horizon` | now/next/later |
| Inline owner select | meta row | `POST /api/task/<id>/owner` | human/claude-code/codex |
| Inline name edit | card body | `POST /api/task/<id>/name` | click-to-edit JS |
| AC toggle | detail page | `POST /api/task/<id>/toggle-ac` | not on kanban card |
| Filter: status | querystring | `?status=` | dropdown |
| Filter: type | querystring | `?type=` | dropdown |
| Filter: component | querystring | `?component=` | from `_tags` |
| Filter: tag | querystring | `?tag=` | substring |
| Filter: arc | querystring | `?arc=` | T-1661 namespace |
| Filter: owner | querystring | `?owner=` | dropdown |
| Filter: horizon | querystring | `?horizon=` | dropdown |
| View mode | querystring | `?view=list` | flat-list alternative |
| Reusable widget | `inline_select` | `_partials/inline_select.html` | the macro |

## Mapping to arcs

Arc data model (from `lib/arc.sh` + `.context/arcs/*.yaml`):

| Arc field | Type | Inline-editable? | Reason |
|-----------|------|-----------------|--------|
| `id` (arc-NNN) | str (immutable) | **no** | D-Immutability axiom (T-1848) |
| `slug` | str | **no** | filename stem, immutable |
| `name` | str | **yes** | descriptive, can refine |
| `status` | enum {draft, in-progress, closed, abandoned} | **partial** | see Status transition matrix below |
| `decision` | str | **no — only on close** | closure-decision is the GO/NO-GO outcome; cannot edit post-hoc |
| `anchor_task` | T-NNNN ref | **maybe** | edit is rare but lawful |
| `headline_mechanic` | rich text | **no on card** (yes on detail) | too long for card; T-1626 closure gate scoping |
| `demo_evidence` | path/url | **no on card** (yes on detail) | same |
| `created` | timestamp | **no** | system-set |
| `closed_at` | timestamp | **no** | closure-only |
| `task_count` (computed) | int | **no** | derived |
| `stale` (computed) | bool | **no** | derived from constituent task commits, T-1855 |
| `focused` (cross-store) | bool | **yes** | `fw arc focus <slug>` toggle |

### Status transition matrix (which inline edits are lawful)

| From → To | Lawful inline? | Reason |
|-----------|----------------|--------|
| `draft` → `in-progress` | **yes** | promotion, agent-permissible |
| `in-progress` → `draft` | no | demotion is rare; require CLI ceremony |
| `in-progress` → `closed` | **NO — gated** | T-1671 §ACD axiom — closure is strategic judgment, not data edit. Routes to T-1902 `/arcs/<slug>/close` surface. |
| `in-progress` → `abandoned` | **yes via Watchtower** | abandonment is a decision but not a strategic ship; `fw arc abandon` CLI exists, equivalent web button reasonable |
| `closed` → anything | **no** | terminal state (immutable post-close) |
| `abandoned` → `in-progress` | **yes** | revival is legitimate |

**Critical design constraint:** the inline-status select on an arc card cannot offer `closed` as an option. Choosing "close" routes to the T-1902 close-review surface instead — single-click goes to a form, not a direct status flip. This is the structural inverse of `/tasks` where any status flip is direct.

## Proposed build slices (priority order)

### Slice 1 (build): card field enrichment — read-only
**T-1906 (proposed):** add to each arc-card: status badge (already implicit via column), focused-dot (already present), stale badge (already present), `decision` snippet (closed-only), `anchor_task` link (already present in some), `created` date short-form, `task_count` (already present). Mostly already there — sweep for completeness vs `/tasks` card density.

Surface: read-only. No new endpoints. Pure template work + a `_load_arc_metadata_for_card()` helper in `web/blueprints/arcs.py`.

Estimated effort: 1-2 hours.

### Slice 2 (build): inline editable name + focus toggle
**T-1907 (proposed):** add inline-editable name (mirror `editable-kanban-name` JS pattern) and a focus-dot toggle. Endpoints: `POST /api/arc/<slug>/name`, `POST /api/arc/<slug>/focus`. Lib functions: `do_arc_rename`, `do_arc_focus_toggle` (the latter mostly exists).

Estimated effort: 2-3 hours.

### Slice 3 (build): inline status select with gated transitions
**T-1908 (proposed):** add inline status select on arc-card. Dropdown options dynamic per current state per Status transition matrix above. Selecting "closed" does NOT POST a status change — it redirects to `/arcs/<slug>/close` (T-1902 surface, requires T-1902 to have shipped first → strict dependency). Selecting "abandoned" POSTs to `/api/arc/<slug>/abandon` after a confirmation modal. Endpoint: `POST /api/arc/<slug>/status` rejecting closed-from-anywhere.

**Hard dependency on T-1902** because slice-3 redirects to the close-review surface.

Estimated effort: 3-4 hours.

### Slice 4 (build): filtering + see-all view
**T-1909 (proposed):** filter querystring controls (by status, by stale, by focused, by anchor-uncompleted) + a "see all" view-mode (`?view=list`) that flattens the 4 columns into a single sortable table. Mirror `/tasks?view=list` pattern.

Estimated effort: 2-3 hours.

### Dependency graph

```
T-1906 (read-only enrichment) ──┬── T-1907 (inline name + focus)
                                │
                                ├── T-1909 (filters + see-all)
                                │
T-1902 (close surface) ─────────┴── T-1908 (inline status — closed→T-1902)
```

T-1906/T-1907/T-1909 parallel-eligible after T-1906 lands. T-1908 strictly after T-1902.

## Recommendation: **DEFER** (until human prioritises slices)

Feature parity is multiple discrete capabilities. Decomposition above is the agent's proposal; user input on slice order + drop-out before committing to a build sequence. DEFER means "park this inception, but the build slices are pre-scoped — promotion to GO is a low-effort triage when slices ship in priority order."

## Scope fence

**IN:** the four slices above, all under `/arcs` Watchtower namespace.

**OUT:**
- Bulk arc operations (would invite the same scoping decisions arc-by-arc)
- Inline `decision` / `headline_mechanic` editing (these are decision-level fields, not data fields)
- Auto-status-flip rules (e.g. "draft → in-progress when first task added") — would require structural arc-state-machine work, separate inception
- Changing T-1671 §ACD axiom

## Cross-references

- T-1904 — the just-shipped kanban this slice builds on
- T-1902 — `/arcs/<slug>/close` review surface (T-1908 depends on this)
- T-1671 — §ACD closure gate (the constraint that shapes slice-3)
- T-1848 — D-Immutability axiom (the constraint that fixes which fields can't be edited)
- T-1855 — stale-arc warning (provides the `stale` flag rendered on cards)
- T-1661 — task arc namespace (the precedent for arc-id filters on `/tasks`)
- `web/templates/tasks.html:480-518` — kanban card template (the parity target)
- `web/blueprints/tasks.py:492-595` — `/tasks` blueprint (the API parity target)
