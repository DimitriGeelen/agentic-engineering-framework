---
id: T-2135
name: "Playwright regression net for htmx targetError class — /review/<id> interactive
  widgets"
description: >
  Playwright regression net for htmx targetError class — /review/<id> interactive
  widgets

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [arc-007, regression-net, htmx, playwright, prevention, T-2134-followup]
components: [tests/playwright/test_review_htmx_target_inheritance.py]
related_tasks: [T-2112, T-2113, T-2114, T-2134]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-31T08:13:58Z
last_update: '2026-06-11T22:24:08Z'
date_finished: 2026-05-31T08:26:39Z
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
  - ts: '2026-05-31T08:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-31T08:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:08Z'
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

# T-2135: Playwright regression net for htmx targetError class — /review/<id> interactive widgets

## Context

The /review/<id> standalone template (T-667 — own `<html>` root, no base.html extends) has been the site of four htmx-target-inheritance regressions in the last fortnight:

- **T-2112** /approvals "Review" click → bounce-back (wrapper inherited target → polling div)
- **T-2113** cockpit Recent Activity task links → same bounce-back class
- **T-2114** review.html Reload-page link + markdown URLs → same class (sibling fix: wrapper-reset div)
- **T-2134** review.html ac-check form → htmx:targetError ABORTED the POST before configRequest, so CSRF never ran and the checkbox click silently no-opped (L-450 captured)

The class shape: a wrapper sets `hx-target="#X"` (often `#content` for the boost-link bounce-back fix); a descendant form/anchor with `hx-post`/`hx-get`/etc. inherits the target; if `#X` doesn't exist in the rendered DOM (standalone template — no base.html → no `#content`), htmx fires `htmx:targetError` and aborts the request before any user-visible feedback or CSRF wiring.

L-450 captured the principle. No structural test guards it. A fifth incident is one wrapper-edit away.

This task ships the regression net: a Playwright test that parses /review/<id> rendered HTML and asserts every interactive descendant (hx-post / hx-get / hx-put / hx-delete) either declares its own `hx-target` OR inherits a `hx-target` whose value resolves to an existing element ID in the same DOM. Same regression-net pattern as T-2042 + T-2048 (unbounded-page-height detector → all-routes Playwright test).

## Acceptance Criteria

### Agent
- [x] `tests/playwright/test_review_htmx_target_inheritance.py` exists and contains a structural-DOM test that walks /review/<id> and asserts every interactive element has a resolvable hx-target (own attribute OR inherited from an ancestor whose target resolves to a DOM-present id).
- [x] The test docstring names T-2112 / T-2113 / T-2114 / T-2134 as origin incidents and L-450 as the captured learning.
- [x] Test passes against the current /review/<id> rendering (T-2134 fix is in place — `ac-check` form has explicit `hx-target="this"`).
- [x] Test fails predictably if a regression is introduced — verified by temporarily removing the `hx-target="this"` line in `web/templates/_review_acs.html`, running the test (expect FAIL), then restoring (revert proves both directions).
- [x] Test is registered in `fw test playwright` collection (lives in `tests/playwright/`, picked up by the existing pytest config).

<!-- No Human ACs — this is a structural test pin (no UI surface touched, no
     subjective judgment required). The test itself replaces the human-eyes
     check that would otherwise be needed every time the wrapper-reset pattern
     is added/removed. Same shape as T-2120 (htmx-toast extraction pin) — pure
     contract enforcement, agent-verifiable end-to-end. -->

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

# T-2135 verification commands:
test -f tests/playwright/test_review_htmx_target_inheritance.py
python3 -m pytest tests/playwright/test_review_htmx_target_inheritance.py -q
out=$(grep -E "T-(2112|2113|2114|2134|L-450)" tests/playwright/test_review_htmx_target_inheritance.py); echo "$out" | grep -q "T-2134" && echo "$out" | grep -q "T-2114"

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

**Symptom:** Four htmx-target-inheritance regressions in the last fortnight (T-2112 /approvals, T-2113 cockpit, T-2114 review.html anchors, T-2134 ac-check form). The most recent (T-2134) caused the /review checkbox to silently no-op — user reported "i tick the box nothing happens !!! regression sht ??".

**Root cause (this task is regression-net, not bug-fix):** The class root cause is documented in `docs/reports/T-2133-review-checkbox-htmx-target-error-rca.md` — a wrapper sets `hx-target="#X"`; descendants without their own override inherit it; if `#X` is absent from the rendered DOM (standalone template, no base.html), htmx fires `htmx:targetError` and aborts the request pre-configRequest, so CSRF / before-request / response-handling never run. This task does NOT fix that class — T-2114 + T-2134 already did. It pins the contract so the *next* removal of an override or addition of a new wrapper-reset is caught by `fw test playwright` instead of by a human user.

**Why structurally allowed:** Until this test landed, the contract was a comment in a template (`_review_acs.html:35-44`) plus a memory entry (L-450) — no machine enforcement. A template edit that drops `hx-target="this"` (e.g. during a refactor that collapses the form attributes) passed every existing test: HTML still rendered, route still returned 200, polling still worked, the only visible failure was a missed POST in a real browser. That failure mode was invisible to curl, grep, and the existing test suite — by design, because htmx aborts client-side before any server-side signal exists.

