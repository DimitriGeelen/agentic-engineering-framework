---
id: T-1968
name: "Arc badge dark-on-dark contrast fix — color: var(--pico-secondary) → var(--pico-color)"
description: >
  Arc badge dark-on-dark contrast fix — color: var(--pico-secondary) → var(--pico-color)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [ui, a11y, readability, arc-badge, arc:arc-grooming]
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T21:04:56Z
last_update: '2026-06-11T22:23:27Z'
date_finished: 2026-05-20T21:09:04Z
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
  - ts: '2026-05-28T22:54:10Z'
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
  - ts: '2026-06-11T22:23:27Z'
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

# T-1968: Arc badge dark-on-dark contrast fix — color: var(--pico-secondary) → var(--pico-color)

## Context

User report mid-review: arc badge labels render as dark-blue text on dark-slate background in dark mode — unreadable. Source: `web/templates/base.html:281` uses `color: var(--pico-secondary)` against `background: var(--pico-secondary-background)`. Pico's `--secondary` (text) and `--secondary-background` (subtle chip bg) are NOT a contrast pair — both are blue-ish in dark mode. The `:hover` state on line 290 correctly uses `--pico-secondary-inverse`, which is why hover reads fine.

Fix (user-chosen "subtle pill, brighter text"): change `color: var(--pico-secondary)` → `color: var(--pico-color)`. Keep background. One-line change.

## Acceptance Criteria

### Agent
- [x] `.arc-badge` text color changed to `var(--pico-color)` in `web/templates/base.html:282` (with T-1968 rationale comment)
- [x] Watchtower restarted (PID 3933336, health check passed) to invalidate Flask template cache
- [x] DOM-content assertion: `/tasks` renders 19 arc-badge instances, `/arcs/arc-006` renders 28; rendered base.html CSS now contains `color: var(--pico-color);` in the `.arc-badge` block (verified via `curl | awk '/\.arc-badge \{/,/^[[:space:]]*\}/' | grep color:`)

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

- [ ] [REVIEW] Arc badge labels are readable at rest in dark mode
  **Steps:**
  1. Hard-refresh http://192.168.10.107:3000/tasks (or http://192.168.10.107:3000/arcs/arc-006) — the page with arc-badge pills next to task entries
  2. Look at the arc badge pill (small rounded label, e.g. "arc-006")
  3. Compare to hover state (mouse over the badge)
  **Expected:** Resting label text is clearly readable against the subtle pill background — comparable legibility class to the hover state, just visually quieter.
  **If not:** Note which page + colour scheme (light/dark) and the actual rendered colours from devtools.

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

# T-2771: two independent defects in one line. (1) It piped a 375,353-byte page
# through awk|grep -q → SIGPIPE/141 (T-2743). (2) It asserted `var(--pico-color)`,
# which is T-1968's OWN v1 fix — the CSS comment at that selector records that v1
# resolved to the Pico link colour inside an <a> and was replaced by
# --pico-secondary-inverse. The line pinned the value its task superseded.
WT=$(bin/fw watchtower url); curl -sf "$WT/" -o /tmp/.t1968-wt.html && awk '/\.arc-badge \{/,/^[[:space:]]*\}/' /tmp/.t1968-wt.html | grep -q 'color: var(--pico-secondary-inverse);'
WT=$(bin/fw watchtower url); test $(curl -sf "$WT/tasks" 2>&1 | grep -c 'class="arc-badge"') -ge 1

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

**Symptom:** Human operator opened `/review/T-XXXX` links; the arc-badge pill rendered as dark-blue text on dark-slate background in dark mode — unreadable at rest. Hovering the badge made it legible (the hover style worked). User reported: "labels are difficlt to read bleu backgroiund on darc colored text".

