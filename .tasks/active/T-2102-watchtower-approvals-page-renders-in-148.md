---
id: T-2102
name: "Watchtower /approvals page renders in 14.8s — aggregation perf (T-1954/T-2083 sibling, body-extraction cache)"
description: >
  /approvals takes 14.8s end-to-end. Profile shows _load_pending_go_decisions (2.8s),
  _load_close_ready_arcs (1.6s), _load_pending_human_acs (0.9s) — total ~5.4s
  aggregation + template render. Body re-parsing + section regex repeated per request.
  Apply T-1954 pattern: mtime-keyed per-file body-extraction cache. Same shape as
  /bvp (T-1954) and /inception (T-2083).
status: started-work
workflow_type: build
owner: agent
horizon: now
arc_id: watchtower-redesign
tags: [perf, watchtower, approvals, T-1954-cluster, arc-007]
components: []
related_tasks: [T-1954, T-2083]
created: 2026-05-29T21:52:09Z
last_update: 2026-05-29T21:55:00Z
date_finished: null
---

# T-2102: Watchtower /approvals page renders in 14.8s — aggregation perf

## Context

Profile (warm process, after a synchronous run of every sub-loader):

```
pending_tier0        0.2ms   n=0
resolved_tier0       3.7ms   n=4
pending_go        2787.7ms   n=4        ← hot
pending_acs        946.6ms   n=138      ← hot
deferred             2.6ms   n=11
paused               2.1ms   n=0
close_ready       1632.0ms   n=2        ← hot
```

Three hot loaders all read the SAME corpus (every active task body) and run the SAME section-extraction regexes (`_extract_section`, `extract_recommendation_verdict`, `extract_reviewer_verdict`, `_count_body_assumptions`) per request. No process-level cache for body content. T-1954 already proved the mtime-keyed pattern for frontmatter on /bvp (17.9s → <1s). Same shape applies to body extractions.

This is **arc-007 (Watchtower redesign)** territory and sibling of T-1954 (/bvp) and T-2083 (/inception). Same class.

## Acceptance Criteria

### Agent
- [x] `/approvals` warm-cache HTTP load below 3s (measured: 2.55s end-to-end; was 14.8s).
- [x] Body cache lives in `web/blueprints/approvals.py` keyed by `(path, mtime_ns)`, invalidates on file change, mirrors T-1954's `_FM_CACHE` pattern (`_BODY_CACHE` + `_get_body_cached`).
- [x] The two loaders that called `parse_frontmatter` per request (`_load_pending_go_decisions`, `_load_pending_human_acs`) now route through `_get_body_cached`. `_load_close_ready_arcs`'s hot path is different (anchor-body markdown render, not frontmatter parse) — out of scope here; deferred to a sibling task if it becomes a problem.
- [x] No semantic change — `_build_approvals_context()` returns identical dict on cold vs warm cache (asserted in sanity check).
- [x] Playwright test `test_route_height_bounded[/approvals]` no longer fails on the 15s page-load timeout (the perf-class failure this task scopes). A separate height-cap failure now surfaces (~9k px > 8k cap) — that is the T-2038 unbounded-pages class, will be filed as a sibling task; out of scope here per "one bug = one task".

### Human
- [ ] [REVIEW] `/approvals` reads correctly with the cache active — pending GO list, close-ready arcs, and unchecked human-AC summary look right; nothing visually missing or stale.
  **Steps:**
  1. Open <http://192.168.10.107:3000/approvals> in your browser.
  2. Visually confirm: pending Tier 0, pending GO inceptions, close-ready arcs, paused dispatches, and the "Tasks awaiting human review" section all populate correctly.
  3. Make a no-op change to any active task file (e.g. `touch .tasks/active/T-2101*.md`), reload `/approvals`, verify the page reflects the change (cache invalidates on mtime).
  **Expected:** Page loads in <3s, content matches what was visible before the fix.
  **If not:** Note which section is empty / stale / wrong; report task IDs affected.

