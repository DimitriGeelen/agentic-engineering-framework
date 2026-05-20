---
id: T-1970
name: "Badge contrast sweep: fix .badge-info (invisible), .badge-ok (3.55), .badge-muted (4.44) — Pico-variable-name anti-pattern"
description: >
  Badge contrast sweep: fix .badge-info (invisible), .badge-ok (3.55), .badge-muted (4.44) — Pico-variable-name anti-pattern

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [ui, a11y, readability, badge, contrast-sweep, arc:arc-grooming]
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T21:22:46Z
last_update: 2026-05-20T21:22:46Z
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

# T-1970: Badge contrast sweep: fix .badge-info (invisible), .badge-ok (3.55), .badge-muted (4.44) — Pico-variable-name anti-pattern

## Context

Playwright contrast scan of `/arcs/arc-006` (post T-1968 v2 ship) revealed a sibling family of the same `--pico-secondary` anti-pattern in three `.badge-*` classes used on arcs pages. The critical case: `.badge-info` ("below threshold" / similar) renders text and background as the SAME color (1.00 contrast → invisible).

**Findings from Playwright contrast audit (2026-05-20):**

| Class | Sample text | Color → BG | Contrast | Severity |
|---|---|---|---|---|
| `.badge-info` | "below threshold" | `rgb(1,114,173)` on `rgb(1,114,173)` | **1.00** | CRITICAL — invisible |
| `.badge-ok` | "work-completed" | `rgb(255,255,255)` on `rgb(39,153,119)` | 3.55 | Below WCAG AA |
| `.badge-muted` | "draft" | `rgb(100,107,121)` on `rgb(231,234,240)` | 4.44 | Just below AA |
| `.audit-warn` | "WARN" | `rgb(232,163,23)` on `rgb(255,255,255)` | 2.17 | Decorative warn glyph |

**Root cause (.badge-info):** `background: var(--pico-primary-background); color: var(--pico-primary);` — same anti-pattern as T-1968 v1 ("looks like a contrast pair but isn't"). In this Pico build both vars resolve to the same blue.

**Affected source files** (all `.badge-info` instances + colocated `.badge-ok`/`.badge-muted`):
- `web/templates/arc_detail.html:10-13`
- `web/templates/arcs_index.html:99-104` AND `:163-166` (duplicate block — HTMX swap context)

**Suggested fixes** (mirroring T-1968 v2 pattern):
- `.badge-info`: `color: var(--pico-primary-inverse)` (white)
- `.badge-ok`: harden bg to `#1e6a2a` (or pick a Pico token that resolves consistently darker)
- `.badge-muted`: `color: var(--pico-color)` (main text colour — guaranteed contrast against any `*-background` variant)
- `.audit-warn`: change yellow to `#8b6914` or use `--pico-color` + warn icon (semantic warn often kept low-contrast intentionally; defer until user calls it out specifically)

## Acceptance Criteria

### Agent
- [ ] `.badge-info` color changed to `var(--pico-primary-inverse)` in `web/templates/arc_detail.html`
- [ ] Same fix applied to `web/templates/arcs_index.html` at BOTH instances (lines ~101 and ~164 — duplicate block exists due to HTMX partial-swap)
- [ ] `.badge-ok` bg darkened or color guaranteed for WCAG AA (target ≥4.5)
- [ ] `.badge-muted` color changed to `var(--pico-color)` at all three files
- [ ] Playwright contrast re-scan on `/arcs/arc-006` shows all four classes ≥4.5 contrast (use the inline contrast helper from this session's scan; computed-style sample of one `.badge-info`, one `.badge-ok`, one `.badge-muted` element)
- [ ] Watchtower restarted to invalidate Flask template cache
- [ ] Before/after screenshots saved as `badge-contrast-before.png` / `badge-contrast-after.png` (this session left `arc-badge-before.png` / `arc-badge-after.png` as the precedent)

### Human
- [ ] [REVIEW] All four badge classes are clearly legible on `/arcs/arc-006` and the arcs index
  **Steps:**
  1. Hard-refresh http://192.168.10.107:3000/arcs/arc-006 and http://192.168.10.107:3000/arcs
  2. Inspect badges: "below threshold" (or whatever info badge is present), the green "work-completed", the muted "draft"
  3. Compare to before screenshot saved in repo root
  **Expected:** All badge text is readable at rest. No same-color-on-same-color.
  **If not:** Note which class, sample the computed colors via devtools, file follow-up.

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

### 2026-05-20T21:22:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1970-badge-contrast-sweep-fix-badge-info-invi.md
- **Context:** Initial task creation
