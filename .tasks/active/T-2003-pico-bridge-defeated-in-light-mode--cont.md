---
id: T-2003
name: "pico-bridge defeated in light mode — content-page chrome ignores palette accent"
description: >
  arc-007 S0 bug found by the T-2002 UX-review agent: foundations.css --pico-primary:var(--wt-accent)
  bridge uses :root (0,1,0) which Pico v2 :root:not([data-theme=dark]) (0,2,0) overrides
  in light mode, so all light palettes render Pico-default azure chrome instead of
  the selected accent. Dark mode works by source-order luck. Proven fix: raise bridge
  selector specificity.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bug, ux, css, render-surface]
components: []
related_tasks: [T-2002, T-1991, T-1988, T-1987]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-23T12:34:14Z
last_update: 2026-05-23T12:52:29Z
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
  - ts: '2026-05-23T12:45:02Z'
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

# T-2003: pico-bridge defeated in light mode — content-page chrome ignores palette accent

## Context

arc-007 S0 (foundations.css) bug found by the T-2002 UX-review agent on its first
pass over S0/S1. The pico-bridge — `--pico-primary: var(--wt-accent)` and siblings —
is the redesign's "keystone" (per the foundations.css header): it re-points Pico's
vars at the `--wt-*` palette so 400+ existing `var(--pico-*)` usages re-theme for
free. But the bridge is declared at plain `:root` (specificity 0,1,0), which Pico v2's
light color-scheme selector `:root:not([data-theme=dark])` (0,2,0) **overrides**. So
in **light mode** every content page's chrome (links, buttons, primary, text) renders
Pico defaults (`--pico-primary` = `#0172ad` azure, text `#373c44`) regardless of the
chosen palette. Dark mode escapes this by source-order luck (`[data-theme=dark]` ties
`:root` on specificity, and foundations loads after Pico).

**Proven fix (confirmed live):** raising the bridge selector to
`:root:not([data-theme=dark])` flips `--pico-primary` from `#0172ad` → `var(--wt-accent)`
(verified: bone `/tasks` went `#0172ad` → `#b87a17`). The `## Decisions` block records
the exact change.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] foundations.css pico-bridge re-declared so it wins over Pico v2's light-scheme selector (`:root:not([data-theme="dark"]), [data-theme="dark"]`, foundations.css §3)
- [x] `fw ux-review` reports zero "pico-bridge defeated" findings across all 6 presets (was: 4 light palettes flagged → now 0; verdict CONCERN 4 → 1)
- [x] Playwright/DOM check: on `/tasks`, computed `--pico-primary` equals computed `--wt-accent` for light palettes (verified bone `#b87a17`, paper `#1f4ed8`)

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
- [ ] [REVIEW] In light mode, the whole app re-themes to the chosen palette (not just the picker)
  **Steps:**
  1. Open `http://192.168.10.107:3000/settings/appearance`, pick **Editorial** (warm linen)
  2. Navigate to Tasks / Cockpit — the links, buttons, and accents should now be linen-rust, not blue
  3. Try **Bone** (amber) and **Paper** (blue) and confirm each content page follows the accent
  4. Re-run `fw ux-review` and open the gallery — the warm light frames should now differ
  **Expected:** Content-page chrome follows the selected palette in light mode; gallery frames are visually distinct per palette
  **If not:** Note which palette/page still shows Pico-default blue and tell the agent

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
# After the fix, the UX-review agent must report zero bridge-defeated findings:
bin/fw ux-review >/dev/null 2>&1; ! grep -qi "pico-bridge defeated" docs/reports/T-2002-ux-review-arc-007-s0-s1.md

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

**Symptom:** In light mode, every content page (e.g. `/tasks`) renders Pico-default
azure chrome (`--pico-primary` = `#0172ad`, links `rgb(1,114,173)`, text `#373c44`)
regardless of the selected palette. The 4 light presets (Calm/Editorial/Paper/Bone)
produce near-identical app renders; only the picker page (which uses inline `--wt-*`)
re-themes. Dark presets (Console/Midnight) are unaffected.

