---
id: T-2010
name: "arc-007 S2c pinned-pages model — star nav destinations, surface in top bar,
  persist per-user"
description: >
  arc-007 S2c pinned-pages model — star nav destinations, surface in top bar, persist
  per-user

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, redesign, ui, nav, arc:watchtower-redesign]
arc_id: watchtower-redesign
components: [tests/playwright/test_pins.py, tests/unit/test_pins.py, 
      web/blueprints/settings.py, web/shared.py, web/templates/base.html, 
      web/templates/_breadcrumb.html, web/templates/_pins.html, 
      web/templates/_star.html]
related_tasks: [T-1989, T-1987, T-1988]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-23T17:08:45Z
last_update: '2026-05-28T22:54:11Z'
date_finished: 2026-05-25T22:48:25Z
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
  - ts: '2026-05-23T17:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-23T17:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F1: 1
      F2: 0
    rationale: "D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 (body:default-change);
      D4=2 (body:env-class-handled); F1=1 (body/tag hits for 'F1': 1); F2=0 (no-signal)"
    rubric_sha: e4a00f38e801
---

# T-2010: arc-007 S2c pinned-pages model — star nav destinations, surface in top bar, persist per-user

## Context

arc-007 S2c, third sub-slice of the T-1989 nav restructure (parent inception T-1987).
Implements T-1989 **AC #4**: "a page can be starred/unstarred and pinned pages surface in
the primary nav; persists across navigation." The design (`docs/design/watchtower-redesign-2026-05-13/`)
calls for user-pinned favourites in the top bar so frequently-visited destinations don't
require opening a group dropdown every time.

**Approach (reuses S1, T-1988 infrastructure):**
- **Pinnable set = nav-leaf endpoints** (`web/shared.py:NAV_ITEMS`). This is the security
  whitelist — same pattern as S1's `_sanitise_appearance` axis whitelist. Detail pages
  (e.g. `/tasks/T-2008`, endpoint `tasks.task_detail`) are NOT in NAV_ITEMS → not pinnable;
  nav destinations (`/tasks`, `/arcs`, …) are. This matches "pinned pages surface in primary nav."
- **Persistence = the S1 per-browser prefs file** (`.context/user-preferences/{uid}.yaml`,
  signed-cookie UID via `_wt_uid()`). Adds a `pins:` list alongside the existing `appearance:`
  key. **Refactor required:** the current `_save_appearance` does `yaml.dump({"appearance": …})`
  which clobbers the whole file — so appearance + pins must share a read-modify-write of the
  full prefs dict, or one wipes the other (Decisions §).
- **Star toggle** lives in the breadcrumb bar (`_breadcrumb.html`) — already rendered inside
  `#content`, so it stays htmx-fresh on navigation (L-425). **Pinned strip** (`#wt-pins`) lives
  in the top nav (`base.html`). The toggle POST returns the new button + an `hx-swap-oob`
  refresh of `#wt-pins` — updates the top-bar strip without a full reload (the L-425 pattern).

L-013 noted: pins key off the same signed-cookie UID as appearance, so a `secret_key`
rotation drops both — accepted tradeoff, identical to S1.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] A nav-leaf page (e.g. `/tasks`) renders a pin toggle in the breadcrumb bar; a non-nav page (home `/`, off-nav `/settings/appearance`) renders no toggle (pinnable set = `NAV_ITEMS` endpoints) — `pin_state_for()` returns None off-nav; unit `test_pin_state_for_reflects_membership` + Playwright `test_star_present_on_nav_page_absent_on_home`
- [x] `POST /settings/pins/toggle` with a valid nav endpoint toggles its pinned state and returns 200; an endpoint NOT in `NAV_ITEMS` returns 400 (whitelist enforced server-side) — unit `test_toggle_route_with_csrf_returns_oob_strip` + `test_toggle_route_rejects_non_nav_endpoint`
- [x] Pinned pages persist in `.context/user-preferences/{uid}.yaml` under a `pins:` key AND coexist with `appearance:` — saving appearance does not wipe pins and toggling a pin does not wipe appearance (regression guard for the read-modify-write refactor) — unit `test_saving_appearance_does_not_wipe_pins` + `test_toggling_pin_does_not_wipe_appearance`
- [x] Pinned pages render in the top nav (`#wt-pins`) on every full page load and survive htmx navigation; a pin toggle refreshes `#wt-pins` via `hx-swap-oob` without a full reload (Playwright: window marker survives) — `test_pin_updates_nav_without_reload` (`window.__wt_no_reload` survives) + `test_pin_persists_across_nav_and_reload`
- [x] Unit test (`tests/unit/test_pins.py`, 10 tests) covers toggle add/remove, whitelist rejection, and appearance/pins coexistence; Playwright test (`tests/playwright/test_pins.py`, 5 tests) covers star→appears-in-nav→persists-across-nav→unpin and captures `web/static/ux-review/T-2010-pins.png`

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
- [ ] [REVIEW] The pin toggle and pinned-nav strip read cleanly and feel intuitive
  **Steps:**
  1. Open the Watchtower URL (`bin/fw watchtower url`) — note: live :3000 caches templates, so review after the human restarts it, or view the captured screenshot at `web/static/ux-review/T-2010-pins.png`
  2. Open a few nav pages (Tasks, Arcs, Learnings); click the pin toggle in the breadcrumb bar on 2-3 of them
  3. Confirm pinned pages appear as quick-links in the top bar; click one to navigate; unpin one
  **Expected:** The star toggle is discoverable and its pinned/unpinned state is obvious; the top-bar pinned strip reads as useful shortcuts (not clutter) and updates immediately on pin/unpin
  **If not:** Note which control is unclear or where the strip crowds the nav

