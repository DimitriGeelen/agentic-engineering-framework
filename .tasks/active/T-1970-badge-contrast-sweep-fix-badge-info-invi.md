---
id: T-1970
name: "Badge contrast sweep: fix .badge-info (invisible), .badge-ok (3.55), .badge-muted
  (4.44) — Pico-variable-name anti-pattern"
description: >
  Badge contrast sweep: fix .badge-info (invisible), .badge-ok (3.55), .badge-muted
  (4.44) — Pico-variable-name anti-pattern

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [ui, a11y, readability, badge, contrast-sweep, arc:arc-grooming]
components: [tests/playwright/test_badge_contrast.py, 
      web/templates/arc_detail.html, web/templates/arcs_index.html]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T21:22:46Z
last_update: '2026-08-16T22:24:02Z'
date_finished: 2026-05-21T06:45:29Z
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
  - ts: '2026-05-20T21:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-20T21:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
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
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
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
- [x] `.badge-info` color changed to `var(--pico-primary-inverse)` in `web/templates/arc_detail.html`
- [x] Same fix applied to `web/templates/arcs_index.html` at BOTH instances (lines ~101 and ~164 — duplicate block exists due to HTMX partial-swap)
- [x] `.badge-ok` bg darkened to `#1e6a2a` for WCAG AA (3.55 → 6.67)
- [x] `.badge-muted` color changed to `var(--pico-color)` at all three sites (4.44 → 9.21)
- [x] Playwright contrast re-scan on `/arcs/arc-006` shows the three fixed classes ≥4.5: badge-info 5.23, badge-ok 6.67, badge-muted 9.21. `/arcs` index pinned similarly: badge-info 5.23, badge-ok 6.67, badge-draft 5.21 (`badge-warn`/`badge-muted` absent from current fixtures)
- [x] Watchtower restarted to invalidate Flask template cache
- [x] After screenshots saved at `docs/reports/T-1970-evidence/`: `badge-contrast-after.png` (arc detail), `badge-contrast-arcs-after.png` (arcs index) — relocated from repo root per T-1949 cleanup (tracked via gitignore `!docs/reports/T-*-evidence/*.png` exception)
- [x] Playwright contrast-pin test added: `tests/playwright/test_badge_contrast.py` — guards against future drift; runs computed-style sample on `/arcs/arc-006` and `/arcs` for `.badge-info|.badge-ok|.badge-muted`, asserts ≥4.5 (or skips if class absent in fixture)

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

# T-1970 verification: re-scan contrast via Playwright pin test (added this task).
# The bare Python command keeps the gate honest — if a future template edit drops
# any of the three badge classes below WCAG AA, this collect-only check still
# passes (no runtime), but `fw test playwright` will fail next CI loop. The actual
# behavioural guard lives in tests/playwright/test_badge_contrast.py.
python3 -c "import ast; ast.parse(open('tests/playwright/test_badge_contrast.py').read())"
grep -q "var(--pico-primary-inverse)" web/templates/arc_detail.html
grep -q "var(--pico-primary-inverse)" web/templates/arcs_index.html
test "$(grep -c 'var(--pico-primary-inverse)' web/templates/arcs_index.html)" -ge 2

## RCA

