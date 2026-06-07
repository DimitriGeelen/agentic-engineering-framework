# A3 — Interactions Architecture Review (arc-007 / T-1987 inception)

**Reviewer:** isolated TermLink worker `reviewer-A3-interactions`
**Dimension:** cross-cutting interactions — S6 (T-1993) + S4 (T-1992) interaction patterns
**Date:** 2026-05-22
**Verdict:** **ADJUST** — S6 as scoped is four independent subsystems mis-bundled into one slice, and one of them (inline edit) is already half-built. Split S6, re-home two subsystems, and re-scope ⌘K as its own slice.

---

## TL;DR for the human

1. **Inline edit is not greenfield.** Watchtower already ships a working inline-edit layer (T-181 spike): per-field POST endpoints (`/api/task/<id>/{status,owner,horizon,type,name,description,toggle-ac}`), an `inline_select` macro, and editable kanban cards. S4/S6 *refine* it; they do not build it. This must be stated in the slice bodies or we re-invent it.
2. **SSE infra already exists.** `sse_event()` in `web/shared.py`, `htmx-ext-sse.js` vendored, and live streaming already used for chat/ask. The live activity ticker has a backend precedent — it is the *cheapest* of the four S6 subsystems, not a risk.
3. **⌘K is the expensive one** and deserves its own slice. It needs an index endpoint + fuzzy matcher + modal + recency persistence — a full session on its own.
4. **Bulk actions are table-coupled** and belong in S4 (Tasks), not a cross-cutting slice.
5. **No new DB.** SQLite FTS would violate the portability directive and the filesystem-store model. Index via a server-built JSON endpoint with mtime invalidation.

---

## Current-surface inventory (what already exists)

Established by reading `web/templates/base.html`, `web/templates/tasks.html`, `web/blueprints/tasks.py`, `web/shared.py`, `web/static/js/`:

| Capability | State today | File evidence |
|---|---|---|
| Keyboard handlers (⌘K, `?`, j/k) | **None** — zero `keydown`/`metaKey` listeners anywhere | `base.html` (no matches), `web/static/js/*` (no matches) |
| Modal / `<dialog>` infra | **None** | no `<dialog>`, `role="dialog"`, `aria-modal` in templates |
| Command palette | **None** | — |
| Inline edit | **Exists** (pessimistic, HTMX) | `tasks.py:852-1000`, `_partials/inline_select.html`, `tasks.html` `.editable-kanban-name`/`.inline-status-select`/`.inline-horizon-select` |
| Kanban board | **Exists** | `tasks.html:108-260` `.kanban-board`/`.kanban-column`/`.kanban-card` |
| Drag-to-reorder | **None** (no Sortable, no HTML5 DnD) | grep clean |
| Bulk actions / multi-select | **None** | grep clean |
| Side-panel detail | **None** — `/tasks` row → full-page nav to `task_detail.html` | — |
| SSE backend | **Exists** | `shared.py:668 sse_event`, `discovery.py:249-314`, `api.py:185-211` |
| SSE client ext | **Vendored** but unused in templates | `base.html:13 htmx-ext-sse.js`; no `hx-ext="sse"` in any template |
| Toast | **Exists** | `base.html:475 showToast`, `.wt-toast` |
| Nav source | static Python list | `shared.py:102 NAV_GROUPS` (4 groups, Govern=16 items) |
| HTMX | present + `afterSwap` hooks (active-nav, highlight.js) | `base.html:516,560,582` |
| Per-user prefs | **None yet** (A2 lands in S1) | grep clean |

**Implication:** S6 was scoped as if all four subsystems were greenfield. Two of the eight interactions named in the inception (inline edit; live feed backend) are partially or wholly in place. The slice bodies must reference these or work will be duplicated.

---

## 1. ⌘K palette — concrete architecture

### 1a. Searchable entities

The mockup (`direction-calm.jsx:599-660`, `CalmCmdK`) groups results into **Pinned · Pages · Entities · Commands**. Concretely the palette should index:

