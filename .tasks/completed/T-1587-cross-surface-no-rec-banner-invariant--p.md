---
id: T-1587
name: "Cross-surface NO-REC banner invariant — pin recommendation-block[data-verdict=NO-REC] on /tasks and /review (T-1586 follow-up)"
description: >
  Extend T-1586's cross-surface parity test with NO-REC banner assertions. T-1576/T-1577/T-1578 shipped NO-REC distinction across queue+landing+review; this pins the per-task structural rendering on /tasks and /review for any task without a Recommendation block.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [test, invariant, regression, cross-surface, no-rec]
components: [tests/playwright/test_cross_surface_parity.py]
related_tasks: [T-1576, T-1577, T-1578, T-1586]
created: 2026-04-28T16:24:05Z
last_update: 2026-04-28T16:27:51Z
date_finished: 2026-04-28T16:27:51Z
---

# T-1587: Cross-surface NO-REC banner invariant — pin recommendation-block[data-verdict=NO-REC] on /tasks and /review (T-1586 follow-up)

## Context

T-1586 pinned cross-surface parity for the *positive* case: a task with `## Recommendation` AND `## Reviewer Verdict` blocks renders structured cards on every surface that consumes the body. The *negative* case (NO-REC — no Recommendation block) was shipped in T-1576/T-1577/T-1578 across queue + landing-page + /review pages, and parallel handling exists in `task_detail.html` via the `rec_state == 'NO-REC'` branch — but no Playwright invariant pins it. A future refactor that drops the `rec_state` plumbing on either /tasks or /review could silently regress the NO-REC banner with no test signal.

This task ships two assertions extending `tests/playwright/test_cross_surface_parity.py`: T-449 (a real NO-REC task) renders `<section class="recommendation-block" data-verdict="NO-REC"` on `/tasks/T-449` AND `/review/T-449`. Same drift class as T-1586, same shape, same lesson — fail-fast on parity regression.

## Acceptance Criteria

### Agent
- [x] `tests/playwright/test_cross_surface_parity.py` extended with `TestCrossSurfaceNoRecBanner` class containing two assertions
- [x] Test asserts T-449 (a build task with NO Recommendation block) renders `<section class="recommendation-block" data-verdict="NO-REC"` on `/tasks/T-449`
- [x] Test asserts T-449 renders the same NO-REC section on `/review/T-449`
- [x] Both assertions match against `<section class="recommendation-block"` (opening tag, not bare class) — same T-1583 lesson encoded
- [x] All tests in file still pass: `python3 -m pytest tests/playwright/test_cross_surface_parity.py -q --no-header 2>&1 | grep -qE '8 passed'`
- [x] No regression in `tests/unit/test_extract_recommendation.py` — `python3 -m pytest tests/unit/test_extract_recommendation.py -q --no-header 2>&1 | grep -q '24 passed'`

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

python3 -m pytest tests/playwright/test_cross_surface_parity.py -q --no-header 2>&1 | grep -qE '8 passed'
python3 -m pytest tests/unit/test_extract_recommendation.py -q --no-header 2>&1 | grep -q '24 passed'
# Comments below preserved for context.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

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

## Decisions

### 2026-04-28 — Prefix-match `<section class="recommendation-block` vs exact match
- **Chose:** Prefix match on `<section class="recommendation-block` (no closing quote in the constant)
- **Why:** The NO-REC banner uses the compound class `recommendation-block recommendation-norec`, so the exact-match constant `'<section class="recommendation-block"'` (with closing quote) doesn't fire on it. Prefix match catches both shapes (positive cards and NO-REC banners) without losing specificity — the prefix still excludes CSS rules in `<style>` blocks (which use bare `.recommendation-block`).
- **Rejected:** Adding `<section class="recommendation-block recommendation-norec"` as a second constant. Reason: doubles the maintenance surface (every future variant card needs a new constant) and hides the actual contract (the `<section>` must exist with that class as a token, regardless of compound modifiers).

## Recommendation

**Recommendation:** GO

**Rationale:** Extends T-1586's parity contract to the NO-REC negative state. Two new assertions pin the banner on `/tasks` and `/review` for tasks without a `## Recommendation` block — the next refactor that drops `rec_state` plumbing on either surface fails this test. Encodes the same T-1583 lesson on grep specificity (prefix match against opening tag).

**Evidence:**
- `tests/playwright/test_cross_surface_parity.py` extended: new `TestCrossSurfaceNoRecBanner` class with 2 tests (NO-REC on `/tasks/T-449` and `/review/T-449`), test fixture constant `TASK_WITH_NO_REC = "T-449"` added.
- All 8 tests pass on fresh test watchtower (T-1583 stale-template lesson applied — killed 3099 between runs): `python3 -m pytest tests/playwright/test_cross_surface_parity.py -q --no-header` → `8 passed in 18.23s`.
- No regression in shared parsing: `python3 -m pytest tests/unit/test_extract_recommendation.py -q --no-header` → `24 passed`.
- Prefix-match decision: NO-REC banner uses compound class `recommendation-block recommendation-norec`, so the constants in T-1586 needed widening from exact match (`<section class="recommendation-block"`) to prefix match (`<section class="recommendation-block`) — D-XXX captured.

## Updates

### 2026-04-28T16:24:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1587-cross-surface-no-rec-banner-invariant--p.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-97fd3683
- **Timestamp:** 2026-06-02T14:58:29Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `python3 -m pytest tests/playwright/test_cross_surface_parity.py -q --no-header 2>&1 | grep -qE '8 passed'`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `python3 -m pytest tests/unit/test_extract_recommendation.py -q --no-header 2>&1 | grep -q '24 passed'`
### 2026-04-28T16:27:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
