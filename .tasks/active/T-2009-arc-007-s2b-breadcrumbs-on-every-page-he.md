---
id: T-2009
name: "arc-007 S2b breadcrumbs on every page header (path-derived, htmx-fresh)"
description: >
  arc-007 S2b breadcrumbs on every page header (path-derived, htmx-fresh)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, redesign, ui, nav]
arc_id: watchtower-redesign
components: [tests/playwright/test_breadcrumb.py, tests/unit/test_breadcrumb.py, 
      web/shared.py, web/templates/base.html, web/templates/_breadcrumb.html, 
      web/templates/_wrapper.html]
related_tasks: [T-1989, T-1987, T-2008]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-23T16:12:02Z
last_update: '2026-08-16T22:24:03Z'
date_finished: 2026-05-25T22:46:44Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
cost_estimate_proposed:
  - ts: '2026-05-23T16:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-23T16:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2009: arc-007 S2b breadcrumbs on every page header (path-derived, htmx-fresh)

## Context

Second build sub-slice of **T-1989 (arc-007 S2 nav restructure)** — **S2b breadcrumbs**
(T-1989 AC #3). The design (`nav-patterns.jsx`, all three patterns) shows a breadcrumb trail in
the page header (e.g. *Work › Tasks › Board*). S2a (T-2008) landed the IA + Govern sub-grouping;
this slice adds the orientation trail.

**Derivation = path-based, not endpoint-based.** The breadcrumb is computed from the request URL's
first path segment matched against the actual URLs of nav leaves (`url_for(leaf)`), so it stays
correct for mixed blueprints (e.g. `discovery` serves both Knowledge and Govern pages) where a
blueprint-name heuristic would misfile. Shape: `[(Group, None), (Section, url|None), (detail, None)]`
where the last crumb is the current page (unlinked).
- `/tasks` → *Work › Tasks*
- `/tasks/T-2008` → *Work › Tasks*(link) › *T-2008*
- `/arcs/arc-007` → *Architecture › Arcs*(link) › *arc-007*
- `/` (home) and pages not under any nav section → no breadcrumb (better silent than misleading)

**htmx freshness.** The nav swaps `#content` (`hx-target="#content"`), and the existing ambient
strip (in `base.html`, outside `#content`) goes stale on htmx nav — an accepted limitation there,
but unacceptable for a breadcrumb that asserts "you are here". So the breadcrumb renders **inside
`#content`**: `_wrapper.html` includes it atop the content block for full loads, and `render_page`'s
htmx branch prepends the same partial to the returned fragment. Either way it is replaced on every
swap → always fresh. No new htmx-OOB machinery introduced.

**Files:** `web/shared.py` (path-prefix index + `nav_breadcrumb()` + context inject + htmx prepend),
`web/templates/_breadcrumb.html` (new partial), `web/templates/_wrapper.html` (include),
`web/templates/base.html` (breadcrumb CSS).

**Out of scope (later sub-slices):** pinned-pages model (S2c), sidebar/rail layouts + selector (S2d).
Review/settings pages (not in the main nav) intentionally get no breadcrumb in S2b.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `nav_breadcrumb(endpoint, path)` in `web/shared.py` derives crumbs from the URL's first path
      segment matched against nav-leaf URLs. Unit-tested for: list page (`/tasks` → Work › Tasks),
      detail page (`/tasks/T-x` → Work › Tasks › T-x), a mixed-blueprint page (`/gaps` → Govern › Gaps,
      not Knowledge), and home (`/` → empty).
- [x] The section crumb on a detail page is a working link to the section list (`url_for` resolves);
      the final crumb (current page) is unlinked.
- [x] Breadcrumb renders **inside `#content`** so it survives htmx navigation: `_wrapper.html`
      includes `_breadcrumb.html` for full loads AND `render_page`'s htmx branch prepends it — a
      Playwright test confirms the breadcrumb updates after an in-app htmx nav (no full reload).
- [x] A nested page (`/arcs/<id>` or `/tasks/<id>`) shows a 3-level trail; a top-level page shows a
      2-level trail; home shows none — verified by rendered DOM (not source grep, per T-1575).
- [x] `fw test unit` green (new breadcrumb unit test + existing nav/app tests); no regression in
      `web/test_app.py`.

### Human
<!-- [REVIEW] criteria — visual/UX taste, cannot be automated (render-surface gate P-013). -->
- [ ] [REVIEW] Breadcrumbs are accurate and aid orientation, and the strip sits cleanly in the page
      header (right weight, not competing with the page H1).
  **Steps:** 1. Open the Watchtower URL (`bin/fw watchtower url`)  2. Visit a nested page (e.g.
  `/arcs/arc-007`, `/tasks/<some T-id>`)  3. Read the trail; click the section crumb  4. Navigate a
  few pages via the top nav (htmx) and re-check the trail each time
  **Expected:** Trail reflects the real hierarchy (Group › Section › detail), the section crumb links
  to its list, the trail updates on every nav without a full reload, and the strip reads as quiet
  chrome above the content
  **If not:** Note the page and the wrong/missing/stale crumb, or the visual issue

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# breadcrumb derivation unit tests pass
python3 -m pytest tests/unit/test_breadcrumb.py -q 2>&1 | tail -3
# htmx-fresh breadcrumb Playwright test passes (isolated server on 3099)
python3 -m pytest tests/playwright/test_breadcrumb.py -q 2>&1 | tail -3
# no regression in nav/app tests
python3 -m pytest web/test_app.py -k nav -q 2>&1 | tail -2
# live page still 200
curl -sf "$(bin/fw watchtower url)/" >/dev/null && echo "live ok"

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

### 2026-05-23 — htmx freshness forced the breadcrumb inside #content
- **What changed:** The obvious place for a breadcrumb is the page header chrome, but Watchtower
  nav is htmx (`hx-target="#content"`) and chrome *outside* `#content` (the ambient strip) goes
  stale on htmx nav. A breadcrumb that asserts "you are here" cannot be stale, so it had to live
  *inside* `#content` and be re-rendered on every swap.
- **Plan impact:** Solved without introducing htmx-OOB: `_wrapper.html` includes the partial for full
  loads; `render_page`'s htmx branch prepends the same partial to the fragment. One partial, two call
  sites, always fresh. The Playwright test pins it with a window-marker reload check.
- **Triggered:** none.

### 2026-05-23 — path-based derivation beats blueprint-name
- **What changed:** Verified the `discovery` blueprint serves both Knowledge (Learnings…) and Govern
  (Gaps) pages. A blueprint→group map would misfile `/gaps` as Knowledge. Deriving from the URL's
  first path segment matched against `url_for(leaf)` resolves `/gaps` → Govern correctly.
- **Plan impact:** Confirms the chosen approach; the unit test pins the mixed-blueprint case so a
  future refactor can't regress it.
- **Triggered:** none.

### 2026-05-23 — verification artefacts
- **Unit (DOM + derivation):** `tests/unit/test_breadcrumb.py` — 6 tests (list/detail/nested/mixed/
  off-nav/home).
- **Executed-browser (htmx-fresh):** `tests/playwright/test_breadcrumb.py` — 4 tests, incl. the
  no-full-reload window-marker proof.
- **Human [REVIEW] artefact:** `web/static/ux-review/T-2009-breadcrumb.png` (web:
  `<watchtower-url>/static/ux-review/T-2009-breadcrumb.png`) — `/arcs/arc-007` showing
  *Architecture › Arcs › arc-007*.
- **Observation (not filed):** the arcs detail page also has a "← All arcs" back-link, now slightly
  redundant with the breadcrumb's linked *Arcs* crumb. Left for the human [REVIEW] to judge — not a
  blocker, and a separate per-page cleanup if wanted.

## Decisions

### 2026-05-23 — render breadcrumb inside #content (not OOB, not base.html chrome)
- **Chose:** Breadcrumb partial rendered inside `#content` via `_wrapper.html` (full load) +
  `render_page` htmx-prepend (htmx load).
- **Why:** Always fresh on htmx nav; no new OOB machinery; one partial reused at both call sites.
- **Rejected:** (a) base.html chrome outside `#content` — goes stale on htmx nav (the ambient-strip
  limitation), unacceptable for a "you are here" element. (b) htmx `hx-swap-oob` — works but adds a
  first-of-its-kind pattern to the codebase for no extra benefit here.

### 2026-05-23 — derive from URL path, not blueprint name
- **Chose:** Map the URL's first path segment → (group, section) using actual `url_for(leaf)` URLs.
- **Why:** Correct for mixed blueprints (`discovery` → both Knowledge and Govern).
- **Rejected:** Blueprint-name heuristic — misfiles `/gaps` (discovery blueprint, Govern group).

## Recommendation

- **Recommendation:** GO
- **Rationale:** All 5 Agent ACs pass. Breadcrumbs render on every nav section page, derive the real
  Group › Section › detail hierarchy from the URL, link the section to its list, and — the key
  property — stay fresh on htmx navigation (proven by a no-reload Playwright assertion). Home and
  off-nav pages correctly show nothing. One [REVIEW] AC remains: the *accuracy + visual weight* of
  the trail, which needs human taste.
- **Evidence:**
  - `tests/unit/test_breadcrumb.py` — 6 tests (incl. mixed-blueprint `/gaps` → Govern).
  - `tests/playwright/test_breadcrumb.py` — 4 tests (incl. htmx-fresh no-reload proof).
  - Screenshot: `web/static/ux-review/T-2009-breadcrumb.png` (web:
    `<watchtower-url>/static/ux-review/T-2009-breadcrumb.png`).
  - All `## Verification` commands green; `web/test_app.py` nav tests unchanged.
- **Note (deploy):** live `:3000` caches templates — new breadcrumb shows after the service restarts.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-23T16:12:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2009-arc-007-s2b-breadcrumbs-on-every-page-he.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-03cc4364
- **Timestamp:** 2026-05-25T22:48:13Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `nav_breadcrumb(endpoint, path)` in `web/shared.py` derives crumbs from the URL's first path
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/shared.py in: `nav_breadcrumb(endpoint, path)` in `web/shared.py` derives crumbs from the URL's first path`

### 2026-05-25T22:46:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
