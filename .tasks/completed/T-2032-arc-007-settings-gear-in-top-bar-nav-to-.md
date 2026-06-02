---
id: T-2032
name: "arc-007 settings gear in top-bar nav to /settings/appearance"
description: >
  arc-007 settings gear in top-bar nav to /settings/appearance

status: work-completed
workflow_type: build
owner: agent
horizon: null
arc_id: watchtower-redesign
tags: [arc:watchtower-redesign, ui, watchtower, nav, bug]
components: []
related_tasks: [T-1987, T-1988, T-2008]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-24T14:54:01Z
last_update: '2026-05-29T09:45:04Z'
date_finished: 2026-05-24T17:15:00+02:00
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
  - ts: '2026-05-29T09:45:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2032: arc-007 settings gear in top-bar nav to /settings/appearance

## Context

User-reported (2026-05-24): "setting/apperance occurs nowhere in the menu, for setting
maybe gear icon?". The `/settings/appearance` page (shipped by T-1988) renders fine
(HTTP 200) but has **zero entry in the nav** — `NAV_GROUPS` (`web/shared.py`) has no
`/settings/*` item, so the page is reachable only by typing the URL. Fix: add a gear-icon
link in the top-bar action cluster (`base.html`, beside the search icon and theme toggle)
pointing at `url_for('settings.appearance_page')`. Mirrors the existing `.nav-search`
icon-link pattern; shares its CSS.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `base.html` top-bar action cluster contains a settings link: an `<li class="nav-settings">`
      whose `<a href>` resolves to `url_for('settings.appearance_page')` and carries a gear
      `<svg>` icon, placed in the search/toggle cluster.
- [x] The gear link is an `<a>` (not a `<button>`) using the shared `.nav-search`/`.nav-settings`
      icon CSS with `color: var(--wt-text)` — so it stays visible on every palette (T-2031 lesson:
      buttons re-derive `--pico-color` to white; `<a>` + `--wt-text` does not).
- [x] Unit test `tests/unit/test_settings_nav_link.py` passes: base.html contains the
      `nav-settings` link to `settings.appearance_page`; the gear `<svg>` is present.
- [x] `/settings/appearance` returns HTTP 200 (the link target is live, not orphaned).
- [x] Playwright test `tests/playwright/test_settings_nav_link.py` passes: the gear is visible in
      the top bar, and clicking it navigates to `/settings/appearance` (DOM assertion, not grep —
      T-1575). Screenshot artefact recorded in Evolution.
- [x] `base.html` still compiles (jinja `get_template`).

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->
- [ ] [REVIEW] The gear icon reads as "settings", sits naturally in the top-bar cluster, and is
      clearly visible on every palette × light/dark mode
  **Steps:**
  1. Open http://192.168.10.107:3000/ (cockpit) — the top bar, right side
  2. Look for the ⚙ gear icon beside the 🔍 search icon and ☾/☀ theme toggle
  3. Open http://192.168.10.107:3000/settings/appearance, switch palette to **Paper** then
     **Console**, mode **Light** then **Dark**, and re-check the gear each time
  4. Click the gear — it should land on the appearance page
  **Expected:** the gear is recognisably a settings affordance, balanced in the cluster (not
  cramped/misaligned), clearly visible in every palette/mode, and navigates to
  `/settings/appearance`
  **If not:** note the palette+mode where it's faint, or where the spacing/alignment looks off

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

# unit test: base.html has the nav-settings gear link to settings.appearance_page
out=$(cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/unit/test_settings_nav_link.py -q 2>&1); echo "$out" | tail -3; echo "$out" | grep -q "passed"
# base.html compiles and the route exists
python3 -c "import sys; sys.path.insert(0,'.'); from web.app import app; app.jinja_env.get_template('base.html'); assert any(r.endpoint=='settings.appearance_page' for r in app.url_map.iter_rules()), 'route missing'; print('ok')"
# link target is live (page returns 200)
curl -sf -o /dev/null "$(bin/fw watchtower url)/settings/appearance"

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

**Symptom:** the `/settings/appearance` page (palette/foundation picker) is reachable only by
typing the URL — it appears nowhere in the nav. User: "setting/apperance occurs nowhere in
the menu."

**Root cause:** T-1988 shipped the page and its blueprint route (`settings.appearance_page`)
but never added a corresponding nav affordance. `NAV_GROUPS` (`web/shared.py`) — the single
source of truth for the top-bar — has no `/settings/*` entry, and the top-bar action cluster
(search + theme toggle) was never extended with a settings link. The page existed; the
doorway to it did not.

**Why structurally allowed:** nothing asserts that a user-facing page is reachable from the
nav. Route registration (Flask url_map) and nav presence (`NAV_GROUPS` / action cluster) are
independent — a route can ship 200-OK while being an orphan in the IA. This is the same
"shipped the substrate, not the affordance" pattern as G-064 (orchestrator) at the UI layer:
the deliverable (page) shipped without the consumer-facing entry point. No audit/test cross-
checks "every primary page has a nav path".

