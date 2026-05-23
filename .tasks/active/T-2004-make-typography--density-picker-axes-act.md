---
id: T-2004
name: "make Typography & Density picker axes actually apply (self-host webfonts, headings
  use --wt-font-head, wire density scaling)"
description: >
  arc-007 S1/S3: the appearance picker exposes Typography and Density controls that
  change data-wt-* + tokens but have zero visible effect — webfonts deferred (system
  fallback identical), headings ignore --wt-font-head, density tokens unconsumed.
  Human chose make-them-work-now: self-host webfonts (no external CDN), apply --wt-font-head
  to headings, wire density to scale the UI. Found during T-2003 review.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [ux, css, fonts, render-surface]
components: []
related_tasks: [T-2003, T-2002, T-1991, T-1988]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-23T14:48:39Z
last_update: 2026-05-23T14:49:39Z
date_finished:
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
bvp_scores_proposed:
  - ts: '2026-05-23T14:49:39Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-2004: make Typography & Density picker axes actually apply (self-host webfonts, headings use --wt-font-head, wire density scaling)

## Context

Found during T-2003 [REVIEW]: the appearance picker (S1) exposes Typography and
Density controls that flip `data-wt-type`/`data-wt-density` and the `--wt-*` tokens, but
nothing visible changes. Three gaps, all confirmed live:
1. **Webfonts not loaded** — `foundations.css` §4 defers `@font-face`, so Inter/Geist/
   Plex/Manrope all fall back to identical system-ui.
2. **Headings ignore the serif token** — `h1` computes `Inter` even under newsreader
   (whose `--wt-font-head` is `Newsreader, Georgia, serif`); nothing maps headings to
   `--wt-font-head`.
3. **Density unconsumed** — `--wt-font-size`/`--wt-space`/`--wt-row-pad`/`--wt-density-scale`
   change but `--pico-font-size` stays `125%` and body stays `20px`; no rule consumes them.

Human decision (2026-05-23): **make them work now** — self-host the webfonts (no external
CDN, respects portability), apply `--wt-font-head` to headings, and wire density to scale
the UI. This brings the deferred S0 §4 webfont loading + S3-S5 density application forward
for the picker axes.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] Webfonts self-hosted under `web/static/fonts/` (woff2, OFL) with `@font-face` rules in foundations.css for each family used by the 6 type options (Inter, Geist, IBM Plex Sans+Mono, Manrope, Newsreader, JetBrains Mono); no external CDN reference
- [ ] Headings consume the type pairing: a rule maps `h1..h6` (and Pico heading vars) to `var(--wt-font-head)` so newsreader renders serif headings
- [ ] Density applies globally: picking compact/cozy/comfortable changes rendered text size (and base spacing) on content pages — verified by computed body font-size differing across the three densities
- [ ] `fw ux-review --axes` (or equivalent) smoke-tests the Type and Density axes individually (not just presets) and reports each as having a visible effect — closes the T-2002 gap that masked this
- [ ] No console/page errors introduced (font 404s included); `fw ux-review` verdict has no new findings attributable to fonts

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
- [ ] [REVIEW] Typography and Density visibly change the app and look right
  **Steps:**
  1. Open `http://192.168.10.107:3000/settings/appearance`
  2. Under **Typography**, click each option (Inter / Geist / Plex / Manrope / Newsreader / System) — the page font should visibly change; Newsreader should give serif headings
  3. Under **Density**, click Compact / Cozy / Comfortable — text size and spacing should tighten/loosen
  4. Navigate to Tasks and confirm the choices carry across pages
  **Expected:** Each Typography option renders a distinct typeface; each Density option visibly changes size/spacing; it reads cohesively
  **If not:** Note which option shows no change (or a font 404 in console) and tell the agent

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

## Decisions

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

### 2026-05-23T14:48:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2004-make-typography--density-picker-axes-act.md
- **Context:** Initial task creation

### 2026-05-23T14:49:39Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
