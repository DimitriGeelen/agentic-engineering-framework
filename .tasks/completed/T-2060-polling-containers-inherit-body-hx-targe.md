---
id: T-2060
name: "polling containers inherit body hx-target=#content — innerHTML swap destroys
  page-header"
description: >
  Bug: <body hx-boost='true' hx-target='#content' hx-swap='innerHTML'> at base.html:506
  sets a body-level hx-target. Two polling containers (approvals.html line 222, review.html
  line 591) declare hx-get/hx-trigger/hx-swap but do NOT override hx-target. By htmx
  attribute inheritance, the 10s/5s polls swap their response into #content (whole
  page area) rather than the polling div itself. Result: after first poll, page-header
  h1, breadcrumbs, Pin button, and outer styling are destroyed; stats render as plain
  text with no boxes. Reproduced via Playwright t0 vs t25 on /approvals. Fix: add
  hx-target='this' to each polling div. Arc: arc-007 (interface redesign — render
  fidelity).

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [bug, htmx, polling, watchtower, render-fidelity, arc-007]
components: [lib/render_surface.sh, tests/unit/test_render_surface_gate.bats, 
      web/templates/approvals.html, web/templates/review.html, 
      web/templates/base.html]
related_tasks: [T-669, T-2038, T-2039, T-2040, T-2041]
arc_id: arc-007
created: 2026-05-28T08:03:48Z
last_update: '2026-06-11T22:24:06Z'
date_finished: 2026-05-28T14:07:08Z
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
  - ts: '2026-05-28T08:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-28T08:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2060: polling containers inherit body hx-target=#content — innerHTML swap destroys page-header

## Context

User-reported (S-2026-0528-0117 continuation): on `/approvals`, every section is enclosed by a lightly-shaded box at page load; the boxes disappear after 15-30 seconds. Reproduced via Playwright t0 (boxed stat cards "0 Decisions / 2 Arc Closure / 137 Verifications / 123 Total") vs t25 (same numbers, flowing plain text, page-header h1 and breadcrumbs also gone).

**Mechanism.** `web/templates/base.html:506` declares `<body hx-boost="true" hx-target="#content" hx-swap="innerHTML">`. Two polling containers (`approvals.html:222` every 10s, `review.html:591` every 5s) declare `hx-get`/`hx-trigger`/`hx-swap` but DO NOT override `hx-target`. By htmx attribute inheritance, the inherited `hx-target="#content"` makes the periodic GET swap its response into the *whole* content area rather than the polling div itself. Page-header, breadcrumbs, and surrounding wrappers (which the fragment template does not include) are destroyed; the result is the same fragment markup floating in a re-targeted container with broken structure.

**Fix.** One-line per template: add `hx-target="this"` to the polling div, overriding the inherited attribute. htmx then swaps innerHTML of the polling element itself (the original intent).

## Acceptance Criteria

### Agent
- [x] `web/templates/approvals.html:222` polling div carries explicit `hx-target="this"` overriding the body-level `#content` inheritance.
- [x] `web/templates/review.html:591` polling div carries explicit `hx-target="this"` for the same reason.
- [x] `curl -sf $(bin/fw watchtower url)/approvals | grep -q 'id="approvals-content"' && curl -sf $(bin/fw watchtower url)/approvals | grep -q 'hx-target="this"'` — server-rendered approvals page contains the override.
- [x] Playwright re-test: load `/approvals`, wait 25s (one full polling cycle), screenshot — the four stat cards "Decisions / Arc Closure / Verifications / Total" remain boxed and aligned in a grid; page-header h1 "Approvals (N pending)" remains visible; breadcrumbs + Pin button remain present. Evidence: `approvals-t25-fixed.png` (124 pending, all chrome intact) vs `approvals-t25.png` (pre-fix, chrome gone, plain text flow).

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