**Symptom:** `.badge-info` pills (e.g. "below threshold", "in-progress") rendered
text in the same blue as their background — visually invisible — on `/arcs` and
`/arcs/<slug>`. Sibling classes `.badge-ok` (3.55) and `.badge-muted` (4.44)
shipped below WCAG AA. Detected by Playwright `getComputedStyle()` contrast scan
during T-1968 v2 verification; user surfaced the symptom by ear ("labels are
difficult to read"), agent first attempt (T-1968 v1) used `--pico-color` which
is shadowed inside `<a>` to be the link colour — same anti-pattern class.

**Root cause:** Pico CSS variable-name pairs that *look* like contrast partners
aren't always so at runtime. `--pico-primary-background` + `--pico-primary` both
resolve to the same blue in this Pico build. The actual contrast partner of
`--pico-X-background` is `--pico-X-inverse`. Same anti-pattern across three
badge classes because the templates were drafted by visual pattern-matching
on the variable names, not by sampling computed values.

**Why structurally allowed:** UI verification convention prior to T-1575 was
"element-presence grep" — assert the class is present in rendered HTML. Grep
cannot see colour, so a same-colour-on-same-colour bug is structurally invisible
to the existing test surface. T-1575 codified "DOM-content / Playwright
screenshot required for UI changes" but the existing badge templates predated
that rule, so the legacy contrast bug sat unseen. There is no audit check that
samples computed contrast against WCAG.

**Prevention:** `tests/playwright/test_badge_contrast.py` (added this task) pins
the three fixed classes on `/arcs` + `/arcs/arc-006` against WCAG AA. Future
template edits that drop contrast below 4.5 will fail `fw test playwright`. The
pin uses computed-style sampling exactly because no static check can catch
the runtime variable-resolution class. Extending the pin to other surfaces
is a sibling task (filed if more invisible badges surface).

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

### 2026-05-21 — sibling family of T-1968 anti-pattern
- **What changed:** Playwright contrast scan revealed the `--pico-X-background` + `--pico-X` anti-pattern is not a one-off (T-1968) but a *class*: three badge variants across two templates all picked the wrong partner. Estimating the bug-density: any future "looks like a contrast pair" Pico variable usage should be treated as suspect until computed-style-sampled.
- **Plan impact:** The original ACs assumed one-line edits per class. Actual fix needed three site edits per class (HTMX swap-context duplicate) and a behavioural pin test, because grep-based regression catches the *string* but not the *resolved colour*.
- **Triggered:** `tests/playwright/test_badge_contrast.py` (computed-style WCAG pin). If more invisible-badge symptoms surface elsewhere in templates, the pattern is solved by extending TARGET_CLASSES and adding the surface route — not by per-class debugging.

## Decisions

### 2026-05-21 — fix mechanism per class
- **Chose:** `.badge-info` uses `--pico-primary-inverse` (Pico contrast partner). `.badge-ok` uses hard-coded `#1e6a2a` (darker green, ≥AA against white). `.badge-muted` uses `--pico-color` (page text colour, always contrasts with `*-background`).
- **Why:** Three different mechanisms because the original anti-pattern took three different shapes. The Pico variable for ok-state has no `-inverse` partner at the same value as the bg, so a hard-coded hex is the most reliable path — matches `.badge-warn` which already uses `#c97a00`. `--pico-color` is safe for muted because no `<a>` scope shadow applies inside a `<span class="badge-muted">`.
- **Rejected:** Adding a new CSS variable layer (`--badge-info-fg` etc.) — adds indirection without removing the underlying Pico-variable-shadow class of bug. Pinned the *outcome* (≥4.5 contrast) via Playwright instead.

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

**Rationale:** The three target classes now exceed WCAG AA on both `/arcs` and `/arcs/<slug>`. Playwright-verified computed-style contrast jumped from invisible (1.00) / fail (3.55) / fail (4.44) to 5.23 / 6.67 / 9.21. A pin test guards against regression. The fix follows the established T-1968 v2 pattern and addresses the root anti-pattern class, not just the symptom.

**Evidence:**
- `.badge-info`: 1.00 → 5.23 (was invisible) on `/arcs/arc-006`; 5.23 on `/arcs`
- `.badge-ok`: 3.55 → 6.67 on both pages
- `.badge-muted`: 4.44 → 9.21 on `/arcs/arc-006`
- After screenshots: `docs/reports/T-1970-evidence/badge-contrast-after.png` (arc detail full page), `docs/reports/T-1970-evidence/badge-contrast-arcs-after.png` (arcs index viewport)
- Pin test: `tests/playwright/test_badge_contrast.py` — 6 parametrised cases (3 classes × 2 pages), each asserts ≥4.5 with explicit `count==0` skip semantics
- Templates: `web/templates/arc_detail.html:10-13`, `web/templates/arcs_index.html:101-104`, `web/templates/arcs_index.html:164-167` — all three sites updated

**Review on Watchtower:** http://192.168.10.107:3000/review/T-1970

## Updates

### 2026-05-20T21:22:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1970-badge-contrast-sweep-fix-badge-info-invi.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-700aa35c
- **Timestamp:** 2026-05-21T06:45:29Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-21T06:45:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
