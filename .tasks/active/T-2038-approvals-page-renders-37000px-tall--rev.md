---
id: T-2038
name: "approvals page renders 37000px tall — review queue has no pagination"
description: >
  Watchtower /approvals renders the entire review backlog (~120 items in one ungated
  DIV) as a 37,247px-tall page. Unusable endless-scroll for humans and pathological
  for tooling (it wedged the ux-review --sweep full_page screenshot until T-2005 added
  height-clipping). Grows unbounded with the backlog. Needs pagination / virtualization
  / collapse. Sibling to T-2035 (cockpit perf). Render surface — needs [REVIEW] Human
  AC.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc-007, perf, watchtower, approvals, ui, render-surface]
components: []
related_tasks: [T-2005, T-2035]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-25T09:59:50Z
last_update: 2026-05-25T10:06:09Z
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
cost_estimate_proposed:
  - ts: '2026-05-25T10:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-25T10:00:03Z'
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

# T-2038: approvals page renders 37000px tall — review queue has no pagination

## Context

Watchtower `/approvals` renders the entire review backlog (~120 items in one
ungated DIV) as a **37,247px-tall page** (`document.documentElement.scrollHeight`,
measured 2026-05-25). This is unusable endless-scroll for a human triaging the
queue, and it grows unbounded as the backlog accumulates. It also wedged the
`fw ux-review --sweep` full_page screenshot until T-2005 added height-clipping
(see `feedback_playwright_fullpage_wedge`). Sibling to T-2035 (cockpit perf):
a Watchtower page that scales pathologically with data volume. The fix should
bound the rendered height (pagination, virtualization, grouping/collapse, or a
"show N more" affordance) WITHOUT hiding items — every approval must remain
reachable. The mechanism is open; the outcome (bounded height + nothing lost)
is the contract.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `/approvals` renders with bounded height under a representative backlog: a Playwright/`scrollHeight` measurement of the loaded page stays below the `_safe_shot` cap (8000px), via pagination / virtualization / collapse — the chosen mechanism stated in `## Decisions`. Measured **6221px** with the live 108-card backlog (was 37,247px). Guarded by `tests/playwright/test_approvals_height.py::test_approvals_height_bounded`.
- [x] No items silently dropped: the count of approval/review items rendered-or-reachable on `/approvals` equals the backend's pending count (assert in a unit/integration test, or a curl+parse check). All **108** `.human-ac-group` cards present in DOM (15 visible + 93 in the collapsed overflow, all one click away). Guarded by `tests/playwright/test_approvals_height.py::test_approvals_items_reachable`.
- [x] After the fix, `fw ux-review --sweep` captures `/approvals` as `full` (not `clipped`) — the sweep report's Capture column shows `full` for `/approvals`. Confirmed in `docs/reports/T-2002-ux-review-arc-007-s0-s1.md` (`/approvals` row: `full`, was `⚠️ clipped @36938px`).

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
- [ ] [REVIEW] /approvals is usable after the height fix — the review queue reads cleanly and nothing important is hidden
  **Steps:**
  1. Open `http://192.168.10.107:3000/approvals` in a browser
  2. Confirm the page is a sane length (no endless scroll); paging/collapse is obvious and intuitive
  3. Confirm every pending item is still reachable (page through / expand groups) — cross-check the count against the cockpit's pending-approval number
  **Expected:** The queue is triage-able at a glance; the bounding mechanism (pages/collapse) is clear; no approval is silently dropped
  **If not:** Note where items feel hidden or the paging is confusing

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
curl -sf "$(bin/fw watchtower url)/approvals" >/dev/null
python3 -m pytest tests/playwright/test_approvals_height.py -q >/tmp/.t2038_pt.out 2>&1; tail -3 /tmp/.t2038_pt.out; grep -q "2 passed" /tmp/.t2038_pt.out

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

**Symptom:** `/approvals` rendered 37,247px tall (`document.documentElement.scrollHeight`) — endless-scroll for the human triaging the queue, and a 53-megapixel page that wedged the ux-review sweep's `full_page` screenshot (T-2005).

**Root cause:** The Verifications section renders every pending human-AC task — `{% for t in pending_acs %}` over ~108 cards — and each unchecked AC uses `<details ... open>`, so every card's Steps/Expected/If-not panel is expanded by default. Height grew linearly and unboundedly with the review backlog; there was no cap, pagination, or collapse.

