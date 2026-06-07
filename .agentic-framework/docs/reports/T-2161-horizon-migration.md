# T-2161 — horizon migration: completed/ null-sweep + partial-complete inventory

**Arc:** arc-009 horizon-axis-hardening (parent T-2159 inception GO)
**Slice:** 2 of 3 (after T-2160 ships derived-past render; before T-2162 audit rail)
**Date:** 2026-06-01

## What this report captures

Two corpus states relevant to the horizon-axis-hardening arc:

1. **completed/ migration** — files whose stored `horizon:` field was nulled by this slice's migration script (`bin/migrate-horizon-null-completed.sh`). Stored horizon on completed/ is behaviorally irrelevant after T-2160 — render computes `past` from `_location == 'completed'` — so YAML hygiene is the only motivation. Idempotent: re-running the script on this corpus emits `0 changes`.
2. **active/ partial-completes** — files where `status: work-completed` but the file lives in `.tasks/active/` because at least one `### Human` AC remains unticked. This is a *legitimate* state (T-193 AC-split); the report lists them so the inventory is grep-able and so any future cleanup has a baseline to compare against. **No active/ file was modified by this migration.**

## completed/ migration summary

| Metric | Count |
|--------|------:|
| Total files in `.tasks/completed/` | 1945 |
| Files with non-null/non-absent horizon BEFORE migration | 1828 |
| → `horizon: now` | 1561 |
| → `horizon: next` | 239 |
| → `horizon: later` | 28 |
| Files with absent horizon field | 117 |
| Files with already-null horizon | 0 |
| Files changed by migration (set to `horizon: null`) | **1828** |
| Re-run change count (idempotence check) | **0** |
| Files with non-null horizon AFTER migration | **0** |

The 117 absent-field files are pre-frontmatter-template tasks; they are NOT modified by this migration (no horizon field to null). They render correctly via the derived-past path.

## active/ partial-completes inventory

Inventory is included verbatim below from the report-builder script. Each row is a task that:

- Lives in `.tasks/active/`
- Has `status: work-completed`
- Has at least one unticked `### Human` AC (or has `owner: human`)
- Is awaiting human review — typically via `fw task review T-XXX` → Watchtower `/review/<id>`

These are NOT migration candidates. They are surfaced by the post-T-2160 handover footer ("Partial-Complete — awaiting human") and by `web/blueprints/tasks.py` rendering `_location == 'active'` + `status == 'work-completed'` distinctly from in-flight tasks.

Total partial-complete tasks (status=work-completed in .tasks/active/): **137**


## horizon: now (136 tasks)

