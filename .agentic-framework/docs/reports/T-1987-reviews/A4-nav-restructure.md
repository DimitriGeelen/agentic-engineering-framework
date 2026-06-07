# T-1987 review-A4 — Navigation restructure (S2 / T-1989)

**Reviewer:** isolated TermLink worker (reviewer-A4-nav)
**Dimension:** navigation restructure — current 4-group nav audit, IA proposal, 3-layout challenge
**Scope of review:** T-1989 (arc-007 S2). No source edits; no task-body edits.
**Verdict:** **ADJUST** — keep S2 in the arc, but (1) ship ONE layout not three, (2) re-cut the IA (Govern 16 → split), (3) correct the migration blast-radius (nav is **one file**, not 30+), (4) give Settings a nav home, (5) solve breadcrumb staleness under htmx.

---

## 0. Method note

I read the *live* nav from `web/shared.py:102-142` (`NAV_GROUPS`), not the design mock. The mock in `nav-patterns.jsx:4-9` uses a **stale, hand-simplified** nav (Govern shown with 11 items, missing BVP/Arcs in Work, etc.). The real nav is larger than the mock — the mock under-states the very pain point it claims to solve. All counts below are from the live source.

---

## 1. Current nav inventory (authoritative — from `web/shared.py`)

The nav is data-driven from `NAV_GROUPS` (shared.py:102) rendered by `base.html:343-364`. Four groups, **31 items**, plus three top-bar extras (Docs link, Search icon, theme toggle).

### Work — 7 items
| Item | Endpoint | Status |
|------|----------|--------|
| Tasks | `tasks.tasks` | **core** |
| Arcs | `arcs.arcs_index` | core |
| BVP | `bvp.bvp_scatter` | core |
| Inception | `inception.inception_list` | core |
| Assumptions | `inception.assumptions_list` | core (sub of Inception) |
| Timeline | `timeline.timeline` | core (a *view* of Tasks, not a peer) |
| Prompts | `prompts.prompts_list` | core |

### Knowledge — 4 items
| Item | Endpoint | Status |
|------|----------|--------|
| Learnings | `discovery.learnings` | core |
| Graduation | `discovery.graduation` | core |
| Patterns | `discovery.patterns` | core |
| Decisions | `discovery.decisions` | core |

### Architecture — 4 items
| Item | Endpoint | Status |
|------|----------|--------|
| Fabric | `fabric.fabric_overview` | core |
| Explorer | `fabric.fabric_graph` | core (a *view* of Fabric) |
| Terminal | `terminal.terminal_page` | core |
| Sessions | `sessions_page.sessions_page` | core |

### Govern — **16 items** ← the stated pain point, confirmed exactly 16
| # | Item | Endpoint | Classification |
|---|------|----------|----------------|
| 1 | Approvals | `approvals.approvals` | **core — and the #1 priority page (chat)** |
| 2 | Directives | `core.directives` | core |
| 3 | Enforcement | `enforcement.enforcement_dashboard` | core |
| 4 | Discoveries | `discoveries_bp.discoveries_dashboard` | core |
| 5 | Hooks | `hooks.hooks_page` | core |
| 6 | Risks | `risks.risk_register` | core |
| 7 | Gaps | `discovery.gaps` | core (Knowledge-adjacent, mis-grouped) |
| 8 | Quality | `quality.quality_gate` | core |
| 9 | Reviewer Audit | `reviewer.reviewer_audit` | core |
| 10 | Reviewer Overrides | `reviewer.reviewer_overrides` | core (a *sub-page* of Reviewer Audit) |
| 11 | Escalation Drift | `escalation.escalation_drift` | core (niche) |
| 12 | Metrics | `metrics.project_metrics` | core (observability, not govern) |
| 13 | Costs | `costs.costs_dashboard` | core (observability, not govern) |
| 14 | Config | `config.config_page` | core |
| 15 | Cron | `cron.cron_registry` | core |
| 16 | Pending | `pending.pending_page` | core |

**Counts:** Work 7 · Knowledge 4 · Architecture 4 · Govern 16 = **31**.

### Duplicates / sub-pages masquerading as peers
These inflate the count and should collapse into a parent's contextual sub-nav rather than occupy a top-level slot:
- **Assumptions** is a view under Inception (route family `/inception/...`).
- **Explorer** is a view of Fabric (`fabric.fabric_graph`).
- **Timeline** is a view of Tasks.
- **Reviewer Overrides** is a sub-page of Reviewer Audit (both under `reviewer.*`).
- **Graduation** is the promotion pipeline of Learnings/Patterns.

