---
id: T-2006
name: "fix Editorial/linen accent contrast — accent-ink on accent 3.83:1 fails WCAG
  AA"
description: >
  fix Editorial/linen accent contrast — accent-ink on accent 3.83:1 fails WCAG AA

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [bug, ux, css, a11y, render-surface, arc-007]
components: [web/static/css/foundations.css]
related_tasks: [T-2005, T-2002, T-1991, T-1988, T-1987]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-23T15:24:00Z
last_update: 2026-05-26T06:50:38Z
date_finished: 2026-05-26T06:50:38Z
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
  - ts: '2026-05-23T15:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-23T15:30:02Z'
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

# T-2006: fix Editorial/linen accent contrast — accent-ink on accent 3.83:1 fails WCAG AA

## Context

The ux-review engine (T-2002) flags one CONCERN across the whole arc-007 foundation: the
**Editorial** preset (linen palette, light) has `--wt-accent-ink` (`#fbf8f1`, near-white)
on `--wt-accent` (`#c4623f`, terracotta) at **3.83:1**, below WCAG AA's 4.5:1 for normal
text. This is the button-label contrast on every accent button under Editorial. Dark linen
inherits the same `--wt-accent`, so the single token at `foundations.css` line 32 governs
both modes. Fix: darken the accent (preserving the terracotta hue and the light-text-on-
accent design intent) to reach ≥4.5:1. The exact shade is a [REVIEW] call for the design owner.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `--wt-accent` in the `[data-wt-palette="linen"]` block (foundations.css line 32) darkened
      `#c4623f → #b35636` (terracotta preserved); `accent-ink (#fbf8f1) on accent` = **4.60:1**
      ≥ AA 4.5:1. Verified by the contrast formula (Verification block, exit 0)
- [x] `bin/fw ux-review --sweep` re-run: Editorial moved ⚠️ concern → ✅ ok; **overall verdict
      PASS** — zero automated findings across the whole arc-007 foundation
- [x] No other palette regressed: all 6 presets `applied=True`, console clean in the run

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
- [ ] [REVIEW] The darkened Editorial accent still looks right (terracotta intent preserved,
      buttons read well) — or pick a different AA-passing shade
  **Steps:**
  1. Open `http://192.168.10.107:3000/settings/appearance` and click **Editorial**
  2. Look at the accent buttons / links — the new accent is a slightly darker terracotta
  3. Compare against the sweep frame at `http://192.168.10.107:3000/static/ux-review/index.html`
  **Expected:** Accent reads as the same terracotta family, just deep enough that white button
  text is comfortably legible; the preset still feels "Editorial"
  **If not:** Tell the agent the hex you'd prefer (must keep accent-ink/accent ≥ 4.5:1) and it
  will swap it in

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
python3 -c "import sys; lin=lambda c:(c/255)/12.92 if c/255<=0.03928 else (((c/255)+0.055)/1.055)**2.4; L=lambda h:0.2126*lin(int(h[1:3],16))+0.7152*lin(int(h[3:5],16))+0.0722*lin(int(h[5:7],16)); import re; css=open('web/static/css/foundations.css').read(); m=re.search(r'\[data-wt-palette=\"linen\"\]\s*\{[^}]*--wt-accent:\s*(#[0-9a-fA-F]{6})', css); a=m.group(1); ink='#fbf8f1'; r=(max(L(ink),L(a))+0.05)/(min(L(ink),L(a))+0.05); print(f'linen accent {a}: ink/accent={r:.2f}'); sys.exit(0 if r>=4.5 else 1)"

## RCA

**Symptom:** The Editorial preset's accent buttons render near-white label text on a
terracotta (`#c4623f`) fill at 3.83:1 — below WCAG AA (4.5:1 normal text). The button text
is harder to read for low-vision users; the framework's own ux-review flags it CONCERN.

**Root cause:** The 6-palette token set (S0, T-1991) was authored from a Claude Design
bundle that specified colours by *look*, not by measured contrast. The linen accent/ink
pair was never run through a contrast check at authoring time, so a sub-AA pair shipped.

**Why structurally allowed:** S0 had no contrast gate. Token values were eyeballed against
the design mock; nothing computed `accent-ink/accent` against the AA threshold before the
tokens landed. The ux-review engine (T-2002) only existed *after* S0, which is why this was
caught in review rather than at authoring.

**Prevention:** The ux-review engine now checks `accent-ink/accent` (and text/bg, muted/bg)
against AA on every run, and the cross-page sweep (T-2005) folds contrast into the overall
verdict — so any future palette edit that drops a pair below AA surfaces as a CONCERN/FAIL
in the next `bin/fw ux-review`. (A pre-commit token-contrast lint would be the stronger
Level-C guard; deferred — the ux-review gate covers the arc's review loop for now.)

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

### 2026-05-23 — the review tool found the defect its own arc shipped
- **What changed:** This is the first defect in the S0 token set caught by the arc's own
  review tool (T-2002), not by a human eye. It validates the inception T-2000 thesis
  (executed-browser review beats the blank `/review` checkbox) on a *non-obvious*
  accessibility issue a casual look would miss.
- **Plan impact:** S0 (T-1991) is now genuinely clean (PASS), not just "looks done". The
  arc's foundation layer can be considered closed at the automated level; remaining work is
  the S2-S6 layout slices.
- **Triggered:** Noted in RCA that a pre-commit token-contrast lint would be the stronger
  Level-C guard (the ux-review gate only fires in the review loop, not at authoring). Not
  filed as a task yet — the ux-review check covers the arc's loop adequately; revisit if a
  second sub-AA pair ever ships.

## Decisions

### 2026-05-23 — darken the accent, not the ink
- **Chose:** Darken `--wt-accent` `#c4623f → #b35636` (closest-hue shade clearing AA at 4.60:1).
- **Why:** The Editorial design intent is *light text on a terracotta button*. Darkening the
  accent preserves that relationship and the hue family; the contrast gain comes for free.
- **Rejected:** Darkening `--wt-accent-ink` instead — would mean dark text on terracotta,
  inverting the design intent. Also rejected deeper shades (`#b05234`/`#ad5032`, 4.83-4.99)
  as further from the original than necessary; #b35636 is the minimal change that passes.

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

## Recommendation

**Recommendation:** GO

**Rationale:** A one-token accessibility fix that clears the only remaining automated defect
in the arc-007 foundation. The terracotta hue and the light-text-on-accent design intent are
preserved; only the human taste call on the exact shade remains (overridable via the [REVIEW]).

**Evidence:**
- `--wt-accent` `#c4623f → #b35636`; `accent-ink/accent` 3.83:1 → **4.60:1** (≥ AA 4.5:1)
- `bin/fw ux-review --sweep` → **overall verdict PASS**; Editorial now ✅ ok, all 6 presets
  applied, console clean; 5/5 pages still carry the theme
- Single line changed (foundations.css:32); dark linen inherits the same accent, so both
  modes are fixed at once
- Gallery: http://192.168.10.107:3000/static/ux-review/index.html

## Updates

### 2026-05-23T15:24:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2006-fix-editoriallinen-accent-contrast--acce.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-03483f54
- **Timestamp:** 2026-05-26T06:50:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-26T06:50:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
