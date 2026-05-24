---
id: T-2015
name: "arc-007 S4a — slide-in dockable task side-panel (htmx read fragment)"
description: >
  arc-007 S4a — slide-in dockable task side-panel (htmx read fragment)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [watchtower, redesign, ui, tasks, arc:watchtower-redesign]
arc_id: watchtower-redesign
components: []
related_tasks: [T-1992, T-1987, T-2012, T-2013]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-24T08:00:43Z
last_update: 2026-05-24T08:00:43Z
date_finished: null
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
---

# T-2015: arc-007 S4a — slide-in dockable task side-panel (htmx read fragment)

## Context

arc-007 S4a — the keystone of the Tasks-board redesign (parent umbrella T-1992, inception
T-1987). Changes the core read interaction on `/tasks`: clicking a card/row opens the task
detail in a **slide-in dockable side panel** instead of a full-page nav to `/tasks/<id>`.

**Design decisions made during recon (2026-05-24):**
- The panel loads a **dedicated lean read fragment** (`_task_panel.html` via a new
  `/tasks/<id>/panel` route), NOT the full `task_detail.html`. Reason: `task_detail.html`'s
  inline scripts add a *document-level* `htmx:afterRequest` listener that would accumulate
  on every panel load (double-bind leak), and its desc-save reloads `#content` (the board,
  not the panel). That inline-edit machinery is S4b's job — S4a is the read keystone.
- The panel shell (`#wt-task-panel`) lives in `base.html` (OUTSIDE `#content`), so its
  click/dock/Esc listeners attach once and survive every htmx `#content` swap — the same
  shell-modal pattern proven in S6a (⌘K palette) and S6b (`?` overlay).
- Card/row links get `data-task-panel` + `hx-boost="false"`; the `href="/tasks/<id>"`
  stays as the no-JS full-page fallback. A single delegated click listener opens the panel.
- Dock choice (right/left/bottom/fullscreen) persists **per-browser** in the S1 prefs file
  (`.context/user-preferences/<uid>.yaml` under a `panel:` key), applied server-side as the
  panel's initial class — same read-modify-write pattern as `appearance:` (T-1988) and
  `pins:` (T-2010), so neither key clobbers the other. Mutual-exclusion with palette/overlay.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `/tasks/<id>/panel` route returns a lean read fragment (HTTP 200) containing the task id, name, status/owner/horizon metadata, and a Recommendation block when present — and does NOT contain the full-page inline-edit script (`startNameEdit`/`htmx:afterRequest`) (unit: test_task_panel.py::test_panel_fragment_is_lean_read_view)
- [x] The panel shell `#wt-task-panel` + `task-panel.js` are injected into every page via base.html (present on an arbitrary non-tasks page), so the open/dock/Esc listeners survive htmx swaps (unit: test_panel_shell_present_on_arbitrary_page)
- [x] Card-id and row-id links on `/tasks` carry `data-task-panel` and `hx-boost="false"` (panel JS owns the click; href is the no-JS fallback) (unit: test_board_links_open_panel_not_full_page)
- [x] Clicking a task card opens the slide-in panel with that task's detail loaded via htmx (no full-page nav — URL stays `/tasks`); Esc closes it (Playwright: test_click_card_opens_panel_no_full_page_nav)
- [x] The panel open/dock listeners still work after an htmx `#content` board refresh — open a panel, swap the board, open another panel (Playwright: test_panel_opens_after_htmx_board_swap)
- [x] Dock controls switch the panel between right/left/bottom/fullscreen; the choice persists across a fresh page load (per-browser prefs) (Playwright: test_dock_controls_switch_and_persist + unit: test_dock_pref_roundtrips_into_render)
- [x] Opening the ⌘K palette or `?` overlay closes the panel and vice-versa — no two shell modals stacked at once (Playwright: test_palette_closes_panel; symmetric close wired in command-palette.js / shortcuts-overlay.js open() + task-panel.js closeOthers())

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
- [ ] [REVIEW] The slide-in panel feels like a calm read surface, not a janky overlay — it slides in smoothly, the dock controls (right/left/bottom/fullscreen) read clearly, the detail content is legible at each dock position, and closing returns focus cleanly to the board.
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw serve` (or open the live Watchtower), go to `/tasks`
  2. Click a task card — confirm the panel slides in with that task's detail and the board stays put behind it
  3. Cycle the dock controls: right → left → bottom → fullscreen → close; reload the page and confirm the last dock position is remembered
  4. Open the ⌘K palette while the panel is open — confirm the panel closes (no stacked modals)
  5. Review the captured screenshot `web/static/ux-review/T-2015-task-panel.png`
  **Expected:** The panel reads as a polished, calm detail surface at every dock position; the dock affordances are obvious; nothing flickers, stacks, or traps focus.
  **If not:** Note which dock position or transition feels off (screenshot it) so it can be tuned before the panel pattern is reused in S4b/S4c.

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
# Live :3000 is NOT restarted by agents (caches templates) — verify against the
# Flask test_client (loads current code fresh), not the running server.
python3 -c "import ast; ast.parse(open('web/blueprints/tasks.py').read())"
python3 -c "import ast; ast.parse(open('web/blueprints/settings.py').read())"
python3 -m pytest tests/unit/test_task_panel.py -q 2>&1 | tail -3

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

### 2026-05-24 — panel content: lean fragment, not the full detail
- **What changed:** Recon showed `task_detail.html` is not safely reusable as a panel body. Its inline `<script>` registers a *document-level* `htmx:afterRequest` listener (would accumulate one extra listener per panel open) and its desc-save reloads `#content` (the board) via `window.location.pathname` — both correct for a full page, both broken inside a panel. The original T-1992 scoping note said "reuses the existing task_detail content as an htmx fragment" assuming that was a clean drop-in; it isn't.
- **Plan impact:** S4a ships a NEW lean read fragment (`_task_panel.html` + `/tasks/<id>/panel`) reusing the *data + render helpers* (extract_recommendation, _parse_acceptance_criteria, render_markdown_safe, BVP/arc helpers) but none of the editable widgets. Editing in the panel moves entirely to S4b.
- **Triggered:** Sharpened S4b's scope — it must wire inline-edit *into the panel* (idempotent, panel-scoped listeners), not just reuse task_detail's. No new task filed; captured here for the S4b carve.