### Dead / unused — none found, but two surprises
No nav item is dead. Recent template churn (60-day `git log`) shows every nav target has a maintained template. **However**, the inverse problem exists — see §1b.

### 1b. Orphans — live pages reachable by URL but ABSENT from the nav
These are reachable routes with maintained templates that **no nav group links to**:

| Page | Route | Template | Churn (60d) | Note |
|------|-------|----------|-------------|------|
| **Orchestrator** | `/orchestrator` | `orchestrator.html` | **15 commits** | Heavily maintained, completely un-navigable. Only linked from `arc_detail.html`/`arcs_index.html`. |
| **Fleet** | `/fleet` | `fleet.html` | 1 | Orphan. |
| **Settings** | `/settings/` | `settings.html` | 1 | **Orphan — and this is where the appearance screen lands (S1/A1).** No nav home today. |
| **Feedback analytics** | `/search/feedback/analytics` | `feedback_analytics.html` | 0 | Orphan. |
| **Docs (generated)** | `/docs/generated` | `docs_index.html` | — | "Docs" nav link points at `core.project` (`/project`), not here. Partial orphan. |

This reframes the pain point: the menu isn't just *too deep* (16-item Govern) — it's also *incomplete* (5 live pages have no nav entry). A restructure that only flattens Govern but doesn't home the orphans leaves the real navigability problem half-solved. **Settings being orphaned is load-bearing for the arc**: S1 ships `/settings/appearance` and there is currently no nav path to Settings at all.

---

## 2. Information architecture proposal

The current 4 groups conflate three different axes: *what you act on* (Tasks, Approvals), *what you know* (Knowledge), and *how the system is governed/observed* (Govern, which is really three sub-concerns crammed together). Govern is fat because it absorbed everything that wasn't obviously Work/Knowledge/Architecture.

**Proposal: 6 primary entries, each ≤7 sub-items.** Promote the two priority pages (Approvals, Tasks) to primary; split Govern's three latent concerns (decisions/risk · observability · ops); give Settings a home.

```
Cockpit            (/) — brand/home, not a dropdown
│
├─ Approvals        ← PROMOTED to primary (priority #1, the review bottleneck)
│     (no sub-nav; badge = pending count)
│
├─ Tasks            ← PROMOTED to primary (priority #2)
│     Board · List · Timeline · Inception · Assumptions · BVP · Prompts
│
├─ Knowledge
│     Learnings · Patterns · Decisions · Graduation · Gaps
│
├─ Architecture
│     Fabric · Explorer · Arcs · Sessions · Terminal
│
├─ Govern          ← slimmed to decisions/risk/policy
│     Directives · Enforcement · Hooks · Risks · Escalation Drift · Discoveries
│
└─ Insight         ← NEW: observability split out of Govern
      Metrics · Costs · Quality · Reviewer Audit · Reviewer Overrides · Orchestrator · Fleet
│
   (Ops items — Config · Cron · Pending · Settings — live under a gear/settings
    affordance on the right of the bar, NOT a dropdown group; see §3)
```

**What moved and why:**
- **Approvals → primary.** It is the chat's #1 priority page AND the framework's current bottleneck (75+ queued). Burying the bottleneck two levels deep in "Govern" is the single worst IA decision in the current nav.
- **Tasks → primary** with a real sub-nav (Board/List/Timeline) matching the mock's Pattern-1 tabs (`nav-patterns.jsx:82`).
- **Govern split** into **Govern** (policy/risk decisions: Directives, Enforcement, Hooks, Risks, Escalation Drift, Discoveries) and **Insight** (observability: Metrics, Costs, Quality, Reviewer×2, Orchestrator, Fleet). These are different mental modes — "is the system behaving?" vs "what do I need to decide?".
- **Gaps → Knowledge.** It is knowledge-corpus-adjacent (concern register), not a govern action.
- **BVP → Tasks sub-nav.** It scores tasks; it is a task lens, not a Work peer.
- **Config / Cron / Pending / Settings → a settings cluster** behind a gear icon on the right (where Settings naturally lives, and where the appearance screen will sit). Removes 4 items from the dropdown groups entirely.

**Result:** 6 primary entries (Cockpit + 5 dropdowns) where the deepest dropdown is 7 items (Insight), down from 16. Every live page including the 5 current orphans has a home.

---

