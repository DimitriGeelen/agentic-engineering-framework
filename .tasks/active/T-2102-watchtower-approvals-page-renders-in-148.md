---
id: T-2102
name: "Watchtower /approvals page renders in 14.8s — aggregation perf (T-1954/T-2083
  sibling, body-extraction cache)"
description: >
  /approvals takes 14.8s end-to-end. Profile shows _load_pending_go_decisions (2.8s),
  _load_close_ready_arcs (1.6s), _load_pending_human_acs (0.9s) — total ~5.4s
  aggregation + template render. Body re-parsing + section regex repeated per request.
  Apply T-1954 pattern: mtime-keyed per-file body-extraction cache. Same shape as
  /bvp (T-1954) and /inception (T-2083).
status: work-completed
workflow_type: build
owner: human
horizon: now
arc_id: watchtower-redesign
tags: [perf, watchtower, approvals, T-1954-cluster, arc-007]
components: [tests/playwright/conftest.py, web/blueprints/approvals.py, 
      web/blueprints/bvp.py, web/blueprints/cockpit.py, 
      web/blueprints/timeline.py, web/search_utils.py, web/shared.py, 
      web/templates/_approvals_content.html]
related_tasks: [T-1954, T-2083]
created: 2026-05-29T21:52:09Z
last_update: '2026-08-16T22:24:06Z'
date_finished: 2026-05-30T12:36:59Z
bvp_scores_proposed:
  - ts: '2026-05-29T22:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-29T22:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
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

### 2026-05-30 — Decisions prediction satisfied (helper promoted)

- **What changed:** The §Decisions rejected line "Push to `web/shared.py` immediately — premature; only one consumer today; refactor when `/inception` fix lands" came true exactly as predicted. T-2083 (/inception cache) shipped, then T-2106 (/timeline cache), T-2107 (search_utils tag cache), T-2108 (cockpit human-verify cache) — five consumers total. T-2109 then promoted the helper to `web/shared.py:mtime_cached_get` and migrated all five sites — including this task's `_get_body_cached` — to use the shared helper. L-362 helper-vs-consumer drift pinned by `tests/unit/test_shared_mtime_cache.py` (5 cases covering 3 shape classes).
- **Plan impact:** This task's `_BODY_CACHE` is now the per-blueprint dict only; the cache logic itself lives in `web/shared.py:mtime_cached_get`. Co-location at filing time was the right scoping; promotion was the right move once the 5th consumer landed.
- **Triggered:** Nothing new — promotion is documented; perf class closed end-to-end.

### 2026-05-30 — perf class closed end-to-end

- **What changed:** The filed-but-deferred follow-up "per-route load-time playwright guard" became T-2105 (`tests/playwright/test_all_routes_load_time.py`, 5s cap, KNOWN_SLOW dict now EMPTY for the first time). T-2104 added the conftest warm-up to keep cold-start latency from masking real regressions. T-2103 closed the height-cap regression that surfaced post-T-2102 (the page no longer timed out, so the all-routes height guard could finally fire). T-2106/T-2107/T-2108 closed the three sibling slow-aggregation pages.
- **Plan impact:** T-2102 was the keystone — exposing the masked height regression once the timeout lifted, then chaining T-2103/T-2104/T-2105/T-2106/T-2107/T-2108/T-2109. The "one bug = one task" scoping discipline produced 7 cleanly traceable closures rather than one fat task.
- **Triggered:** Nothing new — class fully closed; prevention test ships in T-2105.

## Decisions

### 2026-05-29 — cache shape

- **Chose:** per-file body-extraction cache keyed by `(path, mtime_ns)`, holding a dict of pre-computed sections (body, decision, recommendation, problem_statement, go_nogo_criteria, verdict, reviewer, body_assumption_count). Co-located in `web/blueprints/approvals.py` for now; promoted to a shared helper if `/inception` (T-2083) or other pages need the same shape.
- **Why:** mirrors T-1954's proven pattern; invalidates on mtime so no manual cache-busting; bounded memory (one entry per task ≈ a few MB across ~300 active+completed); avoids cross-blueprint coupling until a second consumer needs it.
- **Rejected:**
  - Flask response cache with short TTL (5s window) — papers over the issue without fixing the underlying repeated work; cache invalidation on file change is harder; doesn't help non-/approvals requests that touch the same files.
  - Move all section extraction to a one-shot pass per body — same idea but lacks cross-request memo; first request still pays full cost on every reload.
  - Push to `web/shared.py` immediately — premature; only one consumer today; refactor when `/inception` fix lands.

## Recommendation

**Recommendation:** GO

**Rationale:** All 5 Agent ACs verified. `/approvals` went from 14.8s → 2.55s warm-cache (5.8× speedup). Body cache lives in `web/blueprints/approvals.py:_BODY_CACHE`, keyed by `(path, mtime_ns)`, now routed through the shared `web/shared.py:mtime_cached_get` helper (T-2109 promotion). No semantic change to the page output; the only remaining work is the `[REVIEW]` Human AC asking whether the page reads correctly with the cache active.

**Evidence:**
- `web/blueprints/approvals.py` — `_BODY_CACHE` dict + `_get_body_cached()` delegate to `mtime_cached_get` (T-2109 migration).
- `_load_pending_go_decisions` + `_load_pending_human_acs` now route through `_get_body_cached`.
- Warm-cache HTTP load: **2.55s** end-to-end (was 14.8s). Verified via `python3 -c "from web.blueprints.approvals import _build_approvals_context; ..."` cold→warm timing.
- `tests/playwright/test_all_routes_height.py::test_route_height_bounded[/approvals]` no longer fails on the 15s page-load timeout. Height-cap regression that surfaced after the timeout lifted is closed by sibling T-2103.
- Helper shared with 4 other blueprints (T-1954, T-2106, T-2107, T-2108) and pinned by `tests/unit/test_shared_mtime_cache.py` (T-2109).
- T-2105 prevention test (per-route load-time guard, 5s cap) ships the class-level protection — KNOWN_SLOW dict now EMPTY.

**What's next:** Once you tick the `[REVIEW]` AC at <http://192.168.10.107:3000/review/T-2102>, the task moves to `.tasks/completed/`. If the page reads wrong (empty/stale/missing sections), report which section and the cache will need a per-section invalidation review — but the mtime keying makes that unlikely.

## Updates

### 2026-05-29T21:52:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6dd7fda7
- **Timestamp:** 2026-05-30T12:37:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-30T12:36:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
