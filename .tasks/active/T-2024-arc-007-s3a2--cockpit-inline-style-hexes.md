---
id: T-2024
name: "arc-007 S3a2 — cockpit inline-style hexes to semantic tokens"
description: >
  arc-007 S3a2 — cockpit inline-style hexes to semantic tokens

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc:watchtower-redesign, ui, watchtower, cockpit]
components: []
related_tasks: [T-1990, T-1987, T-2023]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-24T11:07:19Z
last_update: 2026-05-24T11:07:19Z
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

# T-2024: arc-007 S3a2 — cockpit inline-style hexes to semantic tokens

## Context

arc-007 S3a (T-2023) tokenised the cockpit's *named status classes* (`.wt-badge-*`,
`.wt-queue-status.*`). The cockpit still carries ~18 hardcoded theme hexes in
**inline `style=` attributes and `.wt-card-*` border rules** that defeat the live
`/settings/appearance` palette (the human's 2026-05-24 "honour the selected preset"
decision). This slice maps those onto the foundation semantic tokens
(`--wt-success/--wt-warn/--wt-danger/--wt-info/--wt-muted/--wt-accent`) so every
remaining cockpit colour re-themes. Worked template: T-2023. One deliverable: the
cockpit's non-status inline hexes. Excluded: `#fff`/`#1a1a1a` text-on-pill contrast
foregrounds (intentional, not palette colours) and cockpit density/layout (S3b).

Hex → token map (13 sites): `.wt-card-amber/blue/green/red` borders, partial-scan
article border, action-summary card+counts (Tier0/GO/Human-AC), the five verdict
pills (GO/DEFER/NO-GO/NO-REC/?), the Strength line, the concerns counts (gaps/risks/
high), the stale-tasks line, and the Scan-Summary Risks heading.

## Acceptance Criteria

### Agent
- [x] `.wt-card-amber/blue/green/red` border-left rules use `var(--wt-warn/info/success/danger)` — no `#f9a825/#1565c0/#2e7d32/#c62828` in those rules
- [x] Action-summary card border + Tier0/GO/Human-AC count colours use tokens (`var(--wt-warn/info/accent)`); no `#f59e0b/#1565c0/#7c3aed` inline
- [x] All five verdict pills (GO/DEFER/NO-GO/NO-REC/?) use semantic-token backgrounds; no `#1b5e20/#e65100/#b71c1c/#0e7490/#616161` inline
- [x] Strength line, concerns counts (gaps/risks/high), stale-tasks line, and Risks heading use tokens; no `#2e7d32/#1565c0/#e65100/#c62828` remain in those inline styles
- [x] Unit test asserts the token rules are present and the old hexes are gone, and that `cockpit.html` still compiles
- [x] Playwright test proves a cockpit inline-styled element re-themes when `[data-wt-palette]` switches (computed colour changes), with an eyes-on review screenshot captured

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
- [ ] [REVIEW] Cockpit colours read cleanly under the selected palette and the verdict pills keep adequate text contrast
  **Steps:**
  1. Ensure the dev Watchtower is serving current templates (restart if needed): `cd /opt/999-Agentic-Engineering-Framework && bin/fw serve` (or restart the running instance — templates are cached)
  2. Open `$(bin/fw watchtower url)/` and switch palettes at `/settings/appearance` across `linen / stone / paper / bone / console`
  3. Watch the System Health "Strength" line, the concerns counts (Gaps/Risks/High), the "Action Required" card + its verdict pills (GO/DEFER/NO-GO/NO-REC/?), and the Needs-Decision amber cards
  **Expected:** Every coloured element shifts with the palette (nothing stuck at the old fixed amber/blue/green/red); the DEFER pill (now `--wt-warn`, often a light amber) keeps its `#1a1a1a` dark text and stays legible; success/danger/info/muted pills keep white text and stay legible in all five palettes
  **If not:** Note the palette + element where contrast fails; the pill text colour (`#fff` vs `#1a1a1a`) may need flipping for that token

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
python3 -m pytest tests/unit/test_cockpit_inline_tokens.py -q
python3 -c "from web.app import app; app.jinja_env.get_template('cockpit.html')"

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

### 2026-05-24 — inline-style hexes vs named-class hexes
- **What changed:** S3a (T-2023) tokenised the *named* status classes; the eyes-on
  pass for this slice confirmed the remaining cockpit colour lives almost entirely in
  per-element `style=` attributes (verdict pills, concerns counts, action-summary), not
  CSS rules. Same hex→token mechanic, but each is an individual inline edit — higher
  edit count, no `color-mix` tinting (these are solid prominence pills, kept solid).
- **Plan impact:** Confirms the S3a/S3a2 split was correct (one deliverable each). The
  `#fff`/`#1a1a1a` text foregrounds are deliberately *out* of scope — they are contrast
  colours, not palette colours; flipping them is a per-pill taste call left to [REVIEW].
- **Triggered:** No new sub-tasks. S3b (cockpit density/layout) remains the next slice;
  this slice closes the cockpit *colour* tokenisation.

## Decisions

### 2026-05-24 — warn-pill text contrast
- **Chose:** Map the DEFER verdict pill background to `--wt-warn` but set its text to
  `#1a1a1a` (dark), matching the `.wt-badge-warn` convention from T-2023; keep `#fff`
  on the success/danger/info/muted pills.
- **Why:** `--wt-warn` resolves to a light amber in several palettes (linen/bone), where
  white text would be illegible. Dark text on warn is the established cockpit pattern.
- **Rejected:** Uniform `#fff` on all pills (fails contrast on light warn); converting
  pills to `color-mix` tints like the queue pills (verdict pills are intentionally solid
  high-prominence indicators — tinting would weaken the GO/NO-GO signal).

## Recommendation

- **Recommendation:** GO
- **Rationale:** All 6 Agent ACs pass. The cockpit's remaining inline-style theme hexes
  (13 sites / ~18 occurrences) now reference foundation semantic tokens, so the whole
  cockpit honours the live `/settings/appearance` palette — the human's "honour the
  selected preset" decision. Only `#fff`/`#1a1a1a` text contrast foregrounds remain (by
  design). Re-theming is pinned by a unit test (token rules present, old hexes gone, no
  residual theme hexes, template compiles — 6 tests green) and a Playwright test (a live
  inline-token element changes computed colour across `paper`→`console`). Agent eyes-on
  under the `bone` palette confirmed pills/counts re-theme and stay legible.
- **Evidence:**
  - `web/templates/cockpit.html` — grep shows only `#fff`/`#1a1a1a` remain
  - `tests/unit/test_cockpit_inline_tokens.py` — 6 passed in 0.57s
  - `tests/playwright/test_cockpit_inline_tokens.py` — 2 passed (re-theme + screenshot)
  - `web/static/ux-review/T-2024-cockpit-inline-tokens.png` — eyes-on artefact (bone palette)
  - Reviewer R-b08e8778: Overall PASS, needs_human=no, findings none
- **Human [REVIEW] remaining:** contrast/taste across all 5 palettes (the one Human AC).

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

### 2026-05-24T11:07:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2024-arc-007-s3a2--cockpit-inline-style-hexes.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b08e8778
- **Timestamp:** 2026-05-24T11:11:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
