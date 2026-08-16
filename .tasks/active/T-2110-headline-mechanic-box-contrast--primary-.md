---
id: T-2110
name: "headline-mechanic-box contrast — primary-on-primary-bg unreadable on /arcs/<slug>/review"
description: >
  User report: '/arcs/arc-grooming/review' headline mechanic unreadable in current
  visual configuration. CSS in web/templates/arc_review.html:6-9 sets color: var(--pico-primary)
  on background: var(--pico-primary-background) — accent-on-accent-tint = same hue
  family = poor contrast across palettes. Same class as T-1968 (arc badge contrast)
  and T-1970 (badge contrast sweep). Fix: change color to var(--pico-color) so body
  text reads on the tinted primary background.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, contrast, arc-007, ui-bug]
components: [web/templates/arc_review.html]
related_tasks: [T-1968, T-1970, T-2006]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-30T14:31:21Z
last_update: '2026-08-16T22:24:06Z'
date_finished: 2026-05-30T14:36:18Z
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
  - ts: '2026-06-11T22:23:32Z'
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
  - ts: '2026-08-16T22:24:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2110: headline-mechanic-box contrast — primary-on-primary-bg unreadable on /arcs/<slug>/review

## Context

User report 2026-05-30: on `/arcs/arc-grooming/review`, the "Headline mechanic" callout box is unreadable in the current visual configuration. CSS at `web/templates/arc_review.html:6-9`:

```css
.headline-mechanic-box {
    padding: 0.6rem 1rem; background: var(--pico-primary-background);
    color: var(--pico-primary); ...
}
```

`--pico-primary` (accent) on `--pico-primary-background` (tinted accent bg) = same hue family in every palette → contrast ratio well below WCAG AA. Same class as T-1968 (arc badge dark-on-dark) and T-1970 (badge contrast sweep) and T-2006 (Editorial/linen accent contrast 3.83:1).

Fix shape: switch text color from accent (`--pico-primary`) to body text (`--pico-color`) — same pattern T-1968 used for arc badges. Keep the tinted background; add a left accent stripe so the "primary-flavoured" visual signal isn't lost.

## Acceptance Criteria

### Agent
- [x] `.headline-mechanic-box` `color:` is `var(--pico-color)` (body text) not `var(--pico-primary)` (accent).
- [x] Visual signal preserved via `border-left: 3px solid var(--pico-primary)` (accent stripe).
- [x] Comment in the CSS block names T-2110 and explains why the previous combination failed (forensic trail for the next reviewer).
- [x] `/arcs/arc-grooming/review` renders 200 with the headline_mechanic text present in the body.
- [x] Playwright test `test_arc_review_headline_mechanic_box_visible_with_text` added to `tests/playwright/test_arc_review_route.py` — pins structural rendering; passes (34.2s).

### Human
- [ ] [REVIEW] Headline mechanic now reads cleanly on `/arcs/arc-grooming/review` across the palettes you actively use (Calm / Editorial / Console / Paper / Bone / Midnight).
  **Steps:**
  1. Open <http://192.168.10.107:3000/arcs/arc-grooming/review>.
  2. Confirm the headline-mechanic callout (italic text, left-stripe primary accent) is readable.
  3. Optionally switch palettes via <http://192.168.10.107:3000/settings/appearance> and confirm readability holds.
  4. Compare against the captured shot at <http://192.168.10.107:3000/static/ux-review/T-2110-headline-mechanic-fixed.png>.
  **Expected:** Headline mechanic text reads clearly in every palette you try; the left accent stripe still signals "primary-flavoured" without sacrificing legibility.
  **If not:** Note which palette and what the issue is — colour band, font weight, padding, or stripe contrast.

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

grep -q 'color: var(--pico-color)' web/templates/arc_review.html
grep -q 'border-left: 3px solid var(--pico-primary)' web/templates/arc_review.html
grep -q 'T-2110' web/templates/arc_review.html
curl -sf "$(bin/fw watchtower url)/arcs/arc-grooming/review" > /tmp/.t2110-page.html && grep -q "headline-mechanic-box" /tmp/.t2110-page.html
grep -q "fw arc create test" /tmp/.t2110-page.html

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
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

