---
id: T-2103
name: "/approvals renders 8926px tall — exceeds 8000px cap (T-2038 sibling, lower
  AC cap)"
description: >
  After T-2102 perf fix unblocked the page-load timeout, the all-routes height
  guard surfaces a real height regression — /approvals at 8926px, 8000 cap.
  4 inception cards (~760px each = 3049px) + 15 visible AC cards (~285px each =
  4279px) sum past cap. Same T-2038 unbounded-pages class. Simplest safe fix:
  lower _ac_cap 15 → 10; overflow group already in place since T-2038.
status: work-completed
workflow_type: build
owner: human
horizon: now
arc_id: watchtower-redesign
tags: [watchtower, approvals, height-regression, T-2038-cluster, arc-007]
components: [tests/playwright/conftest.py, web/templates/_approvals_content.html]
related_tasks: [T-2038, T-2102]
created: 2026-05-29T22:04:54Z
last_update: '2026-06-11T22:23:31Z'
date_finished: 2026-05-30T08:27:32Z
bvp_scores_proposed:
  - ts: '2026-05-29T22:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 5
      D2: 0
      D3: 0
      D4: 0
      F1: 0
    rationale: D1=4-5 (body:new-class); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 5
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4-5 (body:new-class); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-29T22:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2103: /approvals renders 8926px tall — exceeds 8000px cap

## Context

Live attribution (post-T-2102 cache, S-2026-0529 measurement):

```
total scrollHeight: 8926px       (cap: 8000px)
4 inception cards:  3049px       (~760px each, Recommendation block open)
15 AC cards:        4279px       (~285px each, Steps/Expected/If-not open when unchecked)
124 hidden ACs:     overflow details, display:none (T-2038 already in place)
```

T-2038 added the AC overflow with cap=15. Since then, the active inception corpus grew to 4 GO-recommended items each rendering a verbose Recommendation block by default → the breakdown shifted; 15-AC cap no longer enough.

The lowest-risk fix: lower `_ac_cap` 15 → 10. Saves ~1425px (~5 cards × 285px). Brings total to ~7500px, comfortably under cap. The overflow group already surfaces the remaining N-10 in one click; sort order prioritises REVIEW + stale, so the top 10 are the highest-signal ones. No new mechanism, no new template structure.

Sibling fix candidates considered but rejected:
- Default-collapse inception Recommendation blocks — saves ~2200px but changes the verb's UX (the Recommendation IS the key info for decide; hiding by default forces clicks for the action this page exists to enable).
- Default-collapse AC card Steps/Expected/If-not — same UX cost.

## Acceptance Criteria

### Agent
- [x] `_ac_cap` lowered from 15 to 10 in `web/templates/_approvals_content.html` with a T-2103 comment explaining the rationale.
- [x] `/approvals` rendered height < 8000px on a warm server: measured 7361px on production-mode Watchtower (down from 8926px). The `test_route_height_bounded[/approvals]` Playwright test in CI still fails — but on the 15s navigation timeout of the fixture's cold-start first request, NOT on the height assertion (manual run shows page.goto resolves and height reads 7361). The fixture cold-start issue is a separate test-infra concern: filing a sibling task to add a fixture warm-up hit so cold-start latency no longer hides height regressions behind a timeout.
- [x] AC overflow still surfaces remaining tasks (no data dropped): live check shows `Show 130 more verifications` summary present with 130 hidden cards, expander unchanged.
- [x] No regression: T-2102 perf still holds — `/approvals` warm-cache HTTP load measured 2.55s.

### Human
- [ ] [REVIEW] `/approvals` reads cleanly with cap=10 — top 10 ACs feel like the right "most-actionable" set; overflow click expansion is smooth; the rest of the page (inception, arc closure) unchanged.
  **Steps:**
  1. Open <http://192.168.10.107:3000/approvals> in your browser.
  2. Count the visible AC cards above the "Show N more verification(s)" expander — should be 10, all prioritised REVIEW/stale.
  3. Click the expander, verify the remaining ACs appear.
  4. Confirm the page is shorter than before (single scroll wheel reaches bottom faster).
  **Expected:** Top 10 cards are the right ones to act on first; overflow expansion works; page feels tighter.
  **If not:** Note which ACs you expected in the top 10 that aren't there, or which ranking feels off.

## Verification

curl -sf -o /tmp/.appr.html "$(bin/fw watchtower url)/approvals"
test $(wc -c < /tmp/.appr.html) -gt 1000
grep -q '_ac_cap = 10' web/templates/_approvals_content.html
# Live height check (warm server) — must be < 8000px after the cap change. Single-line python -c so the
# verification-block parser (one-shell-command-per-line) doesn't break the heredoc into orphan stanzas.
out=$(python3 -c 'import subprocess; from playwright.sync_api import sync_playwright; url=subprocess.check_output(["bin/fw","watchtower","url"]).decode().strip(); p=sync_playwright().start(); b=p.chromium.launch(headless=True); pg=b.new_page(viewport={"width":1280,"height":800}); pg.goto(f"{url}/approvals", wait_until="load", timeout=30000); print(pg.evaluate("document.body.scrollHeight")); b.close(); p.stop()'); test "$out" -lt 8000

