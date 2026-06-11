---
id: T-2000
name: "Specialised UX-review TermLink agent + enforce executed-browser review on render
  surfaces — go/no-go"
description: >
  Explore whether the framework should add a specialised UX/visual-review agent (browser-driving,
  executes JS, assesses interactive render surfaces) via TermLink, and enforce executed-browser
  review on render-surface tasks before completion. Origin: T-1988/T-1999 — S1 shipped
  functionally broken (dead preset JS) despite existing static reviewers; verification
  was server-side/markup only.

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: [watchtower, review, inception, ux]
components: []
related_tasks: [T-1988, T-1999, T-1443]
created: 2026-05-23T11:36:05Z
last_update: '2026-06-11T22:24:05Z'
date_finished: 2026-05-23T14:32:27+02:00
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
cost_estimate_proposed:
  - ts: '2026-05-23T11:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-29T09:45:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-23T11:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-2000: Specialised UX-review TermLink agent + enforce executed-browser review on render surfaces — go/no-go

## Problem Statement

The framework already has specialised review agents (the static-scan `fw reviewer`, T-1443;
TermLink dispatch, T-1951) — yet arc-007 S1 (T-1988) shipped **functionally broken**: a JS
`SyntaxError` left every preset button dead, and it passed every check because verification was
server-side (curl round-trip) and markup-presence (grep) only. No agent ever *executed the page's
JS in a browser*. The `[REVIEW]` Human AC was the sole net — and it was never exercised before the
GO. So: interactive render surfaces can pass governance while being dead to a real user, and the
existing reviewers don't cover this class. **Question:** should the framework add a specialised
UX/visual-review agent (browser-driving) and *enforce* executed-browser review on render-surface
tasks before completion? Origin: user prompt after the T-1999 fix — "we have specialised review
agents in termlink for this, maybe we also need a specialised UX review termlink agent and enforce
that type of review to take place."

Candidate approaches (to compare during exploration):
- **A — Enforcement-only (lightest):** extend the render-surface gate (T-1766) so a render-surface
  build task whose page contains inline `<script>`/interactive handlers MUST ship a Playwright test.
  No new agent — L-423 already mandates this by convention; make it structural. Closes the exact
  dead-JS class.
- **B — Extend `fw reviewer` with a browser-driving mode:** add a `--ux` Playwright mode to the
  existing reviewer (loads page, asserts zero console errors, smoke-clicks interactive controls,
  asserts a state change). Reuses reviewer infra + TermLink isolation (T-1951); one agent, two modes.
- **C — New dedicated UX-review TermLink agent:** a separate specialised agent (screenshots,
  console-error scan, interaction smoke, optional LLM visual critique of layout/contrast/coherence),
  dispatched via TermLink, with its own enforcement hook.