## 3. Layout A — Top-bar primary + contextual sub-nav (the chat's stated structure)

This is what the human explicitly asked for in scoping (research artifact §Phase-2: *"Top-bar primary + contextual sub-nav per section"*) and what `NavPatternTopBar` (`nav-patterns.jsx:13-110`) mocks.

**Concrete layout — two strips:**

**Strip 1 (primary, 48px, `base.html` chrome):**
```
[WT logo] Watchtower v0.9.4 │ Approvals(4) · Tasks · Knowledge · Architecture · Govern · Insight │ [⌘K search……] [🔔] [⚙ settings] [☾ theme]
```
- Brand left (→ Cockpit). Primary items center-left as the 6 entries from §2.
- ⌘K search bar pushed right (`nav-patterns.jsx:53-62`).
- Gear (⚙) opens the settings cluster (Config/Cron/Pending/Settings/Appearance). Theme toggle stays.

**Strip 2 (contextual sub-nav, 40px):**
- **Left:** breadcrumb (`Work › Tasks › Board`), monospace, from the resolver in §6.
- **Center-left:** tabs for the *current primary section* (e.g. on Tasks: `Board · List · Timeline · Inception · Assumptions · BVP · Prompts`).
- **Right:** a section-scoped stat (`42 active`) + `Pinned · Recent`.