| Group | Source | Cardinality | Notes |
|---|---|---|---|
| Pages | `NAV_GROUPS` (`shared.py:102`) | ~31 | already structured; free |
| Tasks | `.tasks/active/*.md` (+ recent `completed/`) | ~dozens active, ~2000 completed | **index active + N most-recent completed only** — not the whole corpus |
| Arcs | `.context/arcs/*.yaml` | ~7 | id + headline_mechanic |
| Learnings | `.context/project/learnings.yaml` | ~400 | **titles only** — deep search stays in `/search` |
| Decisions | `.context/.../decisions` | ~hundreds | titles only |
| Approvals | active review queue (`fw review-queue`) | ~75 today | A-NNNN ids |
| fw commands | **curated static list** | ~40 | NOT scanned from `fw help` at request — hand-pick the safe, navigable verbs |
| Files | fabric components (`.fabric/components/*.yaml`) | ~hundreds | optional; gate behind a `>` prefix |

**Scoping recommendation (important):** ⌘K is a *navigator* (jump to an entity / fire a command), **not** a deep semantic search. The framework already has semantic Q&A at `/search` (`search-qa.js`, Qdrant/embeddings). Do **not** duplicate full-text-over-learnings into ⌘K — index titles/ids for jump-to, and offer a "Search everything for '<query>' →" escape hatch that hands off to `/search`. This keeps the index small and the latency instant.

### 1b. Index source — trade-offs and pick

| Option | Pro | Con | Verdict |
|---|---|---|---|
| Filesystem scan per keystroke | always fresh, zero infra | O(corpus) per request; re-parses YAML each time; laggy at 2000 files | ✗ |
| **Pre-built JSON endpoint, cached, mtime-invalidated** | one parse, instant serve, fits existing Flask-returns-data pattern | small staleness window; cache logic | ✓ **pick** |
| SQLite FTS5 | fast, ranked, scales | **new dependency + new store** — violates Directive 4 (portability) and the "YAML is the store, no DB" constraint | ✗ |

**Pick: server-built JSON index at `GET /api/palette/index`.** Build the index by scanning `.tasks/active/`, `.context/arcs/`, NAV_GROUPS, the curated command list, and learning/decision titles; cache the result in module memory; invalidate when the **max mtime** of `.tasks/` + `.context/arcs/` + the learnings file changes (cheap `os.stat` check per request, full rebuild only on change). Ship gzipped; payload for the recommended scope (active tasks + arcs + pages + titles) is small (tens of KB), well within a single fetch on palette-open. Refresh on open, not on keystroke.

### 1c. Fuzzy match

| Option | Bundle | Notes |
|---|---|---|
| **Custom subsequence scorer** (~1 KB) | tiny | subsequence match + bonus for word-boundary / consecutive / id-prefix hits; matches the framework's "no heavy dep" ethos | ✓ **pick** for v1 |
| fuse.js (min+gz ~6 KB) | small | better ranking, configurable weights; reach for it only if custom ranking feels wrong | fallback |
| fzy.js | tiny | good algorithm, less maintained | alt |
| Server round-trip per keystroke | 0 client bundle | adds latency per keystroke, holds a worker; defeats "instant" | ✗ |

Match **client-side** against the fetched JSON — a server round-trip per keystroke is the wrong latency profile for a palette. Start with the ~1 KB custom scorer; fuse.js is a drop-in upgrade if ranking quality is judged insufficient (a `[REVIEW]` call).

### 1d. Keyboard contract & conflicts

- `⌘K` / `Ctrl+K` open (`e.metaKey || e.ctrlKey`). **Browser conflict:** `Ctrl+K` is "focus address bar / search" in some browsers — `preventDefault()` required; acceptable for an internal tool.
- `Escape` close — **free if built on native `<dialog>`** (see §9).
- `↑`/`↓` or `Ctrl+n`/`Ctrl+p` to navigate results; `Enter` to select; `⌘P` to pin (mockup footer `direction-calm.jsx:636`).
- **Global-handler hygiene:** the keydown listener must ignore keys when focus is in `input`/`textarea`/`[contenteditable]` — *except* the ⌘K combo itself, which is global. This is the classic bug source; pin it with a test.
- **HTMX:** htmx binds no global keys, so no key conflict — but palette-injected result rows that carry `hx-*` need `htmx.process()` (see §9).