Key tension: **A** is cheap and closes the proven gap structurally; **C** is powerful but heavy and
its visual-critique half is fuzzy (taste is the human's job — see T-1811 `[REVIEW]` vs `[REVIEWER]`);
**B** is the middle path. The honest default may be "A now, B/C only if evidence shows the class is
broader than dead-JS."

## Assumptions

<!-- Register with: fw assumption add "Statement" --task T-2000 -->
- A1: The dead-interactive-render class recurs (not a one-off) — testable by mining completed
  render-surface build tasks for ones lacking any Playwright/executed-JS coverage.
- A2: A structural gate (A) catches the class without a new agent — testable by checking whether a
  "render-surface + inline-script ⇒ require Playwright test" rule would have blocked T-1988.
- A3: LLM/visual critique (C) adds value beyond "no console errors + interaction smoke" — needs a
  spike; risk of duplicating the human `[REVIEW]` taste call rather than complementing it.

## Exploration Plan

<!-- Time-boxed; this inception is SCOPED here, not yet executed. -->
1. (30m) Mine episodic + completed/ for render-surface build tasks; count those with no executed-JS
   coverage → sizes A1, decides whether enforcement is worth structural cost.
2. (30m) Prototype the gate for approach A (does it cleanly block a T-1988-shaped task?). Cheapest
   prevention; establishes the baseline B/C must beat.
3. (45m) Spike approach B: a `fw reviewer --ux` Playwright pass on /settings/appearance — would it
   have flagged the SyntaxError? Assess reuse vs new-agent cost.
4. (writeup) Recommendation GO/NO-GO/DEFER per Go/No-Go Criteria; the human decides (sovereignty).

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN:** deciding *whether* to enforce executed-browser review on render-surface tasks, and *which*
approach (A enforcement-only / B reviewer `--ux` mode / C new UX agent); the time-boxed mining +
spikes that inform that decision.
**OUT:** building the full UX agent or any LLM visual-critique (those are post-GO build tasks);
making the *taste* call on arc-007's visual design (that stays the human `[REVIEW]`); changing the
existing static `fw reviewer` behaviour beyond an additive mode.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

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
- Mining shows the dead-interactive-render class recurs (≥2-3 render-surface tasks with no executed-JS coverage), AND
- A bounded approach (likely A, possibly B) would have blocked the T-1988-shaped failure, with acceptable cost and clear reversibility

**NO-GO if:**
- T-1988 is effectively a one-off already covered by L-423 + the per-task Playwright rule (T-971) + the render-surface gate — a new agent/gate is unjustified overhead, OR
- The only meaningful addition is fuzzy LLM visual critique that duplicates the human `[REVIEW]` taste call rather than complementing it

**DEFER if:**
- Insufficient evidence (mining step not yet run) — capture and revisit when an interface-arc slice next touches an interactive surface

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

**Recommendation:** GO — scope **A + C** (B dropped per human direction, 2026-05-23)

**Rationale:** Two complementary layers, chosen by the human after the T-1988 incident:
- **A (enforcement)** is the structural floor — a render-surface build task whose page carries inline
  `<script>`/interactive handlers must ship a Playwright test. Cheap, deterministic, and would have
  *blocked* T-1988 outright. This is prevention; it can't be skipped or forgotten.
- **C (dedicated UX-review TermLink agent)** is the qualitative layer — runs the page in a real
  browser, scans console errors, smoke-tests interactions, and assesses against **our own design
  style guides preloaded into the agent** (the key insight): it judges palette/contrast/spacing/
  typography coherence against `docs/design/watchtower-redesign-2026-05-13/` + `foundations.css` +
  `settings.PRESETS`, not generic heuristics. This is what makes it *specialised* rather than a
  generic linter.
- **B dropped:** a `fw reviewer --ux` mode would entangle the static scanner with browser-driving;
  A+C keep prevention (a gate) and assessment (an agent) cleanly separated.

The taste call stays the human's `[REVIEW]` (T-1811) — C *informs* it (flags console errors, off-guide
contrast) but does not replace it.

**Evidence:**
- T-1988/T-1999: interactive surface shipped dead despite static reviewers; verification never executed page JS (RCA in T-1999, L-423)
- Existing substrate to build on: `fw reviewer` (T-1443), TermLink reviewer dispatch (T-1951), Playwright harness (`tests/playwright/conftest.py`), design system (`docs/design/watchtower-redesign-2026-05-13/`, `foundations.css`)
- Render-surface gate (T-1766) is the natural attach point for A

## Decisions

### 2026-05-23 — approach selection (human-directed)
- **Chose:** Build **A** (enforcement gate) **and C** (dedicated UX-review TermLink agent), with C **preloaded with our design style guides** so it assesses against our system.
- **Why:** A is the can't-skip structural floor that would have blocked T-1988; C adds specialised, guide-aware qualitative review that a generic linter can't. Preloading the style guides is what makes C worth building over plain "no console errors" checks.
- **Rejected:** B (`fw reviewer --ux` mode) — keeps the static scanner and browser-driving entangled; A+C separate prevention from assessment more cleanly.

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ccadae6d
- **Timestamp:** 2026-06-02T15:00:48Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
