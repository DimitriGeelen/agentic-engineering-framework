---
id: T-2013
name: "arc-007 S6b — keyboard-shortcuts overlay (? opens, lists live shortcuts)"
description: >
  arc-007 S6b — keyboard-shortcuts overlay (? opens, lists live shortcuts)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, redesign, ui, interactions, keyboard, arc:watchtower-redesign]
components: [tests/playwright/test_shortcuts_overlay.py, tests/unit/test_shortcuts_overlay.py, web/static/command-palette.js, web/static/shortcuts-overlay.js, web/templates/base.html]
related_tasks: [T-1993, T-1987, T-2012]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-23T19:44:20Z
last_update: 2026-05-26T06:48:07Z
date_finished: 2026-05-26T06:48:07Z
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
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-24T19:45:02Z'
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
---

# T-2013: arc-007 S6b — keyboard-shortcuts overlay (? opens, lists live shortcuts)

## Context

arc-007 S6b — the keyboard-shortcuts overlay. Carved from the T-1993 S6 umbrella;
follows S6a (T-2012, the ⌘K palette) which introduced the first real shortcuts. Now
that ⌘K/Esc/arrows exist, a `?`-press overlay can list them so the keyboard surface is
discoverable (you can't use shortcuts you don't know exist).

**Scope (S6b):** a read-only modal in the shell (`base.html`), opened by pressing `?`
(when focus is NOT in a text input — otherwise `?` types normally). Lists the live
shortcuts as key/description rows. Esc or a click on the backdrop closes it. Like S6a,
the modal + its document-level listener live in the shell, so they survive htmx
`#content` swaps. Self-contained: a static list (no backend), one small JS file.

The shortcut rows are the single source of truth for "what keys do something" — keep
them in sync with S6a as new shortcuts land (S6c/S6d may add more).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Pressing `?` outside any text input opens the shortcuts overlay; Esc closes it; works on a fresh load AND after an htmx `#content` swap (shell-level listener) — Playwright `test_shortcuts_overlay.py::test_open_close_fresh` + `::test_open_close_after_htmx_swap`
- [x] Pressing `?` while a text input/textarea is focused does NOT open the overlay (the character types normally) — Playwright `::test_question_mark_in_input_does_not_open`
- [x] The overlay lists the live shortcuts (⌘K palette, `?` help, Esc close, ↑/↓ move, Enter jump) as key/description rows — Playwright `::test_overlay_lists_live_shortcuts` + unit `::test_overlay_lists_every_documented_shortcut` (every documented shortcut description present)
- [x] The overlay markup is injected into every page via `base.html` (shell), present regardless of which `#content` page is loaded — unit `test_shortcuts_overlay.py::test_overlay_present_on_arbitrary_page` + `::test_overlay_is_hidden_by_default`
- [x] Opening the ⌘K palette and opening the `?` overlay are mutually exclusive — opening one while the other is open does not stack two modals — Playwright `::test_palette_and_overlay_do_not_stack`

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
- [ ] [REVIEW] The overlay reads as a clean, scannable cheat-sheet — the key chips are legible, the descriptions are clear, and the modal sits cleanly over the page in light + dark without jank.
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw serve` (or use the running :3000), open the Watchtower URL from `bin/fw watchtower url`
  2. Press `?` (no modifier, with focus on the page body) — the overlay should appear
  3. Read the rows; press Esc to close; toggle dark mode and re-open
  4. Review the screenshot `web/static/ux-review/T-2013-shortcuts-overlay.png`
  **Expected:** key chips (⌘K, ?, Esc, ↑↓, Enter) are crisp and aligned; descriptions are clear; modal centered/legible over the dimmed page in both themes.
  **If not:** note the row/theme that reads poorly, screenshot it.

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
python3 -m pytest tests/unit/test_shortcuts_overlay.py -q
out=$(grep -c "wt-shortcuts-overlay" web/templates/base.html); test "$out" -ge 1

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

### 2026-05-23 — S6b built immediately after S6a in the same session
- **What changed:** The T-1993 plan recommended "S6a → S6b" as separate sessions. With S6a shipped and budget headroom, S6b followed in-session — it's small (static list, no backend) and the shortcut list it documents only became non-empty once S6a landed.
- **Plan impact:** None — order preserved (S6a before S6b). The shortcut rows are now the canonical "what keys do something" list; S6c/S6d must update them when adding shortcuts.
- **Triggered:** Nothing new filed. S6c (bulk actions) still gated on T-1992; S6d (ticker) still last.

## Decisions

### 2026-05-23 — Shortcuts list is static markup, not derived from S6a's JS
- **Chose:** Hard-code the shortcut rows in the `base.html` overlay markup (a small `<dl>` of key→description), separate from `command-palette.js`.
- **Why:** The list is tiny and changes rarely; a static list is trivially testable (grep the rendered HTML) and needs no cross-file coupling. Deriving it from the palette JS would add machinery for no real benefit at this size.
- **Rejected:** A shared shortcut-registry module both S6a and S6b read — over-engineering for ~5 rows; revisit only if the shortcut count grows large (S6c/S6d).

### 2026-05-23 — `?` and ⌘K share the "one modal at a time" rule via a tiny shell helper
- **Chose:** A minimal `web/static/shortcuts-overlay.js` that, on open, first closes the palette if open (and the palette listener already toggles itself). Both check "is a text input focused?" before acting on a bare key.
- **Why:** Prevents two stacked modals; keeps each overlay's logic in its own file while honouring mutual exclusion. The input-focus guard stops `?` from hijacking typing in the palette/search box.
- **Rejected:** A single mega-handler for all shortcuts (couples S6b to S6a's internals; harder to slice independently).

## Recommendation

- **Recommendation:** GO
- **Rationale:** S6b makes the keyboard surface discoverable — `?` now lists every live shortcut S6a introduced, so users can find ⌘K instead of needing to be told. All 5 Agent ACs pass with test evidence; the overlay lives in the shell (survives htmx swaps), is guarded against firing while typing, and is mutually exclusive with the palette (no stacked modals). S6a regression suite re-run green after the 1-line mutual-exclusion edit. One [REVIEW] remains: confirm the cheat-sheet *reads* cleanly in light + dark (taste, not correctness).
- **Evidence:**
  - 3 unit tests (`tests/unit/test_shortcuts_overlay.py`) — overlay present on arbitrary page, every documented shortcut description present, hidden by default. All pass.
  - 6 Playwright tests (`tests/playwright/test_shortcuts_overlay.py`) — open/close fresh + after htmx swap, `?`-in-input guard, lists live shortcuts, palette/overlay mutual exclusion, screenshot. All pass.
  - S6a no-regression: `tests/{playwright,unit}/test_command_palette.py` re-run green (7 + 5) after the mutual-exclusion edit to `command-palette.js`.
  - Eyes-on screenshot `web/static/ux-review/T-2013-shortcuts-overlay.png` — five aligned key-chip rows, clear descriptions, centered legible modal over the dimmed page.
  - Implementation: shell overlay markup + CSS (web/templates/base.html), logic (web/static/shortcuts-overlay.js), 1-line mutual-exclusion guard (web/static/command-palette.js).

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

### 2026-05-23T19:44:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2013-arc-007-s6b--keyboard-shortcuts-overlay-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8db839cb
- **Timestamp:** 2026-05-26T06:48:18Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-26T06:48:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
