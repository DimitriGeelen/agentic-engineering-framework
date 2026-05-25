---
id: T-2026
name: "arc-007 S3c2 — approvals content inline styles to semantic tokens"
description: >
  arc-007 S3c2 — approvals content inline styles to semantic tokens

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [arc:watchtower-redesign, ui, watchtower, approvals]
components: [tests/playwright/test_approvals_content_tokens.py, tests/unit/test_approvals_content_tokens.py, web/templates/_approvals_content.html]
related_tasks: [T-1990, T-1987, T-2023, T-2024, T-2025]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-24T11:27:06Z
last_update: 2026-05-25T22:43:10Z
date_finished: 2026-05-25T22:43:10Z
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
  - ts: '2026-05-24T11:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-24T11:30:02Z'
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

# T-2026: arc-007 S3c2 — approvals content inline styles to semantic tokens

## Context

Completes the approvals-page tokenisation started in S3c (T-2025 = `approvals.html`
`<style>` block). This slice covers `_approvals_content.html` — the **inline-styled**
elements (~39 hexes): the agent verdict pills (3 blocks: inception / arc-closure /
partial-complete), the reviewer mechanical badges (2), the recommendation-summary
decision text, the "no recommendation" fallback box, the severity spans (high/med/low),
the GO/DEFER/NO-GO/NO-REC/review/rubber-stamp/stale filter buttons, the stale-age span,
and the batch-complete / complete-task submit buttons. All map onto foundation tokens so
the page honours the live `/settings/appearance` palette (honour-selected-preset).

Restyle ONLY — no markup, no buttons, no decision logic; approvals is a sovereignty
surface and this slice must NOT add bulk-decision UX. Worked precedent: T-2024 (verdict
pills, DEFER→warn gets `#1a1a1a` dark text), T-2025 (color-mix tints). One deliverable:
`_approvals_content.html` inline styles. Verdict-pill mapping: GO/CLOSE→success,
DEFER→warn (dark text), NO-GO→danger, NO-REC→info, KEEP-OPEN/?→muted; reviewer
good→success / bad→danger; severity high→danger, med→warn, low→muted.

## Acceptance Criteria

### Agent
- [x] All three verdict-pill blocks (inception / arc-closure / partial-complete) use semantic-token backgrounds (DEFER→`--wt-warn` with `#1a1a1a` text); no `#1b5e20/#e65100/#b71c1c/#0e7490/#616161` literals
- [x] Reviewer badges (2) use `var(--wt-danger)` (bad) / `var(--wt-success)` (good); no `#7f1d1d/#14532d` literals
- [x] Recommendation decision text + severity spans use tokens; no `#10b981/#ef4444/#6b7280/#f59e0b` literals in those rules
- [x] The "no recommendation" fallback box + stale-age spans use tokens / `color-mix`; no `#f59e0b…/#b45309/#e65100` literals there
- [x] All filter buttons (go/defer/nogo/norec/unknown/review/rubber-stamp/stale) use `var(--wt-*)` border+text; no hardcoded hexes
- [x] Batch-complete + complete-task submit buttons use `var(--wt-success)`; no `#10b981` literals
- [x] No hardcoded theme hex remains in `_approvals_content.html` (grep clean — only `#fff`/`#1a1a1a` contrast foregrounds + HTML entities)
- [x] Unit test asserts token usage + old hexes gone + template compiles; Playwright proves a content element re-themes on `[data-wt-palette]` switch with an eyes-on screenshot

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
- [ ] [REVIEW] Approvals content reads cleanly under the selected palette; verdict pills, filter buttons, and severity tags keep contrast and the GO/NO-GO/DEFER signal stays unambiguous
  **Steps:**
  1. Ensure the dev Watchtower serves current templates (restart if needed): `cd /opt/999-Agentic-Engineering-Framework && bin/fw serve` (templates are cached)
  2. Open `$(bin/fw watchtower url)/approvals` and switch palettes at `/settings/appearance` across `linen / stone / paper / bone / console`
  3. Check the agent verdict pills (GO/DEFER/NO-GO/NO-REC), the arc-closure pills, the filter-button row (GO/DEFER/NO-GO/Review/Rubber-stamp/Stale), severity tags ([HIGH]/[MED]/[LOW]), and the green submit buttons
  **Expected:** Everything re-themes; the DEFER pill (`--wt-warn`) keeps `#1a1a1a` dark text and stays legible; GO reads green, NO-GO reads red — the recommendation signal must never be ambiguous on a sovereignty surface; filter-button outline text stays readable in all five palettes
  **If not:** Note the palette + element; a pill text colour (`#fff` vs `#1a1a1a`) may need flipping, or a filter outline may need a contrast tweak

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
python3 -m pytest tests/unit/test_approvals_content_tokens.py -q
python3 -c "from web.app import app; app.jinja_env.get_template('_approvals_content.html')"

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