## RCA

**Symptom:** On `/arcs/arc-grooming/review` (and every other arc's review surface), the "Headline mechanic" callout box rendered with text that the user could not read in the current visual configuration.

**Root cause:** `.headline-mechanic-box` set `color: var(--pico-primary)` on `background: var(--pico-primary-background)`. Pico's primary-background is a tinted version of the primary accent — same hue family. Accent-on-tinted-accent has contrast ratio well below WCAG AA in most palettes (matches the Editorial/linen 3.83:1 finding from T-2006).

**Why structurally allowed:** When this CSS was first written (T-1963, /arcs/<slug>/review surface), the contrast sweep that produced T-1968/T-1970 hadn't fired yet, and no automated contrast check ran against the arc_review template. The T-2002 ux-review engine *does* check computed-token contrast — but only on the surfaces it sweeps; this surface (arc-review) wasn't on its target list as of the 2026-05-25 captures. The template was effectively unscanned for contrast.

**Prevention:** Same shape as T-1968 / T-1970 / T-2006 — a known anti-pattern (accent text on accent-tinted background). The longer-term prevention is extending the T-2002 ux-review engine's target list to include `/arcs/<slug>/review` and `/arcs/<slug>/close`. Not filed here per "one bug = one task"; the symptom-class is captured by the catalogue of contrast tickets (T-1968, T-1970, T-2006, T-2110) and the right escalation when a 5th instance lands is to add the surface to the sweep — not file a 5th ticket.

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

### 2026-05-30 — filed + fixed in one session

- **What changed:** User reported live, root cause was a clean class match against T-1968 / T-1970 / T-2006, fix shape was a one-line CSS substitution with the accent-stripe preservation pattern T-1968 established. No mid-build pivot.
- **Plan impact:** None — the fix landed in the same shape the RCA predicted.
- **Triggered:** A separate sibling issue the user reported alongside this one — "larger screen disappears after no to much time" on the same `/arcs/<slug>/review` flow — is being kept distinct per "one bug = one task". User clarification needed before filing.

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

## Recommendation

**Recommendation:** GO

**Rationale:** Clean fix in the shape T-1968 established for the same anti-pattern (accent-on-accent → body-text + accent-stripe). All 5 Agent ACs verified. Playwright regression test added and passes (34.2s). Screenshot served for visual review. The only remaining work is the `[REVIEW]` Human AC for palette-by-palette readability — taste call only the human can make.

**Evidence:**
- `web/templates/arc_review.html` — `.headline-mechanic-box` now uses `color: var(--pico-color)` + `border-left: 3px solid var(--pico-primary)`. Forensic comment names T-2110 and explains why the previous combination failed.
- `/arcs/arc-grooming/review` renders 200 with the box visible and the headline_mechanic text inside it.
- `tests/playwright/test_arc_review_route.py::test_arc_review_headline_mechanic_box_visible_with_text` — added; passes.
- Live screenshot: <http://192.168.10.107:3000/static/ux-review/T-2110-headline-mechanic-fixed.png>
- Live page: <http://192.168.10.107:3000/arcs/arc-grooming/review>

**What's next:** Once you tick the `[REVIEW]` AC at <http://192.168.10.107:3000/review/T-2110>, the task moves to `.tasks/completed/`. The companion "larger screen disappears" issue you flagged needs your clarification before I can file it as a sibling task.

## Updates

### 2026-05-30T14:31:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2110-headline-mechanic-box-contrast--primary-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-44fb68d9
- **Timestamp:** 2026-05-30T14:36:20Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#5 (Agent)** — Playwright test `test_arc_review_headline_mechanic_box_visible_with_text` added to `tests/playwright/test_arc_review_route.py` — pins structural rendering; passes (34.2s).
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/playwright/test_arc_review_route.py in: Playwright test `test_arc_review_headline_mechanic_box_visible_with_text` added to `tests/playwright/test_arc_review_route.py` — pins structural rende`

### 2026-05-30T14:36:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