**Why structurally allowed:** the page predates any backlog-size pressure (it was authored when ≤10 items were ever pending). Nothing measured rendered page height, so the page degraded silently as the backlog accumulated to ~120. It was data growth, not a code regression — which is exactly the class no existing gate watched. The latent brittleness only surfaced when the tall page broke a *tool* (the sweep), not because anyone noticed the page itself.

**Prevention:** `tests/playwright/test_approvals_height.py` now asserts `/approvals` scrollHeight stays under the 8000px `_safe_shot` cap regardless of backlog size, and that no card leaves the DOM when the overflow collapses. The ux-review sweep's Capture column (T-2005) is the second line of defence — any page that breaches the cap is flagged `⚠️ clipped @Npx` in `docs/reports/T-2002-*.md`, which is how `/fabric` (a sibling instance) was caught here.

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

### 2026-05-25 — chose collapse over pagination; discovered /fabric is a sibling
- **What changed:** The fix shipped as a collapsed-overflow `<details>` (render first 15, wrap the rest), not server-side pagination. Reason: the page polls itself every 10s (`hx-get /approvals/content`, replacing innerHTML), so any client-side page state would be wiped each cycle; a server-rendered `<details>` is poll-safe and keeps every item in the DOM. Empirically the cap had to drop from 25 → 15 to clear 8000px (25 open cards measured 9993px; 15 → 6221px) because each card's expanded AC steps are ~377px.
- **Plan impact:** Original task left the mechanism open ("pagination / virtualization / collapse"). Collapse won on poll-safety + minimal blast radius (template-only change, no new route).
- **Triggered:** The verification sweep flagged `/fabric` as `⚠️ clipped @33109px` — a second pathologically-tall page (same data-growth class, different surface). Out of scope for T-2038 (one bug = one task); filed as a sibling task for the /fabric height bound.

## Decisions

### 2026-05-25 — bounding mechanism
- **Chose:** Render the first 15 most-actionable verification cards (list is server-sorted by `(sort_priority, age)`), wrap cards 16..N in a collapsed `<details class="ac-overflow">`. Collapsed `<details>` content is `display:none` → excluded from `scrollHeight` and from `full_page` screenshots, yet stays in the DOM (reachable in one click). `filterACs()` auto-opens the overflow when a filter is active so a filtered match in the overflow still shows.
- **Why:** Poll-safe (survives the 10s htmx innerHTML swap, unlike client-side pagination state), zero new routes/endpoints, nothing dropped (every card reachable), and it directly bounds the metric the ACs measure (`scrollHeight`).
- **Rejected:** (1) *Server-side pagination* — page state wiped by the 10s poll; needs the poll URL to carry page params, more code, more review surface. (2) *Collapsing the per-AC step `<details>` to closed* — would shrink cards but defeats triage (the human reads steps inline) and 108 collapsed cards still ≈ 13k px. (3) *Virtualization (JS windowing)* — heavyweight for a polled fragment; overkill.

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

**Recommendation:** GO (ship the height bound)

**Rationale:** The one open AC is a `[REVIEW]` judgment call — whether the bounded `/approvals` reads cleanly and hides nothing important. All three Agent ACs are verified with evidence: height dropped 37,247px → 6,221px (under the 8000px cap), all 108 cards remain reachable, and the ux-review sweep now captures the page as `full`. The change is template-only (one file), poll-safe, and guarded by a new Playwright regression test. Nothing is dropped — the 93 lower-priority cards sit in a one-click "Show 93 more" disclosure, sorted so the most-actionable (review-priority, oldest) stay visible.

**Evidence:**
- `scrollHeight` 37,247px → **6,221px** (Playwright measurement, live 108-card backlog)
- **108/108** verification cards in the DOM (15 visible + 93 in collapsed overflow)
- `docs/reports/T-2002-ux-review-arc-007-s0-s1.md`: `/approvals` Capture column = `full` (was `⚠️ clipped @36938px`)
- `tests/playwright/test_approvals_height.py` — 2 passed (height-bounded + items-reachable)
- Screenshot: `web/static/ux-review/T-2038-approvals-bounded.png` (served live)
- Commits: `8cfb777e` (fix) + `69cc6f5d` (fabric card), pushed to origin

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-25T09:59:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2038-approvals-page-renders-37000px-tall--rev.md
- **Context:** Initial task creation

### 2026-05-25T10:02:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-25T10:05:36Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-05-25T10:06:09Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
