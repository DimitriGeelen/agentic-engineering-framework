---
id: T-1991
name: "Watchtower foundation tokens — 6 palettes × light/dark + 6 type pairings +
  3 density tiers as CSS custom properties (arc-007 S0)"
description: >
  Define the foundation token layer for the watchtower-redesign arc. Add CSS custom
  properties (--wt-bg, --wt-surface, --wt-border, --wt-text, --wt-muted, --wt-accent,
  --wt-accent-ink, --wt-success, --wt-warn, --wt-danger, --wt-info, plus dark-mode
  variants) for all 6 palettes from docs/design/watchtower-redesign-2026-05-13/project/foundations.jsx
  (Slate, Linen, Stone, Paper, Bone, Console). Define 6 type pairings (Inter+JBM,
  Geist, IBM Plex, Manrope, Newsreader-serif-heads, system). Define 3 density tiers
  (compact/cozy/comfortable) as font-size + spacing scale multipliers. No page-level
  edits in this slice — just web/static/css/foundations.css + import. Parent inception:
  T-1987.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, redesign, ui, foundations]
arc_id: watchtower-redesign
components: [tests/unit/test_appearance_validation.py, 
      web/blueprints/settings.py, web/static/css/foundations.css, 
      web/templates/appearance.html, web/templates/base.html]
related_tasks: [T-1987]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-22T10:06:08Z
last_update: 2026-08-04T12:38:27Z
date_finished: 2026-05-22T19:04:24Z
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
  - ts: '2026-05-22T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-22T10:15:02Z'
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
      F2: 1
    rationale: "D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 (body:default-change);
      D4=2 (body:env-class-handled); F1=1 (body/tag hits for 'F1': 1); F2=1 (body/tag
      hits for 'F2': 1)"
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:28Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1991: Watchtower foundation tokens — 6 palettes × light/dark + 6 type pairings + 3 density tiers as CSS custom properties (arc-007 S0)

## Context

Keystone slice (S0) of arc-007 (watchtower-redesign). Defines a self-contained
foundation token layer — `web/static/css/foundations.css` — with all 6 palettes
(light + dark), 6 type-pairing font sets, and density scale tokens, sourced from
`docs/design/watchtower-redesign-2026-05-13/project/foundations.jsx`.

**The single highest-leverage decision (review-A1, A7):** the **Pico-bridge** — a
`:root` block, loaded *after* `pico.min.css`, that re-points core `--pico-*` vars
at the `--wt-*` tokens. This makes the 400+ existing Pico-var usages across 30+
templates follow the active palette *for free*, without touching any page. Pure
side-by-side coexistence (no bridge) FAILS the headline mechanic — Pico-styled
controls keep reading `--pico-*` and ignore the palette.