**Root cause:** `web/templates/base.html:281` set `color: var(--pico-secondary)` against `background: var(--pico-secondary-background)`. The variable names suggest these belong together as a pair, but they don't — `--pico-secondary` is a text colour and `--pico-secondary-background` is a subtle chip/sidebar bg. In dark mode they're both blue-ish. The actual contrast partner of `--pico-secondary` is `--pico-secondary-inverse`, which is exactly what the `:hover` block on line 290 used — which is why hover read correctly.

**Why structurally allowed:** Three gaps stacked.
1. Pico CSS variable naming implies pairs that don't exist as contrast pairs. The intuitive read "secondary text on secondary background" is wrong, but nothing in the template warns about it.
2. There is no automated contrast test on the rendered Watchtower CSS. T-1575 mandates Playwright/DOM-content checks for UI changes — those were not added when `.arc-badge` was introduced (T-1909), and an `:hover`-only spot-check would have masked the bug.
3. The bug only manifests in dark mode. Light-mode-only review would not have surfaced it. The light-mode reviewer is the framework dev; dark-mode reviewer is the human operator who hit this.

**Prevention:**
1. **This fix:** swap to `color: var(--pico-color)` — always a contrast pair against any `*-background` variant.
2. **Sweep candidate (not done in this task):** grep for `color: var(--pico-secondary)` against any `*-background` pairing in `web/templates/`. Same anti-pattern likely exists in other badges.
3. **Documentation cue:** the inline comment added at `base.html:275-278` names the trap so the next CSS author sees it.
4. **Automated check candidate (future):** a Playwright dark-mode contrast assertion on the `.arc-badge` selector would catch the next instance. Not built here; flagged in Evolution.

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

### 2026-05-20 — A11y in dark mode is structurally invisible to source review
- **What changed:** Filing assumed this was a one-line CSS oops. Investigation showed it's a class-of-bug: Pico CSS variable pairs like `--pico-secondary` + `--pico-secondary-background` are NOT designed as a contrast pair (one is text color, the other is a chip/sidebar background that happens to share the colour family). The naming convention reads "this goes with that" but in dark mode they both become blue-ish on blue-ish. The `:hover` rule used `--pico-secondary-inverse` correctly — that's the actual contrast partner of `--pico-secondary`.
- **Plan impact:** This fix only resolves `.arc-badge`. The same anti-pattern likely exists elsewhere. Worth a sweep at some point: `grep -rE "color:[[:space:]]*var\(--pico-secondary\)" web/templates` paired with background = `--pico-secondary-background` is the smell.
- **Triggered:** No follow-up task filed — the user is mid-review and we needed to ship the fix. A future a11y sweep task could grep for the smell. Captured here so anyone looking at this file later sees the broader pattern.

## Recommendation

**Recommendation:** GO

**Rationale:** Single-line CSS fix on `.arc-badge` resolves the dark-on-dark contrast issue. Resting state now uses `--pico-color` (main text colour, guaranteed contrast against page background and any `*-background` variant). Hover behaviour unchanged. No other CSS dependencies. Watchtower restarted; rendered HTML on `/tasks` (19 badges) and `/arcs/arc-006` (28 badges) confirmed serving the new rule.

**Evidence:**
- `web/templates/base.html:282` now `color: var(--pico-color);` (with T-1968 rationale comment)
- DOM-content: `curl /` → `awk '/\.arc-badge \{/,/^[[:space:]]*\}/' | grep color:` returns `color: var(--pico-color);`
- DOM-content: `/tasks` renders 19 `class="arc-badge"`, `/arcs/arc-006` renders 28
- Watchtower restart confirmed: PID 3933336, health-check passed

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

### 2026-05-20T21:04:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1968-arc-badge-dark-on-dark-contrast-fix--col.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-8390c2cd
- **Timestamp:** 2026-05-20T21:09:07Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `.arc-badge` text color changed to `var(--pico-color)` in `web/templates/base.html:282` (with T-1968 rationale comment)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/base.html in: `.arc-badge` text color changed to `var(--pico-color)` in `web/templates/base.html:282` (with T-1968 rationale comment)`

### 2026-05-20T21:09:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
