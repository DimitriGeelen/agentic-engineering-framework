---
id: T-2012
name: "arc-007 S6a — command palette core (⌘K jump + search fall-through)"
description: >
  arc-007 S6a — command palette core (⌘K jump + search fall-through)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, redesign, ui, interactions, command-palette, 
      arc:watchtower-redesign]
components: [tests/playwright/test_command_palette.py, 
      tests/unit/test_command_palette.py, web/blueprints/settings.py, 
      web/shared.py, web/static/command-palette.js, web/templates/base.html]
related_tasks: [T-1993, T-1987, T-2011, T-2010]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-23T19:32:08Z
last_update: '2026-05-28T22:54:11Z'
date_finished: 2026-05-26T06:47:14Z
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
  - ts: '2026-05-23T19:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-23T19:45:02Z'
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
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2012: arc-007 S6a — command palette core (⌘K jump + search fall-through)

## Context

arc-007 S6a — the **keystone** of the interaction layer (S6, T-1993). The redesigned
nav (S2, T-1989) deliberately defers "everything not pinned" to ⌘K: the **icon-rail
layout (S2d, T-2011) is only fully usable once ⌘K exists** — the rail shows 4 group
flyouts + pins, and ⌘K is the escape hatch for the other ~30 destinations. Design
reference: the "Search or jump to… ⌘K" bar in all three nav patterns in
`docs/design/watchtower-redesign-2026-05-13/project/nav-patterns.jsx`.

Carved from the T-1993 S6 umbrella (which bundled 4 deliverables — S6a palette, S6b
`?`-overlay, S6c bulk actions, S6d ticker), mirroring how T-2011 was carved from the
T-1989 S2 umbrella. **This task ships S6a only.**

**Scope (S6a):** a modal command palette in the shell (`base.html`), opened by ⌘K /
Ctrl-K and by clicking the existing nav-search affordance. A single input that does
two things:
1. **Jump** — client-side fuzzy match over `web.shared.NAV_ITEMS` (the same whitelist
   S2c pins use), arrow-key selection, Enter navigates via htmx `#content` swap.
2. **Search fall-through** — a "Search '<query>' in all content →" row that routes to
   the existing `discovery.search_view` backend (`/search?q=`). No second search
   implementation — the palette is a jump tool + a doorway to the existing search page.