**When sub-nav changes:** **per primary section, not per breadcrumb.** The tab row is keyed off the active primary group (resolved from `request.endpoint`'s blueprint). The breadcrumb (in the same strip) changes per page. So strip-2 has two zones with two different change cadences: tabs = per-section, crumb = per-page.

**Sticky:** strip 1 sticky always; strip 2 sticky on scroll for long list pages (Tasks/Approvals) so the tabs stay reachable.

---

## 4. Layout B — Persistent sidebar (collapsible groups + pinned)

Mocked by `NavPatternSidebar` (`nav-patterns.jsx:114-200`), 232px column.

**Concrete groups & ordering (top → bottom):**
1. **Brand + version** (top, 0.9.4 chip).
2. **Search / ⌘K** trigger.
3. **Pinned** section — **at the top, directly under search** (matches mock `nav-patterns.jsx:146`). Rationale: pinned items are the user's hottest paths; top placement = zero scan. Each pinned row shows a count badge where relevant (Approvals → 4).
4. **Collapsible groups** in §2 order: Approvals, Tasks, Knowledge, Architecture, Govern, Insight. Each group `<details>`-style collapses; **the 16-item problem disappears because Govern/Insight collapse unless expanded** (mock's own claim, `nav-patterns.jsx:194`).
5. **Settings (gear)** pinned to the **bottom** of the rail (conventional position).

**Collapse behaviour:** click group header toggles expand/collapse; collapsed state persists per-user (links to **A2** — `.context/user-preferences/<who>.yaml`, key `nav.collapsed_groups: [..]`). Active group auto-expands on navigation.

**What "pinned" persists (→ A2):** per-user, in the same YAML the appearance screen uses:
```yaml
nav:
  pinned: [{path: /approvals, label: Approvals}, {path: /tasks, label: Tasks}, {path: /fabric/component/auth, label: "Fabric · Auth"}]
  collapsed_groups: [govern, insight]
```
Pinned is **per-user**, not per-browser — this is the whole reason A2 chose YAML over localStorage (research artifact §Q2).

---

## 5. Layout C — Slim icon rail + ⌘K-primary

Mocked by `NavPatternRail` (`nav-patterns.jsx:204-294`), 52px rail.

**Rail contents (5-6 icons):** the mock uses 5 — `list`(Work) · `layers`(Knowledge) · `branch`(Architecture) · `flag`(Govern, badge) · `activity`(Metrics) — plus a `settings` gear pinned to the bottom (`nav-patterns.jsx:248`). With the §2 IA I'd make the rail: **Cockpit · Approvals(badge) · Tasks · Knowledge · Architecture · Govern** + gear at bottom. Insight folds into ⌘K (it's observability — you go there deliberately, by name).

**Icon library:** the mock's icons (`list, layers, branch, flag, activity, settings, search, pin, bell, chevron`) are a hand-rolled `<Icon>` set in `shared.jsx`. For implementation, **Lucide** is the right choice — it is the superset the mock's names are drawn from (`list`, `layers`, `git-branch`, `flag`, `activity` are all Lucide names), MIT-licensed, ships as inline SVG (no font CDN — satisfies the arc's "no network at theme-pick" constraint, inception §Technical-Constraints). Vendor the ~12 needed SVGs into `web/static/icons/` rather than the whole library.

**Discoverability problem (the real risk of Layout C):** for a user who has *not* memorised ⌘K, a 6-icon rail is a **dead end** — Insight, Settings sub-pages, Arcs detail, every Govern item is invisible. The mock's own caption admits it: *"Best for very keyboard-driven users"* (`nav-patterns.jsx:288`). Mitigations if shipped: (a) icon tooltips on hover with the group name; (b) clicking a rail icon opens a fly-out list (so it degrades to Layout B on click); (c) a persistent `⌘K` hint chip in the header. Without (b), Layout C fails the "user who hasn't memorised ⌘K" test outright. **This is the layout I'd cut first** (see §9).

---

## 6. Breadcrumb resolver

**Critical architecture constraint discovered in review:** Watchtower renders pages as **fragments wrapped by `_wrapper.html` → `base.html`** (`web/shared.py:render_page`, `_wrapper.html`). On **htmx navigation only `#content` is swapped** — the nav/breadcrumb chrome in `base.html` is NOT re-rendered. A naïvely server-rendered breadcrumb in `base.html` would go **stale** the moment the user navigates via htmx (which is every in-app click — `<body hx-boost="true">`, `base.html:326`).

Today the code already works around this for `aria-current`: a JS `htmx:afterSwap` handler re-derives the active link client-side (`base.html:516-542`). The breadcrumb needs the same treatment but with data, not just a class toggle.

**Recommended mechanism:** server resolver + OOB swap.
1. Pure function in `web/shared.py`:
   ```python
   def resolve_breadcrumbs(endpoint, view_args) -> list[tuple[str, str]]:
       # returns [(label, url), ...] root → current
   ```
2. `render_page()` injects `breadcrumbs=resolve_breadcrumbs(request.endpoint, request.view_args)` into context (one line, alongside the existing `active_endpoint` setdefault at shared.py:788).
3. `base.html` renders a `<nav id="breadcrumb">` region in strip-2.
4. Each fragment emits an `hx-swap-oob="true"` copy of the breadcrumb region so htmx swaps update it in lockstep with `#content`. (Alternatively: a global `htmx:afterSwap` reads a `<template id="bc-data">` embedded at the top of each fragment — but OOB is cleaner and needs no per-template edit if injected by `render_page` into a shared partial.)

**Resolver coverage (concrete):**
| Route | view_args | Output |
|-------|-----------|--------|
| `/tasks` | — | `[(Work,/), (Tasks,/tasks)]` |
| `/tasks/T-1987` | `task_id=T-1987` | `[(Work,/), (Tasks,/tasks), (T-1987,/tasks/T-1987)]` |
| `/arcs` | — | `[(Architecture,/), (Arcs,/arcs)]` |
| `/arcs/watchtower-redesign` | `arc_id=…` | `[(Architecture,/), (Arcs,/arcs), (watchtower-redesign,/arcs/watchtower-redesign)]` |
| `/arcs/watchtower-redesign/close` | `arc_id=…` | `[…, (watchtower-redesign,/arcs/…), (Close,…/close)]` |
| `/learnings` | — | `[(Knowledge,/), (Learnings,/learnings)]` |
| `/learnings#L-419` (anchor) | — | resolver returns Learnings parent; the L-419 leaf is an in-page anchor, label resolved client-side from the row |

**Implementation note:** the resolver is a **single source-of-truth map** keyed by blueprint/endpoint → (primary-group-label, primary-group-url). For detail routes, append the `view_args` id as the leaf. ~40 lines. It also powers strip-2's per-section tab selection (§3) and the active-group highlight — replacing the brittle client-side path-matching at `base.html:524-531`.

---

## 7. Pinned-pages model

**Persisted data (per-user YAML, links A2):**
```yaml
nav:
  pinned:
    - {path: /approvals, label: Approvals}
    - {path: /tasks,     label: Tasks}
    - {path: /fabric/component/auth, label: "Fabric · Auth"}
```
- **Shape:** `[{path, label}]`. `path` is the canonical URL (used for active-match + navigation); `label` is the display string (user-editable on pin, defaults to the page's `<h1>`).
- **Limit:** **cap at 6**. Beyond 6 the value of pinning (fast recognition) inverts into a second cluttered menu. If the user pins a 7th, oldest unpinned-by-recency drops (or block with a toast — prefer block; pinning is deliberate).
- **Order:** drag-reorder, persisted as list order. (Drag is the same Sortable.js the arc already plans for the Tasks board in S4 — reuse, don't add a second dep.)
- **Star UI location:** a star/pin toggle in the **page header** (`.page-header`/`.wt-header`), top-right next to the H1 — the page you're on is the thing you pin, so the affordance lives on the page. Filled star = pinned. Mock shows the pin glyph (`Icon name="pin"`, `nav-patterns.jsx:151,267`) in amber `#b87a17`.
- **Surface:** Layout A → pinned items appear as a `Pinned ·` cluster in strip-2 right zone and inside ⌘K. Layout B → top "Pinned" section. Layout C → in the ⌘K palette + optional rail tooltips.

**API (HTMX POST, mirrors existing `/api/task/<id>/...` pattern):**
```
POST /api/nav/pin    {path, label}   → 200, returns updated pinned partial (OOB-swappable)
POST /api/nav/unpin  {path}          → 200
POST /api/nav/reorder {paths: [...]} → 200
```
Server-side: read-modify-write the user's YAML via the same `load_user_preferences/save_user_preferences` helper S1 adds to `web/shared.py` (research artifact §Forward-references). No new persistence layer.

---

## 8. Migration risk — **far lower than the brief assumes**

**The brief (T-1989 description + inception §Scope-Fence) implies nav replacement "touches every page header / 30+ templates."** Review of the render path shows this is **false**:

- The nav is defined **once** in `base.html:328-395` and the data once in `shared.py:NAV_GROUPS`.
- Page templates are **pure fragments** — only **5** files even contain `{% extends "base.html" %}`, and 4 of those are non-page utility templates; the real pages render via `render_page()` → `_wrapper.html` → `base.html` (`shared.py:render_page`).
- Therefore **replacing the nav is a 1-2 file change**: `base.html` (markup + CSS) and `shared.py` (NAV_GROUPS reshape + breadcrumb resolver). **Zero page-template edits required.**

**Files actually affected by S2:**
| File | Change |
|------|--------|
| `web/shared.py` | reshape `NAV_GROUPS` (§2), add `resolve_breadcrumbs()`, inject into `render_page` context, add pin helpers |
| `web/templates/base.html` | new nav markup (strip-1 + strip-2), breadcrumb region, pinned cluster, gear menu |
| `web/templates/_wrapper.html` | possibly add OOB breadcrumb region (or keep in base) |
| `web/blueprints/api.py` (or settings) | 3 new pin endpoints |
| `web/static/icons/` | vendored Lucide SVGs (Layout C only) |
| per-page `.page-header` | **only if** the star affordance is added inline — but this can be injected by a shared macro/context, avoiding per-template edits |

**Blast radius: ~4 files, not 30+.** The one place breadth *does* bite is the **star-on-each-page affordance** (§7) — but even that is avoidable via a shared header partial. **Recommend: NO feature flag needed.** Because the change is centralized in `base.html`, an incremental rollout has nothing to incrementally roll — it's one cutover. A feature flag would add complexity for a risk that the architecture has already eliminated. (If the human wants A/B safety, the *layout selector* itself is the flag — ship Layout A as default, keep the old nav reachable via a preference value for one release.)

**The genuine risk that remains** is the **breadcrumb-staleness-under-htmx** problem (§6) — that is where S2 will actually spend its hard hours, not in editing templates.

---

## 9. Challenge: do we need 3 layouts?

**No. Ship one. This is the central ADJUST.**

The combinatorial surface the arc currently implies is:
> **3 nav layouts × 6 palettes × 6 type pairings × 3 densities × 2 modes = 648 combinations.**

This is untestable, un-reviewable (the render-surface gate T-1766 requires a `[REVIEW]` Human AC per slice — nobody can eyeball 648 states), and the Playwright/visual-verification rule (memory: `feedback_ui_visual_verification`) would demand screenshots across an absurd matrix. The arc would collapse under its own QA weight.

**Evidence the human only ever wanted ONE layout:**
- Phase-2 scoping (research artifact): the human picked **"Top-bar primary + contextual sub-nav per section"** as *the* nav structure. Singular. Definite.
- The "3 patterns" came from the *designer's* exploration deliverable, not a human requirement.
- The "selectable layout" idea is from the **Phase-4 pivot** (*"can the styles, colors, navigation pattern be selectable?"*) — but that pivot was about **palette/type/density** selection (the Appearance screen's six presets). Nav-layout-as-a-preset is the designer extrapolating the pivot one axis too far. Navigation *structure* is not aesthetic taste; it is information architecture, and IA wants ONE good answer, not a dropdown of three.

**Arguments for keeping 3 (and why they're weak):**
- *"Power users want the rail."* — Maybe, but Layout C fails the discoverability test (§5) and serves a single keyboard-power-user persona that ⌘K already serves *within* Layout A. ⌘K is the rail, minus the dead-end.
- *"Selectability is the load-bearing arc insight."* — Selectability of **aesthetics** (palette/type/density) is load-bearing. Selectability of **IA** is not — it's three times the build, three times the QA, for a choice users make once and forget.

**Recommended scope-down:**
1. **Ship Layout A (top-bar + contextual sub-nav)** as the one nav. It's the chat's explicit structure, it reuses the existing two-strip mental model, and it carries breadcrumbs + pinned + ⌘K natively.
2. **Build the layout-selector hook but ship it disabled / single-valued.** The Appearance screen (S1) can carry a `nav_layout:` key (research artifact §Forward-references already lists `nav_layout: sidebar` in the preset shape) — wire the *plumbing* so a future slice can add Layout B without re-architecting, but don't build/QA B and C now.
3. **Defer Layout B (sidebar) to a fast-follow** only if S2 user feedback says the top-bar is too wide at 6 groups. Defer Layout C (rail) indefinitely — ⌘K covers its persona.

This turns 648 combinations into **6 palettes × 6 type × 3 densities × 2 modes** for the *appearance* axis (still large, but that's S1's problem and presets tame it) and **1** nav layout for S2. S2 becomes a tractable, single-cutover slice.

---

## 10. Recommendation

**ADJUST** the S2 scope. Keep nav restructure in arc-007 — it targets the human's confirmed #1 pain point — but make these specific adjustments before T-1989 starts:

| # | Adjustment | Why |
|---|------------|-----|
| **A1** | **Ship ONE layout (top-bar + contextual sub-nav).** Wire the `nav_layout` preference plumbing but build only Layout A. Defer B (sidebar) to a feedback-gated fast-follow; defer C (rail) indefinitely. | Kills the 648-combination QA explosion (§9); matches the chat's explicit singular choice. |
| **A2** | **Re-cut the IA: 6 primary entries, Govern split into Govern + Insight, Approvals & Tasks promoted to primary.** | Govern-16 isn't fixed by collapsing it into a dropdown — it's fixed by removing the conflation that made it 16 (§2). |
| **A3** | **Home the 5 orphans** — especially **Settings**, which S1's appearance screen depends on and which has no nav entry today. | The pain is also *incompleteness*, not just depth (§1b). Orchestrator (15 commits/60d) being un-navigable is a standing bug. |
| **A4** | **Correct the migration estimate in T-1989: blast radius is ~4 files, not 30+.** No feature flag needed. | Pages are fragments; nav is one file (§8). The brief over-states risk 8×. |
| **A5** | **Spec the breadcrumb resolver as a server function + htmx OOB swap** (not server-render-in-base, which goes stale on htmx nav). | This is the *actual* hard problem in S2 (§6); the brief doesn't mention it. |
| **A6** | **Re-frame the A5 success metric** from "clicks to reach Govern pages" to "scan-time / recognition cost." | Every grouped item is already 2 clicks; the pain is the 16-item *scan*, not click depth. Measuring clicks before/after would falsely show "no improvement." |

**What stays as-is (KEEP):** the pinned-favourites model (§4/§7 — well-scoped, reuses A2's YAML + S4's Sortable.js), breadcrumbs-everywhere (§6), and ⌘K as the universal escape hatch. The contextual-sub-nav (Board/List/Timeline tabs) is exactly right.

**Net:** S2 is a *good* slice aimed at a *real, human-confirmed* pain — but as written it (a) over-scopes to 3 layouts, (b) keeps the IA conflation that created Govern-16 in the first place, (c) over-estimates risk 8×, and (d) misses the orphan-Settings dependency on S1 and the htmx breadcrumb-staleness trap. ADJUST on all four and S2 becomes a tractable single-cutover win.

---

*Reviewer notes: read live `NAV_GROUPS` (shared.py:102-142), `render_page`/`_wrapper.html` render path, `base.html` nav chrome + htmx afterSwap handler, all blueprint routes, `nav-patterns.jsx` (3 mocks). No source or task-body edits made.*