### 2026-05-24 — open mechanism: event delegation + hx-boost="false", not per-link htmx
- **What changed:** The board's card/row id-links were `hx-get #content` full-page swaps. Rather than rewrite every link to target the panel, a single delegated click listener on `document` (shell-level) owns `[data-task-panel]` clicks. `hx-boost="false"` on the links stops hx-boost from ajax-swapping them, so the `href` degrades to a real full-page nav with JS off.
- **Plan impact:** Confirms the shell-modal pattern (S6a/S6b) generalises to *content-triggered* modals, not just keyboard-triggered ones — the delegated listener survives htmx swaps with zero re-binding (proven by test_panel_opens_after_htmx_board_swap).

## Decisions

### 2026-05-24 — dock persistence: server-side prefs, not localStorage
- **Chose:** Persist the dock choice in the per-browser prefs YAML (`panel.dock`) via a CSRF-guarded `/settings/panel-dock/save`, applied server-side as the panel's initial class.
- **Why:** Matches the stated AC ("persists per-browser like the S1 appearance prefs") AND avoids a wrong-dock flash on load — the dock class is in the server-rendered HTML, same render-time rationale as the S1 theme attribute. Read-modify-write of the full prefs dict so `appearance:`/`pins:` are never clobbered.
- **Rejected:** localStorage — simpler and CSRF-free, but applied only after JS runs, so the panel would flash in the default dock then jump. Also wouldn't match the established prefs pattern.

### 2026-05-24 — panel value whitelist
- **Chose:** `_save_panel_dock` whitelists against `PANEL_DOCKS`; any unknown value silently falls back to the default before touching storage.
- **Why:** Same whitelist-everything posture as `_sanitise_appearance` / pin endpoints — nothing untrusted reaches the YAML. Verified by test_dock_save_whitelists_and_requires_csrf.
- **Rejected:** Storing the raw POST value — would let a crafted request write arbitrary strings into the prefs file.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Recommendation

**Recommendation:** GO

**Rationale:** S4a — the keystone of the Tasks-board redesign — is complete and proven.
Clicking a card/row now opens a slide-in dockable side panel that loads the task detail
via htmx with no full-page nav, the dock choice persists per-browser, and the panel
coexists cleanly with the ⌘K palette and `?` overlay (one shell modal at a time). All 7
Agent ACs pass; the only open item is the `[REVIEW]` Human AC (visual/feel judgment on the
slide-in surface), which is sovereignty-reserved. This unblocks the rest of T-1992
(S4b inline-edit, S4c filter chips, S4e/S6c bulk) — they build on the panel + row model.

**Evidence:**
- New route `web/blueprints/tasks.py::task_panel` + lean fragment `web/templates/_task_panel.html` — returns a read-only detail with NO inline-edit script (avoids the document-listener leak; verified).
- Shell panel `#wt-task-panel` + dock CSS in `web/templates/base.html`; logic in `web/static/task-panel.js` (delegated, shell-level → survives htmx swaps).
- Dock persistence: `web/blueprints/settings.py` (`_load/_save_panel_dock`, `inject_panel`, `/settings/panel-dock/save`) — CSRF-guarded, value-whitelisted, applied server-side (no flash).
- Board links wired in `web/templates/tasks.html` (`data-task-panel` + `hx-boost="false"`, href = no-JS fallback).
- Tests: `tests/unit/test_task_panel.py` (6 pass) + `tests/playwright/test_task_panel.py` (5 pass). S6a/S6b regression after the mutual-exclusion edits: 14 unit + 13 Playwright pass.
- Eyes-on screenshot: `web/static/ux-review/T-2015-task-panel.png` (right-docked panel over the board).

## Updates

### 2026-05-24T08:00:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2015-arc-007-s4a--slide-in-dockable-task-side.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-dde70600
- **Timestamp:** 2026-05-24T08:08:48Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