**Scope fence:** NO page-level edits in this slice. Only `foundations.css` + the
`<link>` wiring in `base.html` (after pico). Palette/mode switching is driven by
`data-wt-palette` / `data-wt-mode` attributes on `<html>`; the picker that sets
them ships in S1 (T-1988). Default palette = slate, mode = light, density = compact
(the design dialogue's chosen density). Webfont @font-face loading is explicitly
DEFERRED (font-family tokens fall back to system fonts) — avoids the
network-at-theme-pick risk and keeps S0 lean. Parent inception: T-1987 (GO).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `web/static/css/foundations.css` exists and defines `--wt-*` token sets (bg, surface, border, text, muted, accent, accent-ink, success, warn, danger, info) for all 6 palettes (slate, linen, stone, paper, bone, console), keyed by `[data-wt-palette="<id>"]` with `:root` defaulting to slate
- [x] Every palette has a dark variant under `[data-wt-mode="dark"][data-wt-palette="<id>"]` — 6 dark blocks present
- [x] **Pico-bridge present:** a `:root` block re-points the core Pico vars at `--wt-*` — at minimum `--pico-background-color: var(--wt-bg)`, `--pico-card-background-color: var(--wt-surface)`, `--pico-color: var(--wt-text)`, `--pico-muted-color: var(--wt-muted)`, `--pico-primary: var(--wt-accent)`, `--pico-primary-inverse: var(--wt-accent-ink)`, `--pico-border-color: var(--wt-border)`
- [x] 6 type-pairing font token sets defined (`--wt-font-sans` / `--wt-font-mono` / `--wt-font-head`), keyed by `[data-wt-type="<id>"]` (inter, geist, plex, manrope, newsreader, system), each with a system-font fallback in the stack
- [x] Density tokens defined (`--wt-density-scale` + spacing/font-size derivations) for compact/cozy/comfortable, default = compact
- [x] `foundations.css` is `<link>`ed in `base.html` **after** `pico.min.css` (bridge must cascade over Pico) — verified by source order
- [x] CSS is structurally valid: brace count balanced, no `var(--wt-undefined)` dangling references for the default (slate/light) path
- [x] Watchtower still returns HTTP 200 with `foundations.css` referenced in the rendered `<head>`

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

- [ ] [REVIEW] Each of the 6 palettes re-themes the page coherently (the headline mechanic at token level)
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw serve` (or use the running instance at the URL from `bin/fw watchtower url`)
  2. Open the Watchtower home page, open browser devtools, and on the `<html>` element set `data-wt-palette="slate"` then cycle through `linen`, `stone`, `paper`, `bone`, `console`
  3. For each, also toggle `data-wt-mode="dark"`
  **Expected:** Background, surfaces, text, borders, and accent all shift together to the new palette with legible contrast in both light and dark — Pico-styled controls (buttons, cards, inputs) follow the palette, not stuck on indigo/grey. No element stays the old colour.
  **If not:** Note which element ignored the palette (likely a hardcoded hex literal, not a `--pico-*`/`--wt-*` var) — that is S3-S5 debt, catalogue it; but the bridged Pico controls MUST follow.

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

# File exists
test -f web/static/css/foundations.css
# All 6 palettes defined
for p in slate linen stone paper bone console; do grep -q "data-wt-palette=\"$p\"" web/static/css/foundations.css || { echo "missing palette $p"; exit 1; }; done
# 6 dark variants
test "$(grep -c 'data-wt-mode="dark"' web/static/css/foundations.css)" -ge 6
# Pico-bridge present (core re-points)
grep -q -- '--pico-background-color: *var(--wt-bg)' web/static/css/foundations.css
grep -q -- '--pico-color: *var(--wt-text)' web/static/css/foundations.css
grep -q -- '--pico-primary: *var(--wt-accent)' web/static/css/foundations.css
# 6 type pairings
for t in inter geist plex manrope newsreader system; do grep -q "data-wt-type=\"$t\"" web/static/css/foundations.css || { echo "missing type $t"; exit 1; }; done
# Density default compact
grep -q -- '--wt-density-scale' web/static/css/foundations.css
# Brace balance
python3 -c "c=open('web/static/css/foundations.css').read(); assert c.count('{')==c.count('}'), 'unbalanced braces'"
# Linked after pico in base.html
python3 -c "import re,sys; h=open('web/templates/base.html').read(); pi=h.find('pico'); fi=h.find('foundations.css'); sys.exit(0 if (pi!=-1 and fi!=-1 and fi>pi) else 1)"
# Watchtower serves it (200 + referenced in head)
url=$(bin/fw watchtower url 2>/dev/null); curl -sf "$url/" | grep -q "foundations.css"

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

### 2026-05-22 — S0 build vs. inception plan
- **What changed:** The existing dark mode is Pico's `data-theme="dark"` toggle (base.html `wtToggleTheme` + `wt-theme` localStorage), not a custom mechanism. The bridge must drive `--wt-*` dark values off `[data-theme="dark"]` (not only the planned `[data-wt-mode="dark"]`) or the existing toggle would break — both selectors are now supported.
- **Plan impact:** S0 stays a pure token layer as planned (no page edits). Confirmed the Pico-bridge is sufficient: dark toggle, accent, surfaces all flow through `var(--pico-*) → var(--wt-*)` without per-page work.
- **Triggered:** No new sub-task. Note for S1 (T-1988): the picker should set palette via `data-wt-palette` and reuse the *existing* `data-theme` for light/dark rather than introducing `data-wt-mode`, to avoid a parallel toggle. The 704 hardcoded hex literals (review-A1) remain theme-blind — they are S3-S5 scope, not S0.

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

## Recommendation

**Recommendation:** GO (agent ACs complete; one `[REVIEW]` visual check pending)

**Rationale:** The S0 foundation token layer is in place and verified end-to-end. The keystone Pico-bridge works — the home page renders `data-wt-palette` from the token layer, and switching the palette via S1's picker re-themes Pico-styled controls live (confirmed in the S1 round-trip: Console preset → `data-theme="dark"` + `data-wt-palette="console"` on `/`). Scope fence held: zero page-level edits this slice. The remaining `[REVIEW]` is pure human taste — confirming the 6 palettes each read coherently and legibly in light + dark.

**Evidence:**
- `web/static/css/foundations.css` — 6 palettes × light/dark, 6 type pairings, density tiers, Pico-bridge (commit `3088f27d`)
- All 8 Agent ACs verified: file checks + brace balance + link order + `curl` 200 with `foundations.css` referenced
- Bridge proven via S1: saving a preset re-themes other pages server-side (no per-page edits)
- Known follow-up (not blocking): 704 hardcoded hex literals across template `<style>` blocks remain theme-blind — S3-S5 scope

## Updates

### 2026-05-22T10:06:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1991-watchtower-foundation-tokens--6-palettes.md
- **Context:** Initial task creation

### 2026-05-22T18:40:00Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-220daf1c
- **Timestamp:** 2026-05-22T19:04:24Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-22T19:04:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-08-04T10:25:09Z — status-update [task-update-agent]
- **Change:** horizon: now → now

### 2026-08-04T12:38:27Z — status-update [task-update-agent]
- **Change:** horizon: now → now
