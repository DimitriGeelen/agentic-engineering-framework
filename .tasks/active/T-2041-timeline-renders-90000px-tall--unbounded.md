---
id: T-2041
name: "timeline renders 90000px tall — unbounded grouped event lists (T-2038 class)"
description: >
  Height-bomb class found by the T-2039 page-height sweep: /timeline renders 90,283px
  — the tallest instance (1001 nodes; several UL event-lists of ~175 items each, grouped
  by period). Same class as T-2038/T-2039/T-2040. Grouped-list shape → bound via per-group
  collapse or a scroll container, keeping all events reachable. Render surface — needs
  [REVIEW]. Verify via tests/playwright (scrollHeight<8000) + sweep Capture full.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [arc-007, perf, watchtower, timeline, ui, render-surface]
components: [agents/ux-review/ux-review.py, 
      tests/playwright/test_timeline_height.py, 
      tests/unit/test_ux_review_routes.py, web/templates/timeline.html]
related_tasks: [T-2038, T-2039, T-2005]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-25T13:52:08Z
last_update: '2026-06-11T22:23:30Z'
date_finished: 2026-05-26T06:54:17Z
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
  - ts: '2026-05-25T14:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-25T14:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:30Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 3
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=3 (body:fw-recall-or-memory-link); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2041: timeline renders 90000px tall — unbounded grouped event lists (T-2038 class)

## Context

4th and last instance of the unbounded-page class (T-2038 /approvals, T-2039 /fabric,
T-2040 /inception). `/timeline` loops `{% for session in sessions %}` over **all ~580
handover files** (newest-first), each a collapsed-`<details>` `<article>`. Inner content
is already collapsed (excluded from scrollHeight); the 90,283px comes purely from the
*count* of summary rows. Card-list shape → same fix as T-2040: render the first N sessions
inline, wrap older ones in a collapsed outer `<details class="timeline-overflow">`
(nesting `<details>` is legal; collapsed content is excluded from scrollHeight AND
full_page screenshots, yet stays in the DOM, one click away — nothing dropped).
See [[project_unbounded_watchtower_pages]].

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] /timeline rendered scrollHeight drops below the 8000px `_safe_shot` cap (from 90,283px), verified by a live playwright probe of the running Watchtower — measured **90,477px → 4,351px**
- [x] Every session `<article>` stays in the DOM: opening `.timeline-overflow` leaves the article count unchanged (collapsed, never truncated) — **1001 → 1001** after expand
- [x] `tests/playwright/test_timeline_height.py` added with two tests (height-bounded + items-reachable), both pass — **2 passed in 33s**
- [x] New test registered in the component fabric (`fw fabric register`) — `.fabric/components/tests-playwright-test_timeline_height.yaml`

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
- [ ] [REVIEW] /timeline reads cleanly after the height fix
  **Steps:**
  1. Open http://192.168.10.107:3000/timeline
  2. Confirm the newest sessions render inline and the page no longer endless-scrolls
  3. Find the "Show N older sessions" affordance; click it and confirm older history expands in place
  **Expected:** Newest sessions visible at a glance; the collapse affordance is discoverable and labelled; clicking it restores the full chronological history without a reload
  **If not:** Note which sessions feel like they should be inline vs collapsed, and whether the affordance label reads clearly

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

curl -sf "$(bin/fw watchtower url)/timeline" >/dev/null
python3 -m pytest tests/playwright/test_timeline_height.py -q 2>&1 | tail -3
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

**Symptom:** `/timeline` rendered 90,477px tall (1001 `<article>` cards). Endless-scroll
for humans; the ux-review `full_page` capture wedges past the 8000px cap.

**Root cause:** The template loops `{% for session in sessions %}` over **every** handover
file in `.context/handovers/` with no height bound. The corpus grows by one card every
session (handovers are append-only), so the page degrades monotonically — it was usable at
100 sessions, unusable at 1001. Same data-growth class as T-2038/T-2039/T-2040.

**Why structurally allowed:** The ux-review sweep is the detector for this class, but its
PAGES list covers only 5 routes (`/`, `/tasks`, `/approvals`, `/fabric`, `/arcs`).
`/timeline` (and `/inception`) were never in scope, so the height regression was invisible
to automated tooling — found only by a manual all-routes probe. This is the same coverage
hole flagged in T-2040's Evolution (G-019 root: the detector exists but its scope is too
narrow to catch new instances).

**Prevention:** (1) `tests/playwright/test_timeline_height.py` pins scrollHeight < 8000 and
no-card-dropped — guards *this* page forever. (2) The systemic prevention — widening the
ux-review sweep PAGES list so the class detector catches the *next* unbounded page
automatically — remains the open follow-up (see Evolution). This task fixes the symptom and
adds a per-page guard; it does not close the detector-coverage gap.

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

### 2026-05-25 — closing the 4-instance class, but not the detector gap

- **What changed:** The /timeline shape turned out *simpler* than the filing note guessed.
  The note said "several UL event-lists of ~175 items each, grouped by period" (read from a
  DOM probe of nested content). The actual template is a flat loop of 1001 `<article>`s,
  each already a collapsed `<details>` — the inner ULs were never the height driver; the
  *count of summary rows* was. So the fix was the plain T-2040 card-list pattern (cap +
  collapse outer `<details>`), not a per-group collapse. avg article ≈ 97px → cap 40 ≈ 4.0k px.
- **Plan impact:** No per-group/period grouping needed. One `_tl_cap` + one nested
  `<details>` wrapper — ~10 template lines, mirroring T-2040 exactly.
- **Triggered:** This is instance 4/4 of the unbounded-page class — the class is now fully
  swept on the pages found. The remaining systemic work is **widening the ux-review sweep
  PAGES list** so the *detector* covers all routes (currently 5/N). That is a separate
  tooling task (small) and is NOT done here — filing/doing it is the genuine next step.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Recommendation

**Recommendation:** GO

**Rationale:** 4th and final instance of the unbounded-page class is fixed with the
established T-2040 pattern. /timeline drops from 90,477px to 4,351px while keeping all
1001 session cards in the DOM (collapsed, one click away — verified count unchanged after
expand). A playwright regression test pins both invariants and the test is registered in
the fabric. Only the visual-rhythm judgment (does the inline/collapsed split read well?)
remains for human taste.

**Evidence:**
- scrollHeight: **90,477px → 4,351px** (live playwright probe, `< 8000px` cap)
- DOM cards: **1001 → 1001** after opening `.timeline-overflow` (nothing dropped)
- `tests/playwright/test_timeline_height.py`: **2 passed in 33s**
- Eyes-on screenshot: http://192.168.10.107:3000/static/ux-review/T-2041-timeline-bounded.png
- Template: `web/templates/timeline.html` — `_tl_cap = 40`, nested `<details class="timeline-overflow">`

## Updates

### 2026-05-25T13:52:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2041-timeline-renders-90000px-tall--unbounded.md
- **Context:** Initial task creation

### 2026-05-25T14:38:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7d2ff650
- **Timestamp:** 2026-05-26T06:54:58Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#4 (Agent)** — New test registered in the component fabric (`fw fabric register`) — `.fabric/components/tests-playwright-test_timeline_height.yaml`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=fabric/components/tests-playwright-test_timeline_height.yaml in: New test registered in the component fabric (`fw fabric register`) — `.fabric/components/tests-playwright-test_timeline_height.yaml``

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 19
     - evidence: `curl -sf "$(bin/fw watchtower url)/timeline" >/dev/null`

### 2026-05-26T06:54:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