**Prevention (what this task ships):** `tests/playwright/test_review_htmx_target_inheritance.py` — two assertions, both fail in `fw test playwright` the moment the override is dropped or a sibling form is added without its own `hx-target`. Verified by pass → mutate → fail → restore → pass cycle. Future similar regressions on other surfaces (e.g. `/inception/<id>`, `/arcs/<slug>/close`) need their own sibling pins; the assertion logic in the test is generic enough to copy.

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

### 2026-05-31 — filing scope captured

- **What changed:** Pre-build hypothesis is "static-DOM analysis of /review/<id> + ID-resolution check" is sufficient. Open question for build: does the test need to load /review for EVERY task in active/ + completed/, or is a representative single fetch enough? Single-fetch is faster but misses tasks whose ACs contain unusual markdown-rendered URLs that re-introduce the hx-target inheritance. Will decide during build based on per-task render variance.
- **Plan impact:** None pre-build; the test file shape and the test harness are independent of this choice.
- **Triggered:** None yet.

### 2026-05-31 — single-fetch is sufficient (single-test pass)

- **What changed:** Single-fetch (`/review/T-2134`) catches both the realistic-regression mode (line removed → form inherits `#content` → DOM-id resolution fails) AND the explicit-pin mode (a second narrowly-scoped test asserts `form.ac-check[hx-target=this]`). The fan-out-over-all-tasks expansion was speculative — the failure mode lives in the template, not in any per-task rendering, so one render exercises it.
- **Plan impact:** Test stays narrow: two assertions, one fixture task. No per-task fanout, no Playwright browser interaction (static DOM via bs4 + urllib is enough — page fixture is included only to share the conftest-managed Watchtower server startup).
- **Triggered:** Two-test shape (general DOM resolution + explicit ac-check pin) instead of one — the general test alone missed the v1-failure mode where someone replaces the override with garbage (e.g. `hx-target="this-removed"`), so a narrowly-named pin tightens the contract. Both fire in the realistic regression where the line is removed entirely.

### 2026-05-31 — bs4 selected over Playwright DOM API

- **What changed:** Originally scoped as a Playwright test (clicking, listening for `htmx:targetError` console events). Build revealed the contract is purely structural — properties of the rendered HTML, not properties of JS execution — so bs4 + urllib runs ~50× faster (0.05s vs ~2s for a real browser interaction) and is more deterministic (no race against htmx initialization).
- **Plan impact:** No browser-side interaction; test fixture is `page` (for server startup) but `_fetch_review_html` uses urllib directly. Documented in the docstring so future maintainers don't add `page.click()` etc. and re-introduce flake.
- **Triggered:** Nothing new — pure scope cut.

## Recommendation

**Recommendation:** GO

**Rationale:** Pure regression-net — no source under test changes shape; the test pins a contract that already holds (the T-2134 fix is in place). Both assertions PASS against the current rendering and FAIL predictably when the regression is reintroduced (verified by pass → mutate → fail → restore → pass cycle on `web/templates/_review_acs.html`). Same shape as T-2042+T-2048 (unbounded-page-height net) and T-2120 (htmx-toast extraction pin) — structural enforcement of an L-captured class.

**Evidence:**
- Test file: `tests/playwright/test_review_htmx_target_inheritance.py` (192 lines).
- Two tests:
  - `test_review_no_unresolvable_hx_target` — walks every htmx-interactive element on /review/T-2134, resolves the effective hx-target (own or ancestor), fails if an `#X` selector inherits an id absent from the DOM.
  - `test_ac_check_form_has_explicit_hx_target_this` — narrowly named pin for the T-2134 fix; asserts `form.ac-check[hx-target=this]` directly so a maintainer reading the test sees exactly the contract that protects against L-450.
- Pass: `pytest -q` → `2 passed in 42.55s`.
- Regression-net proof: removed `hx-target="this"` from `_review_acs.html:47` → both tests FAILED with the exact L-450 explanation in the assert message. Restored → both pass.
- Tagged `arc-007` + `arc_id: watchtower-redesign`; related_tasks names the four origin incidents.
- No render-surface edits in final diff (web/templates/_review_acs.html restored byte-identical to start).

**What's next:** The next htmx-target-inheritance regression in /review will fail `fw test playwright` before it ships. If a 5th surface-class incident emerges (e.g. `/arcs/<slug>/close` or `/inception/<id>`), file a sibling pin against that surface — the assertion logic is generic over `(URL, expected interactive selectors)`.

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

## Updates

### 2026-05-31T08:13:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2135-playwright-regression-net-for-htmx-targe.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8fa29aff
- **Timestamp:** 2026-06-02T15:01:17Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#4 (Agent)** — Test fails predictably if a regression is introduced — verified by temporarily removing the `hx-target="this"` line in `web/templates/_review_acs.html`, running the test (expect FAIL), then restoring 
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/_review_acs.html in: Test fails predictably if a regression is introduced — verified by temporarily removing the `hx-target="this"` line in `web/templates/_review_acs.html`
### 2026-05-31T08:26:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