### 2026-05-24 — verdict pills now share one source of truth across 5 surfaces
- **What changed:** The same GO/DEFER/NO-GO/NO-REC/? verdict-pill colour vocabulary is
  now tokenised in the cockpit (T-2024) AND all three approvals blocks (this slice) AND
  the filter buttons. Five render sites, one token set — a verdict's colour is now defined
  once (the foundation token) instead of copy-pasted hexes that drift (cf. L-312 cross-
  surface count divergence — same class, colour edition).
- **Plan impact:** Closes the approvals page colour work (S3c + S3c2). S3b (cockpit
  density) and T-1994 (Fabric+Arcs) remain.
- **Triggered:** No new sub-tasks; approvals page colour tokenisation complete.

## Decisions

### 2026-05-24 — filter buttons keep outline (token text), pills keep fill (DEFER dark text)
- **Chose:** Filter buttons stay outline — `border-color` + `color` both `var(--wt-X)` on
  transparent bg (so white-vs-dark text is moot). Verdict pills stay solid fill with white
  text, except DEFER (`--wt-warn`) which takes `#1a1a1a` dark text (T-2024 precedent).
- **Why:** Two different affordances: filter buttons are toggles (outline reads as
  "clickable filter"); verdict pills are status indicators (solid reads as "this IS the
  verdict"). Preserving the existing visual grammar while only swapping the colour source.
- **Rejected:** Unifying both into one style (loses the toggle-vs-status distinction);
  uniform white text on all pills (DEFER on light warn fails contrast).

## Recommendation

- **Recommendation:** GO
- **Rationale:** All 8 Agent ACs pass. `_approvals_content.html`'s ~39 inline theme hexes
  now reference foundation semantic tokens — the three verdict-pill blocks, both reviewer
  badges, the recommendation decision text, the "no recommendation" fallback box, severity
  spans, all eight filter buttons, the stale-age span, and the batch-complete/complete-task
  submit buttons. Only `#fff`/`#1a1a1a` contrast foregrounds remain (HTML numeric entities
  are not colours). Together with S3c (T-2025) this completes the approvals-page colour
  tokenisation. Re-theming is pinned by a unit test (7 green: token usage, old hexes gone,
  no residual hex, template compiles) and a Playwright test (a `.verdict-badge` background
  changes across `paper`→`console`). Eyes-on under `bone` confirmed the page renders
  cleanly with the GO pills re-themed. Restyle only — no markup/buttons/decision logic
  touched (sovereignty surface).
- **Evidence:**
  - `web/templates/_approvals_content.html` — grep shows only `#fff`/`#1a1a1a` + HTML entities
  - `tests/unit/test_approvals_content_tokens.py` — 7 passed in 0.66s
  - `tests/playwright/test_approvals_content_tokens.py` — 2 passed (verdict-pill re-theme + screenshot)
  - `web/static/ux-review/T-2026-approvals-content-tokens.png` — eyes-on artefact (bone palette)
  - Reviewer: see `## Reviewer Verdict` below
- **Human [REVIEW] remaining:** GO/NO-GO/DEFER legibility + filter-button contrast across
  all 5 palettes (the sovereignty-load-bearing Human AC).
- **Scope note:** the arc-closure "Approve / Override" buttons are pico-primary (no inline
  hex) — they follow the palette accent already and were not in this slice's hex scope.

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

### 2026-05-24T11:27:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2026-arc-007-s3c2--approvals-content-inline-s.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-98007cfa
- **Timestamp:** 2026-05-25T22:43:13Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-25T22:43:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
