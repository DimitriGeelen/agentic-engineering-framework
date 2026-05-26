---
id: T-2040
name: "inception board renders 83000px tall — unbounded card list (T-2038 class)"
description: >
  Height-bomb class found by the T-2039 page-height sweep: /inception renders 83,146px
  (354 inception cards in one container, no bound). Same class as T-2038 (/approvals)
  / T-2039 (/fabric). Card-list shape → bound via collapse-overflow <details> (the
  T-2038 mechanism), keeping all cards reachable. Render surface — needs [REVIEW].
  Verify via tests/playwright (scrollHeight<8000) + sweep Capture full.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [arc-007, perf, watchtower, inception, ui, render-surface]
components: [tests/playwright/test_inception_height.py, tests/playwright/test_timeline_height.py, web/templates/inception.html, web/templates/timeline.html]
related_tasks: [T-2038, T-2039, T-2005]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-25T13:51:59Z
last_update: 2026-05-26T06:53:44Z
date_finished: 2026-05-26T06:53:44Z
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
  - ts: '2026-05-25T13:54:41Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-25T14:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2040: inception board renders 83000px tall — unbounded card list (T-2038 class)

## Context

Third instance of the unbounded-page class (after T-2038 `/approvals`, T-2039 `/fabric`),
found by a page-height sweep across all major Watchtower pages. `/inception` rendered
83,146px — `web/templates/inception.html` loops `{% raw %}{% for t in inception_tasks %}{% endraw %}`
over **349 `<article>` cards** with no bound. Card-list shape (same as `/approvals`), so
the fix is the collapsed-`<details>` overflow: render the first N, wrap the rest in a
collapsed `<details>` (display:none → excluded from scrollHeight + full_page shots, still
in the DOM). The page already has All/Active/Pending/GO/NO-GO filters for narrowing.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `/inception` renders with bounded height regardless of inception count: a Playwright/`scrollHeight` measurement of the loaded page stays below the `_safe_shot` cap (8000px), via a collapsed-`<details>` overflow (the T-2038 mechanism; stated in `## Decisions`). Measured **5,194px** (was 83,146px). Guarded by `tests/playwright/test_inception_height.py::test_inception_height_bounded`.
- [x] No inceptions dropped: all `<article>` inception cards remain in the DOM and reachable (the overflow is one click away) — DOM card count is unchanged when the overflow opens. All **349** cards present (20 visible + 329 in the collapsed overflow). Guarded by `tests/playwright/test_inception_height.py::test_inception_items_reachable`.
- [x] After the fix, `fw ux-review --sweep` (extended to include `/inception`) or a direct scrollHeight check confirms `/inception` is no longer clipped (< 8000px). Direct Playwright scrollHeight check: **5,194px < 8,000px**.

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
- [ ] [REVIEW] /inception is usable after the height fix — the board reads cleanly and no inception is hidden
  **Steps:**
  1. Open `http://192.168.10.107:3000/inception` in a browser
  2. Confirm the page is a sane length (no 83k-px endless scroll); the "Show N more" disclosure is obvious
  3. Confirm every inception is reachable (expand the overflow); spot-check the All/Active/Pending/GO/NO-GO filters still work
  **Expected:** The board is scannable at a glance; the bounding mechanism is clear; no inception is silently dropped; filters work
  **If not:** Note where inceptions feel hidden or the disclosure is confusing

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
curl -sf "$(bin/fw watchtower url)/inception" >/dev/null
python3 -m pytest tests/playwright/test_inception_height.py -q >/tmp/.t2040_pt.out 2>&1; tail -3 /tmp/.t2040_pt.out; grep -q "2 passed" /tmp/.t2040_pt.out

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

**Symptom:** `/inception` rendered 83,146px tall — the inception board scrolled endlessly with 349 cards stacked in one container.

**Root cause:** `web/templates/inception.html` renders every inception as an `<article>` — `{% raw %}{% for t in inception_tasks %}{% endraw %}` over all 349, no bound. Height grew linearly and unboundedly as inceptions accumulated (many are decided GO/NO-GO and never pruned).

**Why structurally allowed:** identical class to T-2038/T-2039 — page authored when there were few inceptions, nothing measured rendered height, silent degradation with data growth. **Compounding cause specific to this instance:** the ux-review sweep (T-2005, the class detector) only covers 5 pages (`/`, `/tasks`, `/approvals`, `/fabric`, `/arcs`) — `/inception` was never in its page list, so the detector was blind to it. It took a manual all-pages height sweep (this session) to find it.

**Prevention:** `tests/playwright/test_inception_height.py` asserts `/inception` scrollHeight < 8000px and that no card leaves the DOM. **Broader prevention (the G-019 root):** the ux-review sweep's page list should be widened to all major routes so the recurring detector covers them — captured in `## Evolution` as a follow-up so the next instance is caught automatically, not by manual probe.

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

### 2026-05-25 — the detector had a coverage hole
- **What changed:** This is the 3rd instance of the unbounded-page class in one session. The first two (`/approvals`, `/fabric`) were caught by the ux-review sweep because they are in its 5-page list. `/inception` (and `/timeline`, T-2041) were NOT — they surfaced only via a manual all-pages height probe. The detector's value is bounded by its page list.
- **Plan impact:** The collapse mechanism transferred cleanly from T-2038 (card-list shape). No surprises in the fix.
- **Triggered:** Identified a prevention follow-up — widen the ux-review sweep's `PAGES` list (or add a dedicated all-routes height check) so the recurring detector covers every major route. Not done in this task (scope: fix `/inception`); noted here and worth a small tooling task so the next instance is caught automatically. Sibling T-2041 (`/timeline`, 90k px) filed and pending.

## Decisions

### 2026-05-25 — bounding mechanism
- **Chose:** Render the first 20 inception `<article>` cards, wrap the rest in a collapsed `<details class="inc-overflow">` ("Show N more inceptions"). Collapsed content is display:none → excluded from scrollHeight and full_page screenshots, still in the DOM and one click away.
- **Why:** Same card-list shape as `/approvals`, so the T-2038 mechanism transfers directly; zero JS; nothing dropped; bounds the measured metric (33,153→… measured 83,146→5,194px). The existing All/Active/Pending/GO/NO-GO filters complement it for narrowing.
- **Rejected:** (1) *Scroll container (the T-2039 table fix)* — works, but the collapse-overflow keeps the most-recent cards inline without an inner scrollbar, which reads better for a card board. (2) *Server-side pagination* — more code, no benefit over collapse here.

## Recommendation

**Recommendation:** GO (ship the height bound)

**Rationale:** The one open AC is a `[REVIEW]` judgment call. All three Agent ACs verified: height 83,146px → 5,194px (under cap), all 349 cards reachable, direct scrollHeight check passes. Template-only change, zero JS, guarded by a new Playwright regression test. Third instance of the class fixed; the detector-coverage gap is captured for follow-up.

**Evidence:**
- `scrollHeight` 83,146px → **5,194px** (Playwright)
- **349/349** inception cards in DOM (20 visible + 329 in collapsed overflow)
- `tests/playwright/test_inception_height.py` — 2 passed
- Screenshot: `web/static/ux-review/T-2040-inception-bounded.png` (served live)

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-25T13:51:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2040-inception-board-renders-83000px-tall--un.md
- **Context:** Initial task creation

### 2026-05-25T13:54:41Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-87ca6d50
- **Timestamp:** 2026-05-26T06:54:11Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 25
     - evidence: `curl -sf "$(bin/fw watchtower url)/inception" >/dev/null`

### 2026-05-26T06:53:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
