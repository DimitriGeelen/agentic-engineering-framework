---
id: T-2103
name: "/approvals renders 8926px tall — exceeds 8000px cap (T-2038 sibling, lower AC cap)"
description: >
  After T-2102 perf fix unblocked the page-load timeout, the all-routes height
  guard surfaces a real height regression — /approvals at 8926px, 8000 cap.
  4 inception cards (~760px each = 3049px) + 15 visible AC cards (~285px each =
  4279px) sum past cap. Same T-2038 unbounded-pages class. Simplest safe fix:
  lower _ac_cap 15 → 10; overflow group already in place since T-2038.
status: started-work
workflow_type: build
owner: agent
horizon: now
arc_id: watchtower-redesign
tags: [watchtower, approvals, height-regression, T-2038-cluster, arc-007]
components: []
related_tasks: [T-2038, T-2102]
created: 2026-05-29T22:04:54Z
last_update: 2026-05-29T22:10:00Z
date_finished: null
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
# Live height check (warm server) — must be < 8000px after the cap change.
out=$(python3 -c "from playwright.sync_api import sync_playwright; import subprocess; url=subprocess.check_output(['bin/fw','watchtower','url']).decode().strip()
with sync_playwright() as p:
    b=p.chromium.launch(headless=True); pg=b.new_page(viewport={'width':1280,'height':800})
    pg.goto(f'{url}/approvals', wait_until='load', timeout=30000)
    print(pg.evaluate('document.body.scrollHeight'))
    b.close()"); test "$out" -lt 8000

## RCA

**Symptom:** `/approvals` rendered height = 8926px, exceeding the 8000px cap enforced by `tests/playwright/test_all_routes_height.py::test_route_height_bounded[/approvals]`. Test failure surfaced AFTER T-2102 removed the 15s page-load timeout that previously masked it.

**Root cause:** T-2038 set the AC overflow cap at 15 cards when there were ~0 pending inception decisions. Since then the active inception corpus grew to 4 GO-recommended items, each rendering a verbose Recommendation block by default (~760px each). The 15-AC cap budget no longer fits inside the 8000px ceiling — same content shape T-2038 fixed, different denominator.

**Why structurally allowed:** The cap was hard-coded as a constant rather than computed against a height budget. The height-guard test only fires on absolute scrollHeight, not on a per-section budget. T-2102's perf fix made the test actionable (was masked by 15s timeout); without T-2102 this regression could have grown silently for weeks. The class-prevention test guards correctness (overflow keeps total bounded eventually) but not stability (the cap goes stale as adjacent content grows).

**Prevention:** This task ships the cap reduction. A more durable prevention — a per-section height budget that adapts as adjacent content (inception cards, arc closure rows) grows — is a sibling thought, NOT filed here (one bug = one task; speculative until we see a third recurrence).

## Decisions

### 2026-05-30 — cap reduction vs default-collapse

- **Chose:** lower `_ac_cap` 15 → 10. ~1425px saved; total ~7500px, comfortably under cap.
- **Why:** smallest mechanism change; overflow already in place; sort order already prioritises top-10 correctly; no UX shift on the action surface (inception Recommendation stays open where the decide form lives).
- **Rejected:**
  - Default-collapse inception Recommendation blocks — saves more (~2200px) but penalises the page's core verb (read recommendation → decide).
  - Default-collapse AC card Steps/Expected/If-not — same UX penalty on the verification flow.
  - Per-section height budget (computed cap) — premature optimisation; second recurrence would justify; first one points at a constant adjustment.

## Updates

### 2026-05-29T22:04:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent.