- [x] [REVIEW] `/approvals` and `/review/T-XXX` retain layout integrity across polling cycles
  **Steps:**
  1. Open [http://192.168.10.107:3000/approvals](http://192.168.10.107:3000/approvals)
  2. Note the four stat cards "Decisions / Arc Closure / Verifications / Total" rendered as boxed cards in a grid
  3. Wait 30 seconds (past the 10s poll cycle and one or two more)
  4. Open any [http://192.168.10.107:3000/review/T-2058](http://192.168.10.107:3000/review/T-2058) (or another active task with Human ACs)
  5. Wait 30 seconds again
  **Expected:** On both pages the page-header h1 ("Approvals (N pending)" / task name), breadcrumbs, Pin button, and stat-card grid layout REMAIN present and styled across the polling cycle — no plain-text flow, no missing chrome, no flicker.
  **If not:** Note which element vanished, take a screenshot at t0 and t25, file as a follow-up bug citing this task.

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

curl -sf "$(bin/fw watchtower url)/approvals" -o /tmp/.t2060-approvals.html && grep -q 'id="approvals-content"' /tmp/.t2060-approvals.html
grep -q 'hx-target="this"' /tmp/.t2060-approvals.html
n=$(grep -l 'hx-trigger="every' web/templates/approvals.html web/templates/review.html | wc -l); test "$n" = "2"
grep -A1 'hx-trigger="every' web/templates/approvals.html web/templates/review.html > /tmp/.t2060-trigger.txt; n=$(grep -c 'hx-target=' /tmp/.t2060-trigger.txt); test "$n" = "2"

## RCA

**Symptom.** /approvals (and likely /review/T-XXX) loses its page-header h1, breadcrumb nav, and stat-card layout 10s after page load. User-visible: "each section has a box around it, lightly shaded, this disappears after 15-30 seconds".

**Root cause.** `base.html:506` sets `<body hx-boost="true" hx-target="#content" hx-swap="innerHTML">` as a global default. htmx attribute inheritance propagates `hx-target` to descendants that don't override it. Two polling containers (`approvals.html:222`, `review.html:591`) declared `hx-get`/`hx-trigger`/`hx-swap` but forgot `hx-target`. The first poll therefore swapped `/approvals/content` into `#content` (whole page area) rather than `#approvals-content` (the polling div). Markup outside the fragment was destroyed; markup inside the fragment was reparented into a wrapper-less context with broken styling cascades.

**Why structurally allowed.** htmx attribute inheritance is silent and convenient — it's correct for boosted nav links (every `<a>` shouldn't repeat `hx-target="#content"`). But it's a footgun for polling containers, which conceptually want to swap themselves, not the page. Nothing in the codebase warned about it: no linter, no test, no template-author comment near `<body hx-boost>` explaining that polling containers must override.

**Prevention.** Add a `tests/playwright/` regression that loads `/approvals`, waits past the 10s poll, and asserts page-header h1 + stat-card grid layout remain present. The render-surface gate (P-013) already requires a `[REVIEW]` Human AC; the Playwright test guards it forever after. Filed as L-438 (separate commit): "htmx hx-boost on `<body>` with hx-target=#content silently breaks any descendant polling container that doesn't override hx-target — always set hx-target='this' on `hx-trigger='every'` divs."

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

### 2026-05-28 — htmx polling + L-387 verification authoring trap surfaced together
- **What changed:** Two things learned at the close-gate that weren't visible at filing. (1) The original Verification block (`out=$(cmd); echo "$out" | grep -q PATTERN`) crashed with SIGPIPE/exit-141 on three out of four lines — L-387 class — because the `echo "$out"` upstream gets SIGPIPE when grep -q matches and closes stdin early. The "safe capture" pattern in CLAUDE.md was *necessary but not sufficient*: capturing to a variable doesn't help if you still pipe to grep -q. The truly safe pattern is "capture-to-file, grep-the-file" (no pipe at all). (2) The pre-fix render bug was wider than just /approvals — `/review/T-XXX` also polls every 5s and silently destroyed its own chrome the same way; the [REVIEW] Human AC was rightly written to cover both surfaces.
- **Plan impact:** The Verification commands were rewritten from `out=$(...); echo "$out" | grep -q ...` to `cmd -o /tmp/.x && grep -q PATTERN /tmp/.x`. T-2057 (L-387 detector spike) is filed and recommends GO on a reviewer pattern + started-work advisory; this task's Verification rewrite is a worked example for that detector's pattern catalogue.
- **Triggered:** No new sub-task — the L-387 pattern already has a spike report (`docs/reports/T-2057-l-387-detector-spike.md`) and T-2059 shipped the reviewer pattern. This task's authoring just *confirmed the spike's reach estimate* (the corpus scan caught 280 flagged tasks; this one was one of the 280-class siblings hiding in newly-authored Verification blocks).

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

### 2026-05-28 — choice of override token (`"this"` vs `"#approvals-content"`)
- **Chose:** `hx-target="this"`
- **Why:** Self-referential, immune to id renaming. Same fix shape works for both templates with no per-id customisation. Matches the htmx idiom for self-swapping polling.
- **Rejected:** `hx-target="#approvals-content"` (and `#ac-container` on review.html) — works but couples the override to the id; future refactor that renames the container would silently re-introduce the bug.

## Recommendation

**Recommendation:** GO

**Rationale:** Two-line template fix; both surfaces verified end-to-end via Playwright (t25-fixed.png shows full chrome + boxed stats intact after polling cycle). RCA captures the htmx-inheritance footgun; the Verification commands pin the override structurally; the [REVIEW] Human AC asks the user to confirm both surfaces (`/approvals` AND `/review/T-XXX`) render correctly across a full poll cycle. Origin signal: user-reported via screenshot description in S-2026-0528-0117 continuation.

**Evidence:**
- Pre-fix Playwright screenshot: `approvals-t25.png` (boxes gone, page-header gone, plain text flow)
- Post-fix Playwright screenshot: `approvals-t25-fixed.png` (boxes intact, page-header "Approvals (124 pending)" intact, breadcrumbs + Pin button visible)
- Server-side verification: `curl -sf .../approvals | grep -q 'hx-target="this"'` ✓
- Both templates audited: `grep 'hx-trigger="every"' web/templates/*.html` → 2 polling containers, BOTH now carry `hx-target="this"` (verification command #4)
- Root cause structurally documented in RCA section; prevention captured as L-438 (separate commit).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-28T08:03:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2060-polling-containers-inherit-body-hx-targe.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1fbf9614
- **Timestamp:** 2026-06-02T15:00:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-28T14:07:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
