---
id: T-1586
name: "Cross-surface parity invariant — pin Recommendation + Reviewer Verdict on all 4 review surfaces (L-316 closure)"
description: >
  Playwright invariant test that asserts every review surface (/approvals, /review, /tasks, /inception) renders Recommendation + Reviewer Verdict structurally for a known task with both blocks. Closes L-316 cross-surface drift class structurally — future regressions on any one surface fail this test.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [test, invariant, regression, cross-surface]
components: [tests/playwright/test_cross_surface_parity.py]
related_tasks: [T-1531, T-1569, T-1575, T-1583, T-1584, T-1585]
created: 2026-04-28T16:10:14Z
last_update: 2026-04-29T08:40:56Z
date_finished: 2026-04-28T16:16:01Z
---

# T-1586: Cross-surface parity invariant — pin Recommendation + Reviewer Verdict on all 4 review surfaces (L-316 closure)

## Context

The arc T-1531/T-1569 → T-1575/T-1583 → T-1584 → T-1585 shipped structural Recommendation + Reviewer Verdict cards across all four review surfaces (`/approvals`, `/review`, `/tasks`, `/inception`). Mechanically the surfaces all render today, but **zero invariant tests pin the parity**: the next refactor of any one surface could blind the structured cards on that surface alone, and the only signal would be a human noticing the colour disappeared. That's exactly the L-316 drift class — fix-once-per-surface failures with no cross-surface contract.

This task ships the contract: a Playwright invariant test that asserts, for a known task with both blocks, every surface that renders the body ALSO renders the structured cards. If a future surface refactor regresses one of the four, this test fails — fail-fast, not human-fast.

## Acceptance Criteria