Esc closes. Because the modal + its document-level keydown listener live in the shell
(not inside `#content`), they survive htmx swaps without re-binding — the htmx-friendly
design the AC requires.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] ⌘K / Ctrl-K opens the palette modal and Esc closes it, on a fresh load AND after an htmx `#content` swap (the listener lives in the shell, attached once) — verified by Playwright `test_command_palette.py::test_open_close_fresh` and `::test_open_close_after_htmx_swap`
- [x] Clicking the existing nav-search affordance opens the same palette (not a navigation to `/search`) — Playwright `::test_nav_search_click_opens_palette`
- [x] Typing a nav-destination fragment fuzzy-matches `web.shared.NAV_ITEMS`; ArrowDown/ArrowUp move the highlighted result and Enter navigates to it (htmx swap of `#content`, URL updates) — Playwright `::test_fuzzy_jump_arrow_enter`
- [x] The jump list is exactly the `NAV_ITEMS` whitelist resolved to URLs (no destination outside the nav whitelist) — unit `test_command_palette.py::test_palette_jump_list_is_nav_items` + `::test_nav_items_json_payload_parses_and_matches_whitelist` (the `wt-nav-items` JSON payload's labels == `NAV_ITEMS` labels) + Playwright `::test_jump_targets_are_whitelisted_nav_destinations`
- [x] When the query matches no nav destination (or always, as the last row), a "Search '<query>' in all content" row routes to `discovery.search_view` (`/search?q=<query>`) — no second search backend — Playwright `::test_search_fallthrough_routes_to_discovery`
- [x] The palette markup is injected into every page via `base.html` (shell), so it is present regardless of which `#content` page is loaded — unit `::test_palette_present_on_arbitrary_page` (GET `/tasks` HTML contains the palette root id)

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
- [ ] [REVIEW] The palette feels like a fast keyboard-first jump tool — opens instantly on ⌘K, the input is focused, fuzzy results read sensibly (closest match on top), and the modal sits cleanly over the page in all six palettes/themes without layout jank.
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw serve` (or use the running :3000), open the Watchtower URL from `bin/fw watchtower url`
  2. Press ⌘K (mac) / Ctrl-K (linux/win) — the palette should appear with the input already focused
  3. Type a few letters of a page name (e.g. "lear" for Learnings); use ↓/↑ then Enter to jump
  4. Re-open, type a content phrase, pick the "Search '…' in all content" row
  5. Review the captured screenshots in `web/static/ux-review/T-2012-palette-*.png`
  **Expected:** opens instantly, input focused, top result is the closest match, Enter navigates, Esc closes; modal is centered/legible over the dimmed page in light + dark.
  **If not:** note which palette/theme janks or which match ranking feels wrong, screenshot it.

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
python3 -m pytest tests/unit/test_command_palette.py -q
python3 -c "from web.shared import NAV_ITEMS; assert len(NAV_ITEMS) > 5, 'NAV_ITEMS whitelist empty'; print('NAV_ITEMS:', len(NAV_ITEMS))"
out=$(grep -c "wt-command-palette" web/templates/base.html); test "$out" -ge 1

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

### 2026-05-23 — S6a carved from S6 umbrella; search fall-through scoped as a doorway, not inline results
- **What changed:** T-1993 (S6) bundled 4 deliverables. At build start it was decomposed; this task is S6a (the palette core) only — the keystone that unblocks the rail nav (S2d/T-2011). The other three (S6b `?`-overlay, S6c bulk actions after T-1992, S6d ticker) stay in T-1993 for later slices.
- **Plan impact:** The AC phrase "falls through to the existing `discovery.search` backend" is realised as a **route to `/search?q=`** (a doorway), not inline JSON results in the palette. Inline results would need a new JSON API + result rendering + their own tests — scope creep beyond the keystone. The rail is unblocked by *jump*; search-as-doorway fully reuses the existing backend with zero new search code.
- **Triggered:** Inline palette search results noted as a possible S6a follow-on (not filed — only file if the doorway proves insufficient in review).

## Decisions

### 2026-05-23 — Palette lives in the shell (base.html), not in #content
- **Chose:** Inject the modal markup + a document-level keydown listener once, in `base.html` (the shell that wraps `#content`). A static `web/static/command-palette.js` holds the logic.
- **Why:** htmx swaps replace `#content` only. A listener bound in the shell survives every swap with no re-binding — directly satisfies the "works after htmx swap" AC. Matches the S2 pattern (nav + breadcrumb + pins all live in the shell).
- **Rejected:** Per-page palette include (would re-bind on every swap, leak listeners, and break the ⌘K binding mid-session).

### 2026-05-23 — Jump list is NAV_ITEMS resolved to URLs, emitted as a JSON script tag
- **Chose:** Render `web.shared.NAV_ITEMS` (already in render_page context as `nav_items`) into a `<script type="application/json" id="wt-nav-items">` as `[{label, url, group}]`, resolving `url_for` server-side. The palette JS reads + fuzzy-matches it client-side.
- **Why:** Reuses the exact whitelist S2c pins use (one source of truth for "jumpable destinations"); URLs resolved server-side avoid a client-side url_for. Client-side fuzzy match = zero round-trips, instant keyboard feel.
- **Rejected:** A `/api/palette/destinations` endpoint (unnecessary round-trip; the list is small and already in context).

## Recommendation

- **Recommendation:** GO
- **Rationale:** S6a ships the keystone the icon-rail nav (S2d/T-2011) explicitly defers to — ⌘K now provides keyboard-first access to every nav destination plus a doorway into the existing search backend. All 6 Agent ACs pass with test evidence; the modal lives in the shell so it survives htmx swaps (proven E2E); the jump list is provably the same `NAV_ITEMS` whitelist pins use (no new attack surface, no second search impl). One [REVIEW] remains: confirm the palette *feels* fast and reads cleanly across all six palettes/themes (taste, not correctness).
- **Evidence:**
  - 5 unit tests (`tests/unit/test_command_palette.py`) — jump list == NAV_ITEMS whitelist, JSON payload parses + matches, palette present on arbitrary page, nav-search affordance marked as opener. All pass.
  - 7 Playwright tests (`tests/playwright/test_command_palette.py`) — open/close fresh + after htmx swap, nav-search click opens (no /search nav), fuzzy jump with arrow+Enter, whitelisted jump targets, search fall-through routes to `/search?q=`, screenshot capture. All pass.
  - Eyes-on screenshot `web/static/ux-review/T-2012-palette-open.png` — "lear" ranks Learnings top with its Knowledge group tag; italic search fall-through row beneath; modal centered + legible over the dimmed page.
  - Verification block (3 commands) green: pytest, NAV_ITEMS count (31), palette markup present in base.html.
  - Implementation: `palette_destinations()` (web/shared.py), `inject_palette` context processor (web/blueprints/settings.py), shell modal + CSS + JSON tag (web/templates/base.html), logic (web/static/command-palette.js).

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-23T19:32:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2012-arc-007-s6a--command-palette-core-k-jump.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ba6482f7
- **Timestamp:** 2026-05-26T06:47:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-26T06:47:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