### 1e. Recency — where it lives

"Recent-first" needs persistence. Per A2 (per-user YAML), store under `.context/user-preferences/<who>.yaml`:

```yaml
recent_palette: [T-1987, arcs/watchtower-redesign, approvals]   # capped ~20, MRU
```

**Recommendation:** per-user YAML as source of truth (survives restart, cross-machine per A2 rationale), with a **localStorage write-through cache** so the palette can render recents instantly on open without waiting for a round-trip, then reconcile. A bare POST `/api/palette/touch?id=…` on selection appends to the YAML (debounced). **Links to A2** — fold `recent_palette` into the same per-user prefs file S1 introduces; do not create a second persistence mechanism.

---

## 2. `?`-shortcuts overlay — registry pattern

Mockup `direction-calm.jsx:660-690` (`CalmShortcuts`): a static dialog with three sections (**Navigate / Selection / Actions**), each a list of `[key, description]`.

- **Static vs dynamic:** a **hybrid** is right. Maintain a single declarative registry (a JS object: `{section: [[key, desc, scope]]}`) that is the *one* source of truth for both (a) the overlay render and (b) the actual `keydown` dispatch table. This avoids the drift bug where the overlay lists a shortcut that no handler implements (or vice-versa). Avoid scanning `data-shortcut` attributes off the DOM — the overlay should describe *all* shortcuts including ones whose target element isn't currently rendered.
- **Per-page vs global:** registry entries carry a `scope` (`global` | `<page>`). On `?`, render global + current-page entries. Page modules register their extras at load.
- **Accessibility:** build on native `<dialog>` (§9) → free focus trap, `Escape`, `::backdrop`. Add `role="dialog"` `aria-label="Keyboard shortcuts"`; the `<kbd>` element for each key gives screen readers correct semantics. The `?` trigger must itself respect the input-focus guard (don't fire while typing).

This is the **cheapest** S6 subsystem and should ride along with whichever slice first introduces the global keydown layer (logically the same slice as ⌘K, since both need the dialog + key-dispatch scaffolding).

---

## 3. Side-panel docking — state machine

Mockup `direction-calm.jsx:479-540` (`CalmSidePanel`): right-docked panel with header buttons for **dock-to-bottom / dock-to-left / fullscreen / close**.

**States:** `closed` · `right` (default) · `left` · `bottom` · `fullscreen`. Model as a single `dock` enum on a small client controller, not five booleans.

- **Persist:** dock preference is an *aesthetic ergonomic* choice → per-user YAML per A2 (`panel_dock: right`). **Links to A2.** Which task is open is session/URL state, not a preference.
- **Animation:** **CSS transitions** on `transform`/`width` (GPU-cheap), not JS-driven. Nothing should *block* during the ~150 ms transition — content loads independently of the slide. Avoid animating `width` for the row list reflow; prefer `transform: translateX` on the panel over a fixed-position overlay so the underlying list doesn't reflow mid-animation.
- **Click-row → open:** **HTMX-loaded partial** (`hx-get=/tasks/<id>/panel hx-target=#side-panel`). Trade-off: partial = server owns the markup (reuses Jinja, consistent with the rest of Watchtower, no client templating) at the cost of a round-trip; full client render would need a JSON API + client templates (a second rendering path — avoid). Partial wins for consistency. **Preload-on-hover** (`hx-trigger="mouseenter once"`) hides the round-trip.
- **Keyboard:** `Escape` closes; `⌘.` cycles dock position (mockup `direction-calm.jsx` shortcuts list: `⌘. Dock side panel`); `j/k` move selection in the underlying list while the panel tracks the focused row.
- **Note:** the side panel is an **S4 (Tasks)** deliverable, not S6 — it's listed here only because the dock keyboard shortcuts (`⌘.`, `Escape`) must be registered in the same shortcut registry as §2.

---

## 4. Inline edit contract — **already partly built**

**This is the most important finding of the review.** `tasks.py:852-1000` + `_partials/inline_select.html` already implement inline edit:

```jinja
{# inline_select macro — POST /api/task/<id>/<field>, swap returned fragment #}
<form hx-post="/api/task/{{ task_id }}/{{ field }}" hx-swap="innerHTML">
  <select name="{{ field }}" onchange="this.form.requestSubmit()">…</select>
</form>
```

- **Cells covered today:** status, owner, horizon, type, name, description, AC checkboxes. The mockup's editable side-panel fields (`direction-calm.jsx:520`: Status, Owner, Tags) are a **superset** — *tags* is the main gap.
- **Activation:** existing pattern is `<select onchange>` (no click-to-activate text edit except name). Mockup implies click-to-edit on more cells. Recommend: keep `<select>` for enum fields (status/owner/horizon/type), add click-to-activate for free-text (title, tags).
- **Persistence — pessimistic, and that's correct:** existing endpoints POST → `fw task update` → return rendered fragment. **KEEP pessimistic.** Optimistic DOM-first is *wrong here* because the write goes through `fw`'s gates (P-010/P-011, focus-drift, arc-id validation) — an optimistic UI would show a state the gate then rejects. The store is gate-mediated, so the server is the authority. (Contrast: optimistic is fine for stores without server-side validation; this one has heavy validation.)
- **Validation:** round-trip to server (enum validation already in the endpoints: `tasks.py:856 if horizon not in enums`). Client may pre-disable invalid options, but the server is authoritative.
- **Failure UX:** today the endpoints return an error `<p>` fragment swapped inline (`tasks.py:864`). **Upgrade to: revert the cell + `showToast(err,'error')`** (toast already exists, `base.html:475`). The current inline-error-`<p>` is functional but visually crude; this is a `[REVIEW]` polish item.

**Recommendation:** the inline-edit AC in S4/S6 must read *"extend the existing T-181 inline-edit layer to tags + click-to-edit free-text + toast-on-failure"*, not *"build inline edit"*. Otherwise an agent rebuilds what exists.

---

## 5. Drag-to-reorder on board

No drag today. Mockup shows a kanban board (columns = status).

| Library | Bundle (min+gz) | A11y | Verdict |
|---|---|---|---|
| **Sortable.js** | ~12 KB | mouse/touch only OOTB; keyboard needs extra | de-facto; ✓ if drag ships |
| dragula | ~8 KB | similar a11y gap | alt |
| Native HTML5 DnD | 0 | clunky DnD model, worst a11y, ghost-image quirks | ✗ |
| Custom pointer-events | small | full control, more code | overkill v1 |

**The persistence question is the real decision, and it splits the feature:**

- **Cross-column drag = status change.** Dragging a card from "active" to "work-completed" is a **status mutation** — and `/api/task/<id>/status` *already exists*. This is **cheap and zero-new-model**: Sortable `onEnd` → POST the existing endpoint. ✓ ship this.
- **Intra-column reorder = order index.** Tasks have **no `order:` field** today; sorting is by horizon/recency. Persisting manual order needs a **new frontmatter field** with blast radius (every list query, the kanban sort, handover ordering, audits). This is a model change, not a UI change.

**Recommendation: split drag into two.** Cross-column status-drag reuses the existing endpoint — low risk, ship in S4. Intra-column manual reorder requires a new persisted `order:` field — **DEFER** to a follow-up task (the inception already lists drag-reorder as DEFERRED; this review sharpens *why*: it's a data-model change masquerading as a UI feature). Do not gate the whole board redesign on Sortable.js + a new order field.

---

## 6. Bulk-action contract

Mockup `direction-cockpit.jsx:404-450`: checkbox column + footer bulk bar (`1 SELECTED · T-1662` + MOVE/ASSIGN/TAG/PROMOTE→ARC/ARCHIVE + `esc · clear · j/k navigate`).

- **Selection model:** checkbox per row + **shift-click range** + **cmd/ctrl-click toggle** + **select-all** header checkbox. Mirror the mockup's `j/k` navigate + `x` select + `shift+x` range (`direction-calm.jsx` shortcuts).
- **Floating bar position:** mockup uses a **footer bar** under the table; a sticky **bottom-center** floating bar is the modern convention and survives scroll. Pick bottom-center, sticky.
- **Visible vs overflow:** show the 3-4 highest-frequency actions (Status, Owner, Tag) inline; push the rest (Promote→Arc, Archive) into an overflow `⋯` menu.
- **API surface — batch, not N singles:** **add one batch endpoint** `POST /api/tasks/bulk` `{ids:[...], action, params}` that loops `fw task update` server-side and returns a **per-id result summary** fragment. Looping N individual existing endpoints from the client means N HTTP round-trips **and N `fw` subprocess spawns** (each endpoint shells out via `run_fw_command`) — slow and with messy partial-failure semantics. A batch endpoint spawns server-side, can short-circuit, and reports `{succeeded:[], failed:[{id,err}]}` in one response. **This is the one genuinely new backend surface S6/S4 needs.**
- **Gate awareness:** bulk status→work-completed must respect the same gates as single completion (Recommendation/RCA/verification). The batch endpoint must surface per-id gate refusals, not silently `--force`. (Sovereignty: bulk-completing human-owned tasks is a §Autonomous-Mode-Boundaries violation — the batch endpoint should refuse `owner: human` rows unless individually authorised.)

**Recommendation:** bulk actions are **table-coupled** — they live and die with the Tasks table. Re-home bulk actions into **S4 (T-1992)**, not the cross-cutting S6. The only cross-cutting piece is the selection *keyboard* shortcuts, which register in the §2 registry.

---

## 7. Live activity ticker

Mockup `direction-cockpit.jsx:253-255`: `LIVE FEED · last 12h` with a `STREAMING` pulse dot.

- **Source — SSE, decisively.** The infra already exists: `sse_event()` (`shared.py:668`), `htmx-ext-sse.js` vendored (`base.html:13`), and SSE already used for chat/ask (`discovery.py`, `api.py`). Short-poll wastes requests; long-poll is SSE-minus-ergonomics; websockets are overkill (one-directional data) and add a dependency. **Pick SSE.**
- **Cost analysis (idle browser, 10 watchers, event every 30 s):**
  - Each SSE client holds **one long-lived connection = one held server worker/thread** for its lifetime.
  - **Werkzeug dev (threaded=True):** fine for ~10 clients — 10 threads parked on a generator.
  - **gunicorn (parked in T-1611):** ⚠️ **sync workers will starve** — each SSE connection occupies a worker permanently; 10 watchers > default worker count = the app stops serving normal pages. **SSE + gunicorn requires `gevent`/`eventlet` workers or a generous `threads` count.** Flag this as a constraint that couples S6 to the T-1611 gunicorn migration. Mitigation: heartbeat-and-recycle (server closes idle streams after N min, client auto-reconnects), and a single shared event source tailed by all clients rather than per-client filesystem scans.
  - Idle bandwidth is near-zero (SSE comment heartbeats every ~15 s keep the connection alive).
- **Trigger source:** the ticker should **tail an append-only event log**, not poll the filesystem per client. Candidates already exist: `.context/working/watchtower.log`, the audit JSONL streams, monitor JSONLs. **Recommendation:** define a single `.context/working/activity.jsonl` appended by existing hooks (post-commit hook, `update-task.sh` on status transitions) and have the SSE endpoint tail it (`seek` to EOF, stream new lines). This decouples the producer (hooks) from the consumer (SSE) and means zero per-client scanning.
- **Subtle animations:** CSS keyframes (the mockup's pulse dot); trigger by adding a class when a new SSE line arrives, auto-removed after the animation. Keep them in CSS, fired by a tiny JS `addEventListener('message')`.
- **Quiet mode:** per-user YAML toggle (A2) `quiet_mode: true` → body class that disables ticker animations (and optionally pauses the stream). **Links to A2** — this is an appearance preference, so it belongs in the S1 Appearance screen's preference set.

**Recommendation:** the ticker is cross-cutting in *data* but its primary surface is the **Cockpit LIVE FEED card** (S3). Pair the SSE endpoint with **S3 (T-1990)**; expose a reusable ticker component the other pages can mount. It is the lowest-risk S6 item (infra exists) and should not be blocked behind ⌘K.

---

## 8. Filter / saved-view chips

Mockups: editorial `direction-editorial.jsx:305-318` (chips `arc·A-014`, `owner·me`, `status·≠done` + `Save view`); approvals `:413` (`risk·high+`, `mine`, `needs me`). Sub-nav tabs already exist (`Pending·5 / Mine / Resolved / All`).

- **State — URL query params as source of truth.** `/tasks?arc=arc-007&owner=me&status=!done` is **shareable, bookmarkable, back-button-correct, and server-filterable** (the server can pre-filter the list, smaller payloads). This beats client-only filter state. Chips read from / write to the query string.
- **Saved views — per-user YAML (A2).** `saved_views: [{name: "My arc work", query: "arc=arc-007&owner=me"}]`. A saved view is just a named pointer to a param-set. **Links to A2.**
- **Pre-baked vs user-created:** ship **All / Mine / Starred / Recent** as built-in defaults (Mine = `owner=$USER`, Recent = last-touched, Starred = per-user `starred:` list). User-created saved views are additive named param-sets. "Starred" needs a per-user `starred: [T-…]` list (A2) + a star toggle (reuse the inline-edit POST pattern).
- **Facets:** **multi-select** (mockup shows multiple active chips simultaneously: arc AND owner AND status). Single-chip-at-a-time would be a regression from the mockup. Each facet ANDs.

**Recommendation:** filter chips are **table-coupled** (Tasks, Approvals) → distribute to S4 (Tasks) and S3 (Approvals). The only shared piece is the saved-view persistence helper, which folds into the A2 per-user prefs module from S1.

---

## 9. HTMX coexistence — concrete rules

Inline-edit swaps + side-panel partials + ⌘K-loaded result rows all share one DOM. Conflicts and rules:

1. **`htmx.process()` after non-HTMX injection.** If ⌘K results are injected via `fetch` (not htmx), any `hx-*` on the injected rows (e.g. a result row that is itself an inline-approve form) **will not bind** until you call `htmx.process(resultsContainer)`. Rule: every fetch-injected fragment that may contain `hx-*` must be passed through `htmx.process()`.
2. **Nested HTMX is fine going the other way.** If ⌘K opens an **HTMX-loaded** partial (`hx-get` into the dialog body), htmx processes the swapped content automatically — nested `hx-*` inside it bind normally. So *prefer* loading palette detail/side-panel via htmx over fetch where possible.
3. **`<dialog>` + htmx swap target.** Use a native `<dialog>` whose body is an `hx-target`. Open with `dialog.showModal()` (free Escape/focus-trap/`::backdrop`), let htmx swap the inner content. The existing `htmx:afterSwap` listeners (`base.html:516` active-nav, `:582` highlight.js) will run on dialog content too — verify they no-op gracefully on palette/panel markup.
4. **Keydown guard vs htmx inputs.** The global keydown layer must skip when focus is inside an htmx form input (else `j/k` selection fires while the user types in an inline-edit field). Guard: `if (/^(input|textarea|select)$/i.test(document.activeElement.tagName) || activeElement.isContentEditable) return;` — except for the ⌘K combo.
5. **CSRF.** All mutating posts (bulk endpoint, palette `touch`, star toggle) must include the CSRF token — `csrf-htmx.js` (`base.html:14`) auto-injects for htmx; for raw `fetch` you must add the header manually (the codebase has `fetchWithCsrf`, T-1453).
6. **SSE + htmx ext.** The ticker can use `hx-ext="sse" sse-connect=…` declaratively, OR a raw `EventSource`. Given the existing chat code uses raw fetch-SSE (not the htmx ext), and the ticker needs custom animation handling, a **raw `EventSource`** is simpler and avoids the unused-ext path — but either coexists.
7. **`afterSwap` re-init.** Any feature initialised once on `DOMContentLoaded` (palette key-binding, Sortable on the board) must **also re-init after htmx swaps** if the board/table is itself swapped — register on `htmx:afterSwap` like the existing nav/highlight handlers do.

No blocking conflict exists; the rules above are the join-points to test. The single biggest footgun is rule 1 (`htmx.process` on fetch-injected `hx-*`).

---

## 10. Recommendation — S6 scope

**Verdict: ADJUST (split + re-home).** S6 as written ("⌘K + ?-overlay + bulk + ticker") bundles four subsystems with different surfaces, risk profiles, and dependencies, and overlaps S4 on inline edit. Recommended re-decomposition:

| New shape | Contents | Why | Risk |
|---|---|---|---|
| **S6a — Command layer** (own slice; the real T-1993) | ⌘K palette + `?`-overlay + global keydown registry + `<dialog>` scaffold | These share the keydown/dialog/registry scaffolding; ⌘K alone is a full session (index endpoint + fuzzy + recency + modal). The overlay is cheap and rides the same scaffold. | **Med-High** — first global keyboard layer; index endpoint; recency persistence |
| **→ S4 (T-1992)** absorbs | bulk-action contract + batch endpoint + filter chips + drag (cross-column only) + inline-edit *extension* | All table-coupled; inline edit already exists here (T-181) | Med |
| **→ S3 (T-1990)** absorbs | live activity ticker + SSE activity endpoint | Primary surface is the Cockpit LIVE FEED card; SSE infra exists | **Low** (infra present) |
| **→ S1 (T-1988)** absorbs | per-user pref keys: `quiet_mode`, `panel_dock`, `recent_palette`, `starred`, `saved_views` | All are A2 per-user prefs; one persistence module, not five | Low |
| **DEFER** (follow-up task) | intra-column drag reorder (needs new `order:` frontmatter field) | data-model change, not UI; already DEFERRED in inception | — |

**If the human prefers minimal churn to the slice plan:** keep S6 as one slice but (a) explicitly scope it to **⌘K + `?`-overlay only** (the genuinely cross-cutting, genuinely new pieces), (b) move bulk/chips/drag into S4's body, (c) move the ticker into S3's body, and (d) annotate S4 that inline edit is an *extension of T-181*, not new. This is the lighter-touch version of the same recommendation.

**Either way, two corrections are non-negotiable for arc honesty:**
1. **State that inline edit already exists (T-181).** Otherwise §ACD divergence: the slice claims to build what's shipped.
2. **State that SSE infra already exists.** The ticker's "first global keyboard layer" framing in the inception over-states its risk; the ticker is the *easy* one.

### Index-source decision (the headline pick requested)

**Pre-built JSON index endpoint (`GET /api/palette/index`), module-cached, invalidated by max-mtime of `.tasks/` + `.context/arcs/` + learnings file; fuzzy-matched in-browser with a ~1 KB custom subsequence scorer (fuse.js as the upgrade path).** No SQLite — it would violate Directive 4 (portability) and the no-DB constraint.

### Biggest risk

**SSE + the parked gunicorn migration (T-1611) is a starvation trap.** SSE holds one worker per connected client; gunicorn sync workers will stop serving normal pages once watcher count exceeds worker count. The ticker works fine on today's threaded Werkzeug dev server, then silently breaks the whole app the day Watchtower moves to gunicorn — unless S3/S6 specifies `gevent`/`eventlet` workers (or a generous threaded count) and a heartbeat-recycle policy. This cross-slice coupling between the ticker and T-1611 must be written down now, not discovered in production.