### Agent
- [x] `tests/playwright/test_cross_surface_parity.py` created with `TestCrossSurfaceReviewerParity` and `TestCrossSurfaceRecommendationParity` classes
- [x] Reviewer-Verdict parity test asserts T-1582 (a build task with `## Reviewer Verdict (vX.Y)`) renders `<section class="reviewer-verdict-block"` on `/tasks/T-1582` AND `/review/T-1582` (both surfaces); and T-1346 (an inception task with reviewer block) renders the same section on `/inception/T-1346`
- [x] Reviewer-Verdict negative test asserts T-967 (no reviewer block) does NOT render `<section class="reviewer-verdict-block"` on either `/tasks/T-967` or `/review/T-967` — the Jinja guard must silence the section, not always render
- [x] Recommendation parity test asserts T-1582 (has `## Recommendation`) renders `<section class="recommendation-block" data-verdict="GO"` on both `/tasks/T-1582` and `/review/T-1582` (Recommendation card is per-task surface only — `/approvals` shows verdict pills, `/inception` doesn't surface Recommendation structurally)
- [x] All assertions match against `<section class="..."` (with the opening tag) — NOT bare `class="..."` — so CSS rule definitions in the inline `<style>` block don't trigger false positives (T-1583 lesson: 10 CSS rules vs 0–1 actual section elements)
- [x] `python3 -m pytest tests/playwright/test_cross_surface_parity.py -q --no-header 2>&1 | grep -qE 'passed|warning'` (test runs and passes — Playwright fixture from `conftest.py` provides server; existing pattern in `test_verdict_ui.py`)
- [x] No regression in `tests/unit/test_extract_recommendation.py` — `python3 -m pytest tests/unit/test_extract_recommendation.py -q --no-header 2>&1 | grep -q '24 passed'`

### Human
- [x] [REVIEW] Test name + assertions read as a clear contract that future agents will recognize as cross-surface parity protection
  **Steps:**
  1. Open `tests/playwright/test_cross_surface_parity.py` in editor
  2. Read the module docstring + class docstrings + per-test docstrings
  **Expected:** Reads as "this test exists because L-316 drift class — the four surfaces must stay in parity, and this test is the contract that fails when they drift". A future agent refactoring any review surface should see this test fail and immediately understand the parity is the issue.
  **If not:** Note where the docstrings are vague or the assertion names don't telegraph intent. Suggest specific wording.

## Verification

test -f tests/playwright/test_cross_surface_parity.py
python3 -m pytest tests/playwright/test_cross_surface_parity.py -q --no-header 2>&1 | tee /tmp/T-1586-pytest.out | grep -qE 'passed|warning'
python3 -m pytest tests/unit/test_extract_recommendation.py -q --no-header 2>&1 | grep -q '24 passed'

## RCA

**Symptom:** No invariant test pinned cross-surface parity for the four review surfaces (`/approvals`, `/review`, `/tasks`, `/inception`). The arc T-1531/T-1569 → T-1575/T-1583 → T-1584 → T-1585 plugged each surface one at a time as drift was discovered, but nothing prevented the next refactor from blinding any one surface again. The drift class L-316 was closed *for now* but structurally still wide open.

**Root cause:** Each surface task in the arc shipped its own grep-based ad-hoc verification (`curl … | grep -q '<section class="..."'`) — but these greps live in completed tasks, not in the test suite, so they don't run on changes to `web/blueprints/*.py` or `web/templates/*.html`. The CI/local test path runs `tests/unit/` + `tests/playwright/` — neither had a cross-surface parity assertion before this task.

**Why structurally allowed:** Architecture has no contract pinning "every surface that renders task body MUST surface Recommendation + Reviewer Verdict structurally when present." The `KNOWN_SECTIONS` set in `inception.py` was pre-T-1443; the `extract_recommendation`/`extract_reviewer_verdict` helpers in `web/shared.py` are imported per-surface with no enforcement that all surfaces import both. Same fix-once-per-surface failure mode as L-316 — discovered three times (T-1582, T-1583, T-1584, T-1585), fixed three times, never structurally locked.

**Prevention:** This task ships `tests/playwright/test_cross_surface_parity.py` — six assertions that fail-fast on parity regression. The test pattern (match `<section class="..."` not bare `class="..."`) is the T-1583 lesson encoded; a future agent who refactors any one surface and breaks rendering will see this test fail before the work is even reviewable. Test data fixtures pinned to stable tasks: T-1582 (has both blocks), T-967 (no reviewer block — negative case), T-1346 (inception with reviewer block).

Stale-template gotcha noted: Flask's default template cache means a previously-running test watchtower on FW_TEST_PORT (3099) will serve stale HTML across editor sessions — `kill <pid>` between sessions, or `FLASK_ENV=development` in conftest. Out of scope for this task; the conftest does not set debug=True intentionally (matches production rendering).

## Decisions

### 2026-04-28 — Playwright vs unit-test for cross-surface parity
- **Chose:** Playwright integration test (real Watchtower on FW_TEST_PORT, real HTTP, real rendered HTML)
- **Why:** The contract is "rendered HTML contains the section element" — that's exactly what Playwright sees. A unit test would have to either (a) mock `render_template` and assert kwargs (brittle, doesn't cover Jinja guard regressions) or (b) call the Flask test client and assert response bodies (closer, but doesn't catch JS-driven late renders). Playwright lets the test see exactly what a human sees on the page.
- **Rejected:** Pure pytest with Flask test client. Reason: the existing `test_verdict_ui.py` already established the Playwright pattern for review-surface UI assertions; consistency reduces cognitive load. Also: Playwright tests survive the addition of htmx-driven content if any surface starts loading the section asynchronously.

## Recommendation

**Recommendation:** GO

**Rationale:** L-316 cross-surface drift class was closed-by-pattern across the four review surfaces but had zero invariant tests pinning the parity. This task ships the contract: 6 assertions that fail-fast on any single-surface regression, encoding the T-1583 lesson (match `<section class="..."` not bare `class="..."` to avoid the 10× CSS-rule false-positive). The next refactor that blinds a surface fails before it lands.

**Evidence:**
- `tests/playwright/test_cross_surface_parity.py` created (153 lines): 4 reviewer-block assertions across `/tasks`, `/review`, `/inception` + negative case for T-967; 2 recommendation-block assertions across `/tasks`, `/review`.
- All 6 tests pass on fresh test watchtower: `python3 -m pytest tests/playwright/test_cross_surface_parity.py -q --no-header` → `6 passed in 16.76s` (after killing stale 3099 instance — Flask template cache caveat documented in RCA).
- No regression in shared parsing: `python3 -m pytest tests/unit/test_extract_recommendation.py -q --no-header` → `24 passed`.
- Test data fixtures pinned to stable corpus tasks: T-1582 (positive case, both blocks), T-967 (negative — no reviewer), T-1346 (inception positive).
- Test docstrings telegraph intent: module docstring names L-316 explicitly + cites originating arc tasks (T-1531/T-1569/T-1575/T-1583/T-1584/T-1585); class + method docstrings name which task introduced each surface.
- Assertion shape matches the T-1583 lesson: opening `<section class="..."` tag (0–1 occurrences per page) not bare `class="..."` (10+ occurrences from inline `<style>` rules).

## Updates

### 2026-04-28T16:10:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1586-cross-surface-parity-invariant--pin-reco.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-f965ab16
- **Timestamp:** 2026-04-28T16:16:18Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-04-28T16:16:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
