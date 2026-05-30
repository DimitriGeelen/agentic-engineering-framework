---
id: T-2115
name: "L-438 detector inception — htmx hx-target inheritance bounce-back detector
  class"
description: >
  After 3 instances (T-2112, T-2113, T-2114) of the same bug class in 1 day, file
  an inception to scope a structural detector. Class: any boost-anchor descendant
  of a polling container with hx-target='this' is a bounce-back candidate. Options:
  (a) Jinja-level static scan of templates; (b) Playwright class-wide test that walks
  every polling container; (c) htmx CSP/strict-mode signal. Inception output: GO/NO-GO/DEFER
  on which prevention approach to pursue.

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: [inception, watchtower, htmx, arc-007, detector]
components: []
related_tasks: [T-2112, T-2113, T-2114, T-2060]
arc_id: watchtower-redesign
created: 2026-05-30T16:44:31Z
last_update: '2026-05-30T16:45:02Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-30T16:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 2
      F1: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-30T16:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2115: L-438 detector inception — htmx hx-target inheritance bounce-back detector class

## Problem Statement

Three independent instances of the same htmx `hx-target` inheritance bug class shipped in a single day (2026-05-30):

- **T-2112** — `/approvals` arc-closure card Review/Approve/anchor links bounced back after 10 s
- **T-2113** — `/cockpit` Recent Activity task links bounced back after 15 s
- **T-2114** — `/review/T-XXX` AC fragment Reload-page link + markdown-rendered URLs bounced back after 5 s

All three share one mechanism: a polling container (`hx-target="this" hx-trigger="every Ns"`) propagates its `hx-target` to descendant boost-anchors. Click → swap into polling div → ≤N s later polling overwrites the swap → bounce-back. Documented in L-438 (T-2060) for the descending case; the ascending case was hit-by-hit until now.

**For whom:** any human using Watchtower (reported by user as "larger screen disappears after no to much time"). **Why now:** the third instance landed in the same session pair — pattern has crossed the noise threshold.

See `docs/reports/T-2115-l438-detector-inception.md` for full analysis.

## Assumptions

A1. The bug class is finite — bounded by the templates currently running polling containers (3 known: approvals, cockpit, review). Validated by `grep -rln 'hx-target="this"' web/templates/` cross-referenced with `hx-trigger.*every` — 3 polling-container surfaces match, no others.

A2. A run-time DOM scan via Playwright will catch both static and markdown-rendered anchors. Validated by T-2114 where curl of the rendered fragment showed markdown-URLs alongside the explicit anchor.

A3. The existing all-routes pattern (T-2042's `test_all_routes_height.py`) can be reused as the detector scaffold. To validate via spike when GO.

## Exploration Plan

Spike S1 (time-box: 30 min) — confirm A1 by enumerating all current polling containers + their descendant anchors. Done during T-2114 build; result: 3 surfaces, ~6 distinct anchor types, all already fixed.

Spike S2 (time-box: 1 h, GO-only) — adapt `test_all_routes_height.py` shape into a polling-container inheritance scanner. Each route's rendered DOM is scanned for `[hx-target="this"][hx-trigger*="every "]` containers; for each, descendant `<a hx-boost!="false">` elements are checked for own `hx-target` or wrapper-reset ancestor.

## Technical Constraints

- Detector runs under existing `fw test playwright` infrastructure (TEST_PORT=3099 fixture conftest pattern).
- Browser/DOM access via Playwright (already a dependency).
- Routes requiring authentication / state setup may need fixtures or `--skip` lists — accept that 100% route coverage is not achievable in v1.

## Scope Fence

**IN:** detector for the ascending-inheritance case (descendant boost-anchor inside `hx-target="this"` container). Run-time Playwright. Reports findings as test failures. Covers explicit anchors AND markdown-rendered anchors.

**OUT:** retroactive scanning of `hx-boost` semantics changes (htmx version bumps); CSP-level strict-mode (Option C — researched separately if Option B proves insufficient); fix of any found regressions (those would be sibling per-instance build tasks).

**OUT (deferred):** Jinja-level static scan (Option A) — would close ~70% of the class but miss markdown-rendered URLs, which is the exact instance that motivated the detector.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated — 3 instances cited (T-2112/T-2113/T-2114), all in same session pair, all confirmed sharing L-438 ascending-inheritance mechanism.
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested — A1 validated via grep enumeration (3 polling surfaces); A2 validated via T-2114 markdown-URL capture; A3 to be validated only on GO (S2 spike).
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale — GO on Option B, citing run-time DOM coverage + existing T-2042 infrastructure pattern.

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO on Option B (Playwright class-wide detector).

**Rationale:** Three instances in one day cross the noise threshold. A static-scan-only detector (Option A) closes ~70% of the class but misses the markdown-rendered URL case (T-2114's specific symptom). The run-time DOM scan covers both static and dynamic anchors, reuses the existing `test_all_routes_height.py` shape (T-2042), and adds bounded cost (3-5 h). Option C (CSP/strict-mode) is unbounded research; defer until B is in place.

**Evidence:**
- 3 bug-task fixes shipped 2026-05-30 (T-2112 + T-2113 + T-2114) — all same root cause class, all same arc (arc-007).
- L-438 (T-2060) documented the descending case 21 d ago; the ascending case is the inverse and has now hit 3 surfaces.
- Per-anchor triplet fix shape vs wrapper-reset fix shape diverged between T-2113 (triplet) and T-2114 (wrapper) — future template authors will guess without a structural guard.
- The detector scaffold pattern is established (T-2042 `discover_get_routes()` + per-route Playwright sweep). Cost is incremental, not net-new infra.
- Research artifact: `docs/reports/T-2115-l438-detector-inception.md` — full option analysis (A/B/C/D) with pros/cons/scope estimates.

**GO decision unblocks:** build task T-2116 candidate — `tests/playwright/test_all_polling_containers_inheritance.py` adapting the T-2042 shape.

**Hand to human:** `fw task review T-2115` (Watchtower decision form; CLAUDECODE-gated per T-1671 — agent cannot decide).

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