**Root cause:** CSS specificity. foundations.css declares the pico-bridge at `:root`
(specificity 0,1,0). Pico v2 sets its light color-scheme tokens under
`:root:not([data-theme=dark])` (specificity 0,2,0), which wins. So `--pico-primary`
resolves to Pico's default, not `var(--wt-accent)`. The `--wt-*` tokens themselves are
correct (the variable is set); they just never reach Pico's vars in light mode. Dark
mode works only by source-order luck: `[data-theme=dark]` (0,1,0) ties `:root`, and
foundations.css loads after pico.min.css, so the later declaration wins.

**Why structurally allowed:** S0/S1 verification was server-side (curl) + markup-grep +
the picker page (which looks correct because it uses inline `--wt-*`). No check ever
executed the app in a browser and compared `--pico-primary` to `--wt-accent` on a
content page. The bridge was asserted to work ("keystone, review-A1/A7") but never
verified at the rendered-paint level on a Pico-styled page.

**Prevention:** The T-2002 UX-review agent now runs a bridge check
(`--pico-primary` == `--wt-accent` on the content page) across all presets — this
finding came from that check and will catch any regression. Consider a Playwright
unit test pinning the invariant for at least one light palette.

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

### 2026-05-23 — bridge bug found by the new review agent, not a human
- **What changed:** S0's "keystone" pico-bridge was assumed working (and looked fine on the picker page, which uses inline `--wt-*`). The T-2002 UX-review agent's content-page bridge check proved it was defeated in light mode — a class no existing gate covered. The fix is one specificity bump, confirmed live.
- **Plan impact:** S0 (T-1991) cannot be GO'd as-was; this fix is a prerequisite. S1 (T-1988) picker is sound but sat on the broken bridge.
- **Triggered:** the bridge check is now permanent in `fw ux-review`, so any regression re-flags. Separately surfaced: Editorial/linen button-label contrast 3.83:1 (design-token call, left for human).

## Recommendation

**Recommendation:** GO (apply the fix) — pending human `[REVIEW]` of the visual result.

**Rationale:** The bridge was functionally broken — the entire app chrome ignored the
selected palette in light mode (4 of 6 presets). The fix is minimal (one selector,
no template changes — the whole point of the bridge), reversible, and confirmed live:
`fw ux-review` bridge-defeated findings 4 → 0, verdict CONCERN 4 → 1, all 6 app frames
now visually distinct, bone/paper `--pico-primary` now equals `--wt-accent`.

**Evidence:**
- DOM: bone `/tasks` `--pico-primary` `#0172ad` → `#b87a17`; paper → `#1f4ed8`
- Gallery refreshed (all palettes re-theme): http://192.168.10.107:3000/static/ux-review/index.html
- Visual confirm: bone app frame now shows amber chrome (was Pico-default blue)
- Remaining (separate, your call): Editorial/linen button labels 3.83:1 < AA 4.5:1 — a palette-token aesthetic decision, not fixed unilaterally

## Decisions

### 2026-05-23 — proven fix (raise bridge specificity)
- **Chose:** Re-declare the foundations.css pico-bridge so its selector beats Pico v2's
  light scheme. The bridge block (currently `:root { --pico-primary: var(--wt-accent); … }`,
  foundations.css §3, ~lines 101-148) moves to a selector of equal-or-higher specificity
  than `:root:not([data-theme=dark])` — e.g. `:root:not([data-theme=dark]), [data-theme=dark]`
  (or add `:where()`-free `:root:not([data-theme=dark])` + keep a `[data-theme=dark]` arm).
- **Why:** Confirmed live — injecting `:root:not([data-theme=dark]){--pico-primary:var(--wt-accent)}`
  flipped bone `/tasks` `--pico-primary` from `#0172ad` → `#b87a17`. Minimal, reversible,
  no template changes (the whole point of the bridge).
- **Rejected:** (a) `!important` on every bridge var — works but heavy-handed and fights
  Pico everywhere; (b) per-page overrides — defeats the "free re-theme via existing
  `var(--pico-*)`" design; (c) reorder CSS load — source order already favours foundations,
  the problem is selector specificity, not order.
- **Note:** This is arc-007 S0 (under human review). Render surface — needs the human
  `[REVIEW]` before completion. Filed, not auto-fixed, because it changes the whole
  light-mode look of the app the human is currently reviewing.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-23T12:34:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2003-pico-bridge-defeated-in-light-mode--cont.md
- **Context:** Initial task creation

### 2026-05-23T12:52:29Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