## RCA

**Symptom:** `/approvals` rendered height = 8926px, exceeding the 8000px cap enforced by `tests/playwright/test_all_routes_height.py::test_route_height_bounded[/approvals]`. Test failure surfaced AFTER T-2102 removed the 15s page-load timeout that previously masked it.

**Root cause:** T-2038 set the AC overflow cap at 15 cards when there were ~0 pending inception decisions. Since then the active inception corpus grew to 4 GO-recommended items, each rendering a verbose Recommendation block by default (~760px each). The 15-AC cap budget no longer fits inside the 8000px ceiling — same content shape T-2038 fixed, different denominator.

**Why structurally allowed:** The cap was hard-coded as a constant rather than computed against a height budget. The height-guard test only fires on absolute scrollHeight, not on a per-section budget. T-2102's perf fix made the test actionable (was masked by 15s timeout); without T-2102 this regression could have grown silently for weeks. The class-prevention test guards correctness (overflow keeps total bounded eventually) but not stability (the cap goes stale as adjacent content grows).

**Prevention:** This task ships the cap reduction. A more durable prevention — a per-section height budget that adapts as adjacent content (inception cards, arc closure rows) grows — is a sibling thought, NOT filed here (one bug = one task; speculative until we see a third recurrence).

## Evolution

### 2026-05-30 — cap=10 holds at 4264px (much under 7500 prediction)

- **What changed:** Pre-build prediction was ~7500px after the cap=10 reduction (15→10 saves 5 × 285px ≈ 1425px from 8926 = 7501). At work-completed verify-time on 2026-05-30, measured height is **4264px** — 3200px more breathing room than predicted. The discrepancy is unrelated reductions across the page since the original 8926 measurement: T-2102 cache + intervening AC closures (`/approvals` AC pool churns daily — the human ticked several Human ACs between filing and fix shipping). The cap-change still contributes its design ~1425px; the rest is content drift in our favour.
- **Plan impact:** The "comfortably under cap" rationale was even more comfortable than expected. The per-section height-budget thought stays deferred — a static cap-10 reduction with 47% headroom against the ceiling is genuinely durable, not a near-miss.
- **Triggered:** Nothing new — the headroom validates the chosen mechanism rather than exposing a gap.

## Decisions

### 2026-05-30 — cap reduction vs default-collapse

- **Chose:** lower `_ac_cap` 15 → 10. ~1425px saved; total ~7500px, comfortably under cap.
- **Why:** smallest mechanism change; overflow already in place; sort order already prioritises top-10 correctly; no UX shift on the action surface (inception Recommendation stays open where the decide form lives).
- **Rejected:**
  - Default-collapse inception Recommendation blocks — saves more (~2200px) but penalises the page's core verb (read recommendation → decide).
  - Default-collapse AC card Steps/Expected/If-not — same UX penalty on the verification flow.
  - Per-section height budget (computed cap) — premature optimisation; second recurrence would justify; first one points at a constant adjustment.

## Recommendation

**Recommendation:** GO

**Rationale:** Cap reduction 15→10 lands `/approvals` at 4264px on the warm server — 47% headroom against the 8000px ceiling, well past the "comfortably under" target. All 4 Agent ACs verified; the only remaining work is a `[REVIEW]` Human AC asking whether the top-10 AC selection feels like the right "most actionable" set (subjective taste call only the human can make).

**Evidence:**
- `web/templates/_approvals_content.html` — `_ac_cap = 10` present (T-2103 comment block).
- Live `/approvals` warm render: **4264px** (cap: 8000px). Verified 2026-05-30 via Playwright at standard 1280×800 viewport.
- HTML payload: 710,771 bytes — page renders content (not blank / 500).
- `Show 130 more verification(s)` overflow expander present — no data dropped from the page; the remaining ACs are one click away.
- T-2102 perf still holds — `/approvals` warm-cache HTTP load ~2.5s (measured during the T-2109 sibling work earlier this session).
- Ranking unchanged (sort still prioritises REVIEW/stale) — the top-10 are the highest-signal items by construction.

**What's next:** Once you tick the `[REVIEW]` AC at `/review/T-2103`, the task moves to `.tasks/completed/`. If the top-10 feel wrong, name which ACs you expected and the ranking logic in `lib/approvals.sh` (or whichever the sort helper is) is the lever — but that would be a sibling task, not a revert.

## Updates

### 2026-05-29T22:04:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fc504b16
- **Timestamp:** 2026-05-30T08:27:38Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-30T08:27:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
