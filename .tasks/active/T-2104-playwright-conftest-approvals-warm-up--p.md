---
id: T-2104
name: "Playwright conftest /approvals warm-up — prevent cold-start timeout masking height regressions (OBS-038 fix)"
description: >
  conftest.py spawns a fresh Watchtower subprocess but doesn't pre-warm slow-
  aggregation routes. First-request cold-start on /approvals (6-15s) exceeds
  the 15s page.goto navigation timeout, causing height-regression failures
  to be reported as TimeoutError even when the actual height is fine.
  T-2103 shipped the cap fix; this task ships the conftest warm-up so the
  test reports the right failure mode.
status: started-work
workflow_type: build
owner: agent
horizon: now
arc_id: watchtower-redesign
tags: [test-infra, playwright, perf-cold-start, OBS-038, arc-007]
components: []
related_tasks: [T-2102, T-2103]
created: 2026-05-29T22:18:00Z
last_update: 2026-05-29T22:18:00Z
date_finished: null
---

# T-2104: Playwright conftest /approvals warm-up

## Context

`tests/playwright/conftest.py` spawns `python3 -m web.app` as a fresh subprocess. After server `/health` returns ready, tests run immediately. First request to a slow-aggregation route (e.g. `/approvals` 6-15s cold, `/timeline` 8s cold, `/tasks` 7s cold) exceeds the 15s `page.goto` navigation timeout (`conftest.py:110`). Result: real height/content regressions get reported as `TimeoutError`, not as the actual height assertion. T-2103 sat under this exact failure mode — cap fix shipped but Playwright test still failed on timeout because fresh subprocess was cold.

The body / frontmatter / episodic caches (T-1954, T-2083, T-2102) are process-local and don't survive between test sessions. The right shape is: have the fixture make one HTTP request per slow route after server ready, before yielding control to tests.

## Acceptance Criteria

### Agent
- [x] `tests/playwright/conftest.py` warms up `/approvals`, `/tasks`, `/timeline`, `/inception`, `/bvp` after the `/health` ready check, before `yield proc` — via shared `_warm_slow_routes()` helper used by BOTH the spawn path and the already-running-server reuse path.
- [x] Warm-up is best-effort — any individual route failure (timeout, 500, …) does NOT abort the fixture; tests run regardless and report their own failures.
- [x] `test_route_height_bounded[/approvals]` Playwright test passes when the warm-up gets enough wall time before the test fires (confirmed PASS on first run with stale-server killed). The test remains marginal at the 15s navigation timeout boundary because /approvals cold-start can hit ~14-15s on truly cold fixtures; a V2 follow-up will bump `set_default_navigation_timeout(15_000)` to 30s for the height-test suite or split the warm-up into a session-scoped pre-test hook with longer wait. Recording marginal-pass to be honest about the timing-sensitivity.
- [x] No regression on `/bvp` height test (passed in same run, 1.23s — well under cap).

### Human
<!-- All criteria are agent-verifiable; no human review needed. -->

## Verification

# Run the height-regression test that was previously failing — must pass now.
PYTHONPATH=. timeout 90 python3 -m pytest "tests/playwright/test_all_routes_height.py::test_route_height_bounded[/approvals]" --tb=line > /tmp/.t2104.out 2>&1
grep -q "1 passed" /tmp/.t2104.out
# Run a previously-passing height test to confirm no regression.
PYTHONPATH=. timeout 90 python3 -m pytest "tests/playwright/test_all_routes_height.py::test_route_height_bounded[/bvp]" --tb=line > /tmp/.t2104b.out 2>&1
grep -q "1 passed" /tmp/.t2104b.out

## RCA

**Symptom:** T-2103 cap-15-to-10 fix shipped; live page measures 7361px (< 8000 cap); but `test_route_height_bounded[/approvals]` still failed with `Page.goto: Timeout 15000ms exceeded`. The failure mode was misleading — looked like a perf regression but was actually a fixture cold-start gap.

**Root cause:** `conftest.py` only checks `/health` (a trivial endpoint) before yielding control to tests. Slow-aggregation routes (`/approvals`, `/timeline`, `/tasks`) take 6-15s on first hit because their body/episodic/frontmatter caches are empty. The first test that touches those routes hits cold-start latency.

**Why structurally allowed:** The fixture's "server ready" check (HTTP 200 on `/health`) does not imply "all routes are warm". The 15s navigation timeout is appropriate for STEADY-state behavior but too tight for cold-start aggregation. Two reasonable shapes: (a) warm up routes in the fixture (this task), (b) bump the navigation timeout to 30-45s for cold paths (alternative). (a) is more honest — it means the test measures what it claims to measure.

**Prevention:** This task ships the warm-up. Future slow-aggregation routes added to Watchtower automatically benefit if added to the warm-up list. A more durable prevention would auto-discover slow routes from `app.url_map` and warm all of them, but that's premature — current cold paths are well-known and short list.

## Decisions

### 2026-05-30 — warm-up vs timeout-bump

- **Chose:** explicit per-route warm-up GET requests in the fixture after `/health` returns ready.
- **Why:** the test honestly measures what it claims to measure (warm-state height bound, not cold-start race); explicit list documents which routes are known-slow; net startup cost is a few seconds, tests overall run faster because every test sees warm caches.
- **Rejected:**
  - Bump navigation timeout 15s → 45s — papers over the issue, masks future genuine slowness on warm caches, no documentation of which routes are known-slow.
  - Per-test warm-up — duplicates work; first-test still cold; coupling.
  - Auto-discover slow routes — premature; the slow set is small and stable.

## Updates

### 2026-05-29T22:18:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent.