**Prevention:** this task adds the affordance (gear → `settings.appearance_page`) and pins it
with a unit test (`base.html` contains the `nav-settings` link to the route) + a Playwright
click-through (gear visible → navigates to the page). The broader class — *orphaned primary
pages with no nav path* — is noted as a candidate detector (a test enumerating "primary"
endpoints and asserting each is reachable from `NAV_GROUPS` or the action cluster); deferred
as its own follow-up rather than scope-creeping this gear fix. Recorded in Evolution.

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

### 2026-05-24 — gear is an `<a>`, reusing the search-icon CSS (T-2031 lesson applied)
- **What changed:** The obvious mirror for the gear was the `.theme-toggle` `<button>`, but T-2031
  proved Pico re-derives `--pico-color`→white on buttons, making the icon vanish on light
  palettes. So the gear is an `<a>` (like `.nav-search`), and I extended the existing
  `.nav-search` CSS to `.nav-search, .nav-settings` rather than authoring a new rule — and set
  the shared colour to `var(--wt-text)` (was `--pico-color`), which is correct for `<a>` and
  immune to the button override.
- **Plan impact:** none — confirmed the approach; the Playwright contrast test reuses the
  exact T-2031 white-on-white probe on the gear so the nav-chrome regression class is now
  guarded on two icons, not one.
- **Triggered:** noted (not yet filed) a candidate **orphaned-page detector** — a test that
  enumerates "primary" endpoints and asserts each is reachable from `NAV_GROUPS` or the action
  cluster. This gear bug is the UI-layer instance of the G-064 "shipped substrate, not the
  consumer-facing affordance" pattern; the detector would catch the next orphaned page.

### 2026-05-24 — HTMX boost changes how navigation is tested
- **What changed:** `<body hx-boost="true">` makes every nav click an AJAX swap + history push,
  not a full page load. The first Playwright nav assertion failed because it waited for
  `domcontentloaded` (which never fires for a boosted swap) and read `page.url` before HTMX
  pushed the new URL. Fixed by `page.wait_for_url("**/settings/appearance")`.
- **Plan impact:** none functional — the gear navigates correctly; only the *test* needed the
  boost-aware wait. Worth remembering for future Watchtower nav Playwright tests.
- **Triggered:** none.

### 2026-05-24 — verification artefacts
- **Unit (T-1575 DOM, not grep-only):** `tests/unit/test_settings_nav_link.py` — 5 tests
  (link targets the route, gear svg present, is an `<a>` not `<button>`, route registered,
  template compiles).
- **Executed-browser guard (T-971):** `tests/playwright/test_settings_nav_link.py` — 4 tests
  (gear visible, navigates to `/settings/appearance`, contrasts the bar in paper/light, screenshot).
- **Human [REVIEW] artefact (screenshot):** `web/static/ux-review/T-2032-settings-gear-topbar.png`
  — the top-bar cluster showing 🔍 search · ⚙ gear · ☾ toggle. Web path:
  `<watchtower-url>/static/ux-review/T-2032-settings-gear-topbar.png`. Eyes-on confirmed the gear
  renders as a recognisable gear, well-spaced.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

- **Recommendation:** GO
- **Rationale:** All 6 Agent ACs pass. The orphaned page now has a doorway — a gear icon in the
  top-bar cluster (🔍 search · ⚙ gear · ☾ toggle) links to `/settings/appearance`. Built as an
  `<a>` reusing the proven search-icon CSS with `--wt-text`, so it dodges the T-2031 button-vanish
  bug; the contrast probe confirms it stays visible in paper/light. One [REVIEW] AC remains — the
  *taste* of the icon choice/placement and cross-palette visibility — which only the human can settle.
- **Evidence:**
  - `tests/unit/test_settings_nav_link.py` — 5 tests pass (link→route, gear svg, `<a>` not button,
    route registered, compiles).
  - `tests/playwright/test_settings_nav_link.py` — 4 tests pass (visible, navigates to
    `/settings/appearance`, contrasts bar in paper/light, screenshot).
  - Screenshot (eyes-on): `web/static/ux-review/T-2032-settings-gear-topbar.png` — gear renders as
    a recognisable gear, balanced beside search + toggle.
  - `/settings/appearance` returns HTTP 200; route `settings.appearance_page` registered.
- **Note (deploy):** the live Watchtower at `:3000` caches templates — the gear will appear only
  after the service restarts. The screenshot + isolated-port Playwright run prove the new render.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-24T14:54:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2032-arc-007-settings-gear-in-top-bar-nav-to-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-646afc33
- **Timestamp:** 2026-06-02T15:00:50Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