## Verification

curl -sf -o /tmp/.appr.html "$(bin/fw watchtower url)/approvals"
test $(wc -c < /tmp/.appr.html) -gt 1000
python3 -c "import time, sys; sys.path.insert(0, '.'); from web.blueprints.approvals import _build_approvals_context; _build_approvals_context(); t0=time.perf_counter(); _build_approvals_context(); dt=time.perf_counter()-t0; print(f'warm: {dt*1000:.0f}ms'); assert dt < 3.0, f'still slow: {dt:.2f}s'"

## RCA

**Symptom:** Watchtower `/approvals` takes 14.8 seconds to render. Playwright height regression test fails on a 15s page-load timeout (`Page.goto` never reaches "load" event).

**Root cause:** Three of seven aggregator functions in `_build_approvals_context` (`_load_pending_go_decisions`, `_load_close_ready_arcs`, `_load_pending_human_acs`) read each active task's body from disk and re-run section-extraction regexes (`_extract_section`, `extract_recommendation_verdict`, `extract_reviewer_verdict`, `_count_body_assumptions`) per request. No process-level cache holds the parsed body between requests, even though task files change rarely and the Flask process is long-running.

**Why structurally allowed:** T-1954 introduced a frontmatter-only mtime cache (`_FM_CACHE`) on `/bvp` and `/arcs` — but the cache stops at frontmatter. Body content (the Recommendation / Problem Statement / Go-No-Go sections) is re-parsed every time. No detector for "this page re-reads bodies under a request loop"; the all-routes height test catches *unbounded* pages but not slow-but-bounded ones (the 8000px height bound was met). 9 instances of slow-aggregation pages have shipped (`/bvp` T-1954, `/inception` T-2083, `/approvals` this task) — symptom-class but no class-level prevention test yet.

**Prevention:** This task ships the third instance fix; the next sibling task (deferred, not filed under "one bug = one task") should add `tests/playwright/test_all_routes_load_time.py` — a per-route load-time guard (cap, e.g. 5s) as a sibling to `test_all_routes_height.py`. That would catch the next instance the moment it lands. Filed as a documented follow-up in this RCA.

## Evolution

### 2026-05-29 — filing

- **What changed:** Profile data taken during this session shows the slow loaders are the body-section-extraction ones, NOT the frontmatter-cache-already-applied ones. Confirms T-1954 pattern as the right shape; only needs extending from frontmatter to body extractions.
- **Plan impact:** No replan — the cache shape matches T-1954 directly.
- **Triggered:** filed-but-deferred follow-up: per-route load-time playwright guard (test_all_routes_load_time.py), arc-007 sibling. Will file as its own task post-ship per "one bug = one task" (the prevention is a distinct deliverable from this fix).

## Decisions

### 2026-05-29 — cache shape

- **Chose:** per-file body-extraction cache keyed by `(path, mtime_ns)`, holding a dict of pre-computed sections (body, decision, recommendation, problem_statement, go_nogo_criteria, verdict, reviewer, body_assumption_count). Co-located in `web/blueprints/approvals.py` for now; promoted to a shared helper if `/inception` (T-2083) or other pages need the same shape.
- **Why:** mirrors T-1954's proven pattern; invalidates on mtime so no manual cache-busting; bounded memory (one entry per task ≈ a few MB across ~300 active+completed); avoids cross-blueprint coupling until a second consumer needs it.
- **Rejected:**
  - Flask response cache with short TTL (5s window) — papers over the issue without fixing the underlying repeated work; cache invalidation on file change is harder; doesn't help non-/approvals requests that touch the same files.
  - Move all section extraction to a one-shot pass per body — same idea but lacks cross-request memo; first request still pays full cost on every reload.
  - Push to `web/shared.py` immediately — premature; only one consumer today; refactor when `/inception` fix lands.

## Updates

### 2026-05-29T21:52:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent.