| Task | Name | Last update | Owner |
|------|------|-------------|-------|
| T-2160 | horizon: derived past for terminal tasks + render-surface integration + invarian | 2026-06-01T10:47:46Z | human |
| T-1702 | Boundary hook: extend to outside-path arguments + scope-tag fw doctor findings | 2026-05-31T18:14:08Z | human |
| T-2136 | arc-006 demo_evidence capture — wire-level artefact for value-prioritisation hea | 2026-05-31T09:09:15Z | human |
| T-2119 | T-2074 followup: remove duplicate inline htmx error listeners in review.html | 2026-05-30T20:05:46Z | human |
| T-2117 | /arcs/<slug> scoped-driver display consistency — humanized name + slug across ap | 2026-05-30T18:39:31Z | human |
| T-2116 | /arcs/<slug>/close headline-mechanic-box contrast — primary-on-primary-bg same-h | 2026-05-30T18:28:44Z | human |
| T-2114 | review.html #ac-container Reload-page link + markdown-rendered URLs bounce-back  | 2026-05-30T16:40:31Z | human |
| T-2112 | /approvals 'Review' click swaps into polling div + bounces back after 10s — | 2026-05-30T16:19:43Z | human |
| T-2111 | /approvals arc-closure headline_mechanic uses .approval-meta — muted on dark, | 2026-05-30T14:46:15Z | human |
| T-2110 | headline-mechanic-box contrast — primary-on-primary-bg unreadable on /arcs/<slug | 2026-05-30T14:36:18Z | human |
| T-2102 | Watchtower /approvals page renders in 14.8s — aggregation perf (T-1954/T-2083 | 2026-05-30T12:36:59Z | human |
| T-2103 | /approvals renders 8926px tall — exceeds 8000px cap (T-2038 sibling, lower | 2026-05-30T08:27:32Z | human |
| T-2106 | /timeline warm-load 8.3s exceeds T-2105 5s cap — T-1954 cache pattern needed | 2026-05-29T23:15:40Z | human |
| T-1991 | Watchtower foundation tokens — 6 palettes × light/dark + 6 type pairings + | 2026-05-29T22:00:58Z | human |
| T-2089 | reviewer/overrides renders 8628px — 10th unbounded-table class instance | 2026-05-29T10:17:27Z | human |
| T-2088 | parametrized-route height guard: sample /arcs/<id>, /tasks/T-XXX, /review/T-XXX, | 2026-05-29T10:11:09Z | human |
| T-2087 | fix /arcs/<slug> constituent-table unbounded height (T-2038 class on parametrize | 2026-05-29T09:46:25Z | human |
| T-2086 | fix /bvp rubric duplicate rows for range scores (1–2 expands to two identical ro | 2026-05-29T09:28:36Z | human |
| T-2085 | fix double numbering in /bvp driver rubric (T-2084 followup) | 2026-05-29T09:00:01Z | human |
| T-2084 | show 0-5 scoring guidance per driver on /bvp (hover tooltip / expand) | 2026-05-29T07:45:22Z | human |
| T-2046 | /graduation renders 70000px tall — unbounded pipeline lists (T-2038 class) | '2026-05-28T22:54:12Z' | human |
| T-2047 | /docs/generated renders 34000px tall — unbounded list (T-2038 class) | '2026-05-28T22:54:12Z' | human |
| T-2049 | docs/generated detail pages — linkify dependency targets + resolve C-NNN fabric | '2026-05-28T22:54:12Z' | human |
| T-2051 | Watchtower POST /inception/<id>/decide returns 500 + leaves decision uncommitted | '2026-05-28T22:54:12Z' | human |
| T-2054 | work-completed clears focus, no-active-task gate then blocks committing the | '2026-05-28T22:54:12Z' | human |
| T-2062 | Watchtower /review/T-XXX returns 404 for completed tasks — break of agent hand-o | '2026-05-28T22:54:12Z' | human |
| T-2063 | Watchtower Complete button silent-fail — htmx form hits CSRF 403, swallows | '2026-05-28T22:54:12Z' | human |
| T-2064 | Task surfaced for human review despite zero Human ACs — review-queue filter | '2026-05-28T22:54:12Z' | human |
| T-2065 | arc driver-approve doesn't trigger automatic member-task BVP recalculation | '2026-05-28T22:54:12Z' | human |
| T-2066 | inception detail template silently drops Context/RCA/AC/Verification/Decisions | '2026-05-28T22:54:12Z' | human |
| T-2075 | push 'needs human review' predicate to queue-build layer via shared helper | '2026-05-28T22:54:12Z' | human |
| T-2077 | add render slots in inception_detail.html for Context/RCA/AC/Verification/Decisi | '2026-05-28T22:54:12Z' | human |
| T-2080 | show driver name alongside id on /bvp tables and forms | '2026-05-28T22:54:12Z' | human |
| T-1990 | Watchtower Cockpit + Approvals redesign — apply foundation tokens + new density | '2026-05-28T22:54:11Z' | human |
| T-1992 | Watchtower Tasks board + list redesign — side-panel detail with dock controls, | '2026-05-28T22:54:11Z' | human |
| T-1993 | Watchtower interactions — ⌘K command palette + ?-shortcuts overlay + bulk action | '2026-05-28T22:54:11Z' | human |
| T-1994 | Watchtower Fabric + Arcs page redesign — apply foundation tokens, dense graph, | '2026-05-28T22:54:11Z' | human |
| T-1999 | arc-007 review enablement — visual review surface for S0/S1 presets (palette/the | '2026-05-28T22:54:11Z' | human |
| T-2002 | UX-review TermLink agent preloaded with design style guides (T-2000 approach | '2026-05-28T22:54:11Z' | human |
| T-2003 | pico-bridge defeated in light mode — content-page chrome ignores palette accent | '2026-05-28T22:54:11Z' | human |
| T-2004 | make Typography & Density picker axes actually apply (self-host webfonts, headin | '2026-05-28T22:54:11Z' | human |
| T-2006 | fix Editorial/linen accent contrast — accent-ink on accent 3.83:1 fails WCAG | '2026-05-28T22:54:11Z' | human |
| T-2008 | arc-007 S2a nav IA regroup + Govern sub-grouping (top-bar layout) | '2026-05-28T22:54:11Z' | human |
| T-2009 | arc-007 S2b breadcrumbs on every page header (path-derived, htmx-fresh) | '2026-05-28T22:54:11Z' | human |
| T-2010 | arc-007 S2c pinned-pages model — star nav destinations, surface in top bar, | '2026-05-28T22:54:11Z' | human |
| T-2011 | arc-007 S2d — sidebar + icon-rail nav layouts + data-wt-nav selector | '2026-05-28T22:54:11Z' | human |
| T-2012 | arc-007 S6a — command palette core (⌘K jump + search fall-through) | '2026-05-28T22:54:11Z' | human |
| T-2013 | arc-007 S6b — keyboard-shortcuts overlay (? opens, lists live shortcuts) | '2026-05-28T22:54:11Z' | human |
| T-2015 | arc-007 S4a — slide-in dockable task side-panel (htmx read fragment) | '2026-05-28T22:54:11Z' | human |
| T-2016 | arc-007 S4c — active-filter chips on the tasks board (per-chip clear, shareable | '2026-05-28T22:54:11Z' | human |
| T-2017 | arc-007 S4b -- inline-edit task meta cells in the side panel | '2026-05-28T22:54:11Z' | human |
| T-2018 | arc-007 S4e/S6c -- bulk multi-select + floating action bar on the tasks board | '2026-05-28T22:54:11Z' | human |
| T-2019 | arc-007 S4d — drag-to-reorder kanban (cross-column status change) | '2026-05-28T22:54:11Z' | human |
| T-2020 | arc-007 S6d — cockpit live activity feed (recent commits, htmx poll) | '2026-05-28T22:54:11Z' | human |
| T-2021 | Cockpit System Health renders traceability as raw dict not percentage | '2026-05-28T22:54:11Z' | human |
| T-2022 | Cockpit System Health knowledge counts always zero (template reads missing | '2026-05-28T22:54:11Z' | human |
| T-2023 | arc-007 S3a — cockpit theme-respecting status pills (token-ize hardcoded status | '2026-05-28T22:54:11Z' | human |
| T-2024 | arc-007 S3a2 — cockpit inline-style hexes to semantic tokens | '2026-05-28T22:54:11Z' | human |
| T-2025 | arc-007 S3c — approvals page style block to semantic tokens | '2026-05-28T22:54:11Z' | human |
| T-2026 | arc-007 S3c2 — approvals content inline styles to semantic tokens | '2026-05-28T22:54:11Z' | human |
| T-2027 | arc-007 S5a — arcs pages semantic colour tokenisation | '2026-05-28T22:54:11Z' | human |
| T-2028 | arc-007 S5b — fabric coupling-note semantic colour (categorical-fixed) | '2026-05-28T22:54:11Z' | human |
| T-2029 | arc-007 S3b — cockpit density spacing (scale-multiply) | '2026-05-28T22:54:11Z' | human |
| T-2031 | dark-mode toggle invisible on light palettes (button --pico-color = accent-ink) | '2026-05-28T22:54:11Z' | human |
| T-2033 | arc-007 nav-layout polish — rail flyout clip, content overflow, sidebar gap, | '2026-05-28T22:54:11Z' | human |
| T-2034 | Move Arcs nav item from Architecture back to Work — human IA override of T-2008 | '2026-05-28T22:54:11Z' | human |
| T-2038 | approvals page renders 37000px tall — review queue has no pagination | '2026-05-28T22:54:11Z' | human |
| T-2039 | fabric page renders 33000px tall — same unbounded-list class as T-2038 | '2026-05-28T22:54:11Z' | human |
| T-2040 | inception board renders 83000px tall — unbounded card list (T-2038 class) | '2026-05-28T22:54:11Z' | human |
| T-2041 | timeline renders 90000px tall — unbounded grouped event lists (T-2038 class) | '2026-05-28T22:54:11Z' | human |
| T-2043 | /gaps renders 22000px tall — unbounded card list (T-2038 class) | '2026-05-28T22:54:11Z' | human |
| T-2044 | /learnings renders 67000px tall — unbounded table (T-2038 class) | '2026-05-28T22:54:11Z' | human |
| T-2045 | /decisions renders 13000px tall — unbounded table+list (T-2038 class) | '2026-05-28T22:54:11Z' | human |
| T-1806 | Resolver risk-policy preamble injection (dispatch-safety slice 2) | '2026-05-28T22:54:10Z' | human |
| T-1807 | Workflow schema lint — pause_threshold, allow_pause, pause_preamble (dispatch-sa | '2026-05-28T22:54:10Z' | human |
| T-1808 | Paused-dispatch surface — fw review-queue + Watchtower /approvals (dispatch-safe | '2026-05-28T22:54:10Z' | human |
| T-1810 | Watchtower paused-dispatch resolve form on /review/T-XXX — web parity for fw | '2026-05-28T22:54:10Z' | human |
| T-1811 | AC classification gap — [REVIEWER] prefix for reviewer-agent-verifiable ACs | '2026-05-28T22:54:10Z' | human |
| T-1818 | v2 peer-consult slice 1 framework-half — inbox.queued event subscriber + respond | '2026-05-28T22:54:10Z' | human |
| T-1827 | Pickup: Cross-hub relay stall: termlink-agents framework:pickup offsets 9+10 | '2026-05-28T22:54:10Z' | human |
| T-1834 | Purge MS_OAUTH client secret from framework git history — filter-repo commit | '2026-05-28T22:54:10Z' | human |
| T-1842 | fabric exclude: blindness — honor exclude in do_scan + do_drift (consumer Penelo | '2026-05-28T22:54:10Z' | human |
| T-1843 | T-1603 smarter hook + mirror-sync stderr capture (T-1829 build child) | '2026-05-28T22:54:10Z' | human |
| T-1844 | pre-commit secret scan hook — root-cause prevention for T-1828/T-1834 class | '2026-05-28T22:54:10Z' | human |
| T-1891 | CLAUDE.md governance rule — producer/consumer parity for hook bypass contracts | '2026-05-28T22:54:10Z' | human |
| T-1909 | Render arc_id badge on task surfaces — finish the T-1849 visibility job (kanban | '2026-05-28T22:54:10Z' | human |
| T-1910 | Arc page parity — read-only enrichment + inline editable name/focus + filters | '2026-05-28T22:54:10Z' | human |
| T-1911 | Watchtower /arcs/<slug>/close build — review surface, POST handler, CLI fw | '2026-05-28T22:54:10Z' | human |
| T-1928 | BVP T-NEW-12a: Watchtower /bvp static scatter read-only (split parent T-NEW-12) | '2026-05-28T22:54:10Z' | human |
| T-1929 | BVP T-NEW-12b: Watchtower /bvp live weight sliders + commit (split parent T-NEW- | '2026-05-28T22:54:10Z' | human |
| T-1930 | BVP T-NEW-13: Watchtower /arcs/<id> extensions — arc-level BVP, coherence warnin | '2026-05-28T22:54:10Z' | human |
| T-1933 | BVP T-NEW-15: canonical doc 040-ValueDrivers.md + FRAMEWORK.md glossary/Quick | '2026-05-28T22:54:10Z' | human |
| T-1934 | BVP T-NEW-12c: /bvp scatter renders proposed scores (advisory layer) | '2026-05-28T22:54:10Z' | human |
| T-1935 | BVP T-NEW-7c: bvp-cost-estimator — propose cost_estimate (blast_radius / tier | '2026-05-28T22:54:10Z' | human |
| T-1936 | BVP T-NEW-7d: arc-level BVP+cost rollup — render arc dots on /bvp scatter | '2026-05-28T22:54:10Z' | human |
| T-1939 | BVP T-1936/T-1937 sibling — /arcs/<slug> BVP signals use constituent rollup | '2026-05-28T22:54:10Z' | human |
| T-1947 | reviewer prose-quality mis-routing guard — REVIEWER necessary-but-not-sufficient | '2026-05-28T22:54:10Z' | human |
| T-1951 | G-066 deliverable #3 — reviewer TermLink-dispatch worker (evidence-gated, isolat | '2026-05-28T22:54:10Z' | human |
| T-1954 | BVP /bvp perf — 17.9s load time, cache _collect_task_points() or batch 1918 | '2026-05-28T22:54:10Z' | human |
| T-1955 | BVP /bvp?mode=proposed renders 0 tasks — T-1934 unfinished proposed-scatter | '2026-05-28T22:54:10Z' | human |
| T-1957 | arc-006 self-application — run BVP estimator on anchor T-1915 to populate propos | '2026-05-28T22:54:10Z' | human |
| T-1960 | arc Recommendation schema + auto-render on /arcs/<slug>/close | '2026-05-28T22:54:10Z' | human |
| T-1961 | /approvals ingestion of close-ready arcs — ARC CLOSURE section | '2026-05-28T22:54:10Z' | human |
| T-1963 | /arcs/<slug>/review route — read-only review surface (separate from /close) | '2026-05-28T22:54:10Z' | human |
| T-1964 | BVP driver add form — /api/bvp/driver/add POST + add-driver form below sliders | '2026-05-28T22:54:10Z' | human |
| T-1965 | BVP driver remove form — /api/bvp/driver/remove POST + per-row remove button | '2026-05-28T22:54:10Z' | human |
| T-1968 | Arc badge dark-on-dark contrast fix — color: var(--pico-secondary) → var(--pico- | '2026-05-28T22:54:10Z' | human |
| T-1969 | Arc badge unified form: render 'arc-NNN · slug' resolving the missing form | '2026-05-28T22:54:10Z' | human |
| T-1970 | Badge contrast sweep: fix .badge-info (invisible), .badge-ok (3.55), .badge-mute | '2026-05-28T22:54:10Z' | human |
| T-1971 | Remove stale 'Read-only — live weight sliders ship in T-1929' text on /bvp | '2026-05-28T22:54:10Z' | human |
| T-1976 | arc-scoped driver add/remove parity with global /bvp | '2026-05-28T22:54:10Z' | human |
| T-1977 | arc-scoped driver weight sliders — T-1929 parity at arc scope | '2026-05-28T22:54:10Z' | human |
| T-1978 | constituent task BVP columns on arc detail | '2026-05-28T22:54:10Z' | human |
| T-1980 | T-1978 sibling: show BVP scores/cost on task detail page (/tasks/T-XXX) | '2026-05-28T22:54:10Z' | human |
| T-1982 | show BVP badge on /tasks listing cards + list view — T-1980 sibling | '2026-05-28T22:54:10Z' | human |
| T-1984 | T-1983A: inception GO-scope traceability — schema + hook + close gate | '2026-05-28T22:54:10Z' | human |
| T-1985 | T-1950A reviewer auto-tick [REVIEWER] Agent ACs v1.0 — dogfood of T-1984 substra | '2026-05-28T22:54:10Z' | human |
| T-1988 | Watchtower /settings/appearance page — preset picker + foundation axes + sticky | '2026-05-28T22:54:10Z' | human |
| T-1989 | Watchtower nav restructure — flatten 16-item Govern group, top-bar + contextual | '2026-05-28T22:54:10Z' | human |
| T-1701 | v1 build: install + integrate pi RPC backend for worker_kind=pi dispatch | '2026-05-28T22:54:09Z' | human |
| T-1707 | fw doctor scope tagging — split project vs host findings (T-1702 Stream 2) | '2026-05-28T22:54:09Z' | human |
| T-1718 | Evolution-gate + vertical-slice discipline for inception → build transitions | '2026-05-28T22:54:09Z' | human |
| T-1773 | spawn-side dispatch driver: read resolver envelope → spawn worker → stream | '2026-05-28T22:54:09Z' | human |
| T-1774 | fw resolver run: CLI integration of spawn driver — one-line dispatch+spawn | '2026-05-28T22:54:09Z' | human |
| T-1775 | lib/ollama_loop.py — claude -p worker primitive (2nd worker_kind route) | '2026-05-28T22:54:09Z' | human |
| T-1792 | Watchtower /orchestrator: add Dispatch substrate panel — by_model breakdown | '2026-05-28T22:54:09Z' | human |
| T-1794 | Watchtower /orchestrator: extend Dispatch substrate panel with by_task_type | '2026-05-28T22:54:09Z' | human |
| T-1795 | Watchtower /orchestrator: extend Dispatch substrate panel with by_worker_kind | '2026-05-28T22:54:09Z' | human |
| T-1796 | Watchtower /orchestrator: add Outcome quality panel — verification pass/fail | '2026-05-28T22:54:09Z' | human |
| T-1797 | TermLink worker primitive — lib/termlink_worker.py wraps fw termlink dispatch | '2026-05-28T22:54:09Z' | human |
| T-1799 | Watchtower /orchestrator: add Workflow coverage panel — surface T-1798 audit | '2026-05-28T22:54:09Z' | human |
| T-1801 | extend Workflow coverage panel with missing-provider class — web parity for | '2026-05-28T22:54:09Z' | human |
| T-1802 | Workflow coverage panel: per-workflow last-dispatch timestamp — surface deprecat | '2026-05-28T22:54:09Z' | human |
| T-1803 | Workflow coverage audit: stale-workflow WARN class — workflows declared but | '2026-05-28T22:54:09Z' | human |
| T-1805 | pause_requested terminal_event class — substrate recognition (dispatch-safety | '2026-05-28T22:54:09Z' | human |
| T-2082 | T-2081 fix — add task_completed guard to review_acs_fragment polling endpoint | '2026-05-28T22:52:18Z' | human |

## horizon: next (1 tasks)

| Task | Name | Last update | Owner |
|------|------|-------------|-------|
| T-1776 | fallback-workflow contract gap — default.yaml declares worker_kind: TermLink | 2026-05-31T09:26:42Z | human |


## Re-running the migration

```
bin/migrate-horizon-null-completed.sh             # apply
bin/migrate-horizon-null-completed.sh --dry-run   # report only, no writes
```

The script is intentionally narrow: only touches `.tasks/completed/`, only nulls non-null horizon fields, preserves all other frontmatter ordering and content. Slice 3 (T-2162) adds an `agents/audit/audit.sh` rail that FAILs if `.tasks/completed/` ever again grows non-null horizon entries — that closes the maintenance loop.

## Related

- **T-2159** — parent inception (Q1=(b) derived-past chosen)
- **T-2160** — Slice 1: derived-past render + render-surface integration + invariant guard
- **T-2162** — Slice 3 (next): audit rail
- **.context/arcs/horizon-axis-hardening.yaml** — arc-009 record