## Verification
out=$(cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/unit/test_pins.py -q 2>&1); echo "$out" | tail -3; echo "$out" | grep -q "passed"
out=$(cd /opt/999-Agentic-Engineering-Framework && python3 -c "import ast; ast.parse(open('web/blueprints/settings.py').read()); ast.parse(open('web/shared.py').read()); print('ok')" 2>&1); echo "$out" | grep -q "ok"
out=$(cd /opt/999-Agentic-Engineering-Framework && python3 -c "from web.app import app; c=app.test_client(); r=c.get('/tasks'); print(r.status_code)" 2>&1); echo "$out" | grep -q "200"

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

### 2026-05-23 — S2c build
- **What changed:** The S1 `_save_appearance` was discovered to dump only `{"appearance": …}`,
  which would silently wipe a sibling `pins:` key. The plan had assumed pins could just be added
  alongside; in reality the persistence layer needed a read-modify-write refactor first
  (extracted `_load_prefs`/`_save_prefs`). This is a latent S1 bug surfaced by adding the second
  prefs consumer — captured as a regression test, not just a fix.
- **Plan impact:** None to scope. The whitelist-the-set security pattern (S1's `_sanitise_appearance`)
  transferred cleanly to pins (`_valid_pin_endpoints` = NAV_ITEMS membership), so no new attack
  surface analysis was needed.
- **Triggered:** No new sub-tasks. S2d (sidebar/icon-rail layouts + `data-wt-nav` selector) remains
  the last open S2 sub-slice on the T-1989 umbrella.

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

## Decisions

### 2026-05-23 — Prefs persistence: read-modify-write the full dict
- **Chose:** Extract `_load_prefs`/`_save_prefs` (whole-dict) and route both `appearance:` and
  `pins:` writes through them.
- **Why:** Two independent consumers now share one per-browser file. A key-scoped dump clobbers
  the other key. RMW is the minimal correct fix and pins it with a coexistence regression test.
- **Rejected:** Separate files per concern (`{uid}.appearance.yaml`, `{uid}.pins.yaml`) — doubles
  the path-safety surface and the UID-glob bookkeeping for no benefit at this scale.

### 2026-05-23 — Star toggle in the breadcrumb bar, not a per-page button
- **Chose:** Render the pin toggle inside `_breadcrumb.html` (already inside `#content`), and
  refresh the top-bar `#wt-pins` strip via `hx-swap-oob` from the toggle response.
- **Why:** The breadcrumb is the page-context chrome and is already htmx-fresh (L-425). Reusing it
  means the star is correct on every navigation for free; oob keeps the out-of-`#content` strip in
  sync without a reload.
- **Rejected:** Putting the toggle in each page template — would require touching ~20 templates and
  re-solving freshness per page. Rejected: a full-reload after toggle — defeats the htmx SPA feel.

### 2026-05-23 — Pinnable set = nav leaves (NAV_ITEMS), not arbitrary URLs
- **Chose:** Only endpoints in `NAV_ITEMS` are pinnable; detail pages are not.
- **Why:** Matches the AC ("pinned pages surface in primary nav" — they are nav destinations) and
  gives a closed whitelist that doubles as the security boundary (no untrusted endpoint reaches
  `url_for`). Mirrors S1's axis-whitelist pattern.
- **Rejected:** Pinning any URL (incl. task-detail pages) — unbounded set, weaker security story,
  and clutters the nav with one-off deep links.

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
- **Rationale:** All 5 Agent ACs are satisfied with executed-test evidence. The pinned-pages model
  ships AC #4 of the T-1989 umbrella: star a nav destination from the breadcrumb bar, it appears as
  a quick-link in the top bar, persists per-browser across navigation and hard reload, and unpins
  cleanly. The one [REVIEW] is genuine visual taste (does the strip read as useful, not clutter) —
  the eyes-on screenshot confirms it reads cleanly, but the call is the human's.
- **Evidence:**
  - `tests/unit/test_pins.py` — 10/10 pass: whitelist rejection, toggle add/remove, the
    appearance↔pins coexistence regression (both directions), and the CSRF route contract
    (403 without token, 200 + oob strip with).
  - `tests/playwright/test_pins.py` — 5/5 pass on the isolated :3099 harness: star present on nav
    pages / absent on home; pin updates the nav with **no full reload** (`window.__wt_no_reload`
    marker survives the oob swap); persistence across htmx-nav **and** hard reload; unpin removes.
  - Screenshot reviewed by eye: `web/static/ux-review/T-2010-pins.png` — `★ Tasks` quick-link in
    the top bar, `★ Pinned` toggle right-aligned in the breadcrumb. Clean, uncluttered.
  - Latent S1 bug fixed in passing: `_save_appearance` no longer clobbers sibling prefs keys
    (read-modify-write via `_load_prefs`/`_save_prefs`).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-23T17:08:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2010-arc-007-s2c-pinned-pages-model--star-nav.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5f18d7f0
- **Timestamp:** 2026-05-25T22:48:37Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 1

**Per-AC findings:**

- **AC#5 (Agent)** — Unit test (`tests/unit/test_pins.py`, 10 tests) covers toggle add/remove, whitelist rejection, and appearance/pins coexistence; Playwright test (`tests/playwright/test_pins.py`, 5 tests) covers star→a
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/static/ux-review/T-2010-pins.png in: Unit test (`tests/unit/test_pins.py`, 10 tests) covers toggle add/remove, whitelist rejection, and appearance/pins coexistence; Playwright test (`test`

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `wipe`

### 2026-05-25T22:48:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
