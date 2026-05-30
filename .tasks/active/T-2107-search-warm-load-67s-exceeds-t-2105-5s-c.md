---
id: T-2107
name: "/search warm-load 6.7s exceeds T-2105 5s cap — T-1954 cache pattern needed"
description: >
  Discovered by T-2105 all-routes load-time guard. /search warm-cache load measured
  at 6655ms — exceeds the 5000ms global cap. /search probably loads embeddings or
  full task corpus per request. Apply T-1954/T-2102 mtime-keyed cache pattern in web/blueprints/search.py.
  Currently held under 8000ms KNOWN_SLOW elevated cap in test_all_routes_load_time.py
  — fix closes that exemption.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [arc-007, perf, test-infra, T-1954-cluster, watchtower]
components: [web/blueprints/timeline.py, web/search_utils.py]
related_tasks: [T-2105, T-1954, T-2102, T-2106]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-29T23:00:06Z
last_update: 2026-05-30T06:52:38Z
date_finished: 2026-05-30T06:52:38Z
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
bvp_scores_proposed:
  - ts: '2026-05-29T23:15:02Z'
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
cost_estimate_proposed:
  - ts: '2026-05-29T23:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2107: /search warm-load 6.7s exceeds T-2105 5s cap — T-1954 cache pattern needed

## Context

Discovered by T-2105 all-routes load-time guard: /search warm-cache load = 6655ms (exceeds the 5000ms global cap; currently held under an 8000ms KNOWN_SLOW elevated cap with T-2107 as the tracking task). /search probably aggregates embeddings + full task corpus per request. Apply T-1954/T-2102/T-2106 mtime-keyed cache pattern in `web/blueprints/search.py` or related. After fix /search should be under the global 5000ms cap and the KNOWN_SLOW entry in `tests/playwright/test_all_routes_load_time.py` is removed.

## Acceptance Criteria

### Agent
- [x] Profile `/search` to identify the hot path (likely embedding load, full task corpus, or per-request file walks).
- [x] Apply the T-1954-pattern mtime-keyed cache to the hot path — pattern documented in T-1954 / T-2102 / T-2106 RCAs.
- [x] `/search` warm-cache HTTP load < 5000ms (verified by direct curl-timing on live Watchtower).
- [x] `KNOWN_SLOW` dict in `tests/playwright/test_all_routes_load_time.py` no longer contains `/search`; Playwright `test_route_load_time_bounded[/search]` PASSES at global 5000ms cap.
- [x] No semantic change — search results identical pre- and post-fix on a sample query.

### Human

- [ ] [REVIEW] `/search` empty-state tag cloud renders correctly post-cache-refactor
  **Steps:**
  1. Open http://192.168.10.107:3000/search (no query)
  2. Look at the tag cloud — should show ~24 tags, sized/weighted by count, top tags include common ones (arc:*, build, watchtower, governance, pickup)
  3. Touch an episodic file: `touch .context/episodic/T-2107.yaml` then reload — tag for arc-007 should still appear (cache invalidation by mtime works)
  **Expected:** Same visual shape and weighting as before refactor (semantic identity already verified by Agent AC #5; this is the eyes-on confirmation that nothing rendered weirdly).
  **If not:** Note which tag is missing/extra and reopen with details — likely a yaml-parse path divergence in `_episodic_tags_for()`.

<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

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

python3 -c "from web.search_utils import aggregate_tags; r1 = aggregate_tags(limit=24); r2 = aggregate_tags(limit=24); assert r1 == r2, 'aggregate_tags non-idempotent'; assert len(r1) == 24, f'expected 24 tags, got {len(r1)}'"
grep -q "_TAG_FM_CACHE" web/search_utils.py
grep -q "T-2107 (/search) CLOSED" tests/playwright/test_all_routes_load_time.py
out=$(grep -A2 "KNOWN_SLOW: dict" tests/playwright/test_all_routes_load_time.py); echo "$out" | grep -vq '"/search"'

## RCA

**Symptom:** T-2105 all-routes load-time guard measured `/search` warm-load at 6655ms — exceeds the 5000ms global cap. Held under elevated 8000ms `KNOWN_SLOW` cap with T-2107 as tracker.

**Root cause:** `web/search_utils.py:aggregate_tags()` walked all 1166 `.context/episodic/T-*.yaml` files on every cache miss. Guarded by a single 60s wrapper TTL (`_tag_cache`, T-1235) — so once per minute, the next /search hit paid the full 5-6s scan cost. The Playwright `prime + measure` pattern in T-2105's guard frequently straddled this TTL: prime warmed nothing useful (the cache had just expired and was rebuilt cold under prime); measure landed shortly after with a fresh cache, OR vice-versa during contention.

**Why structurally allowed:** The cache was correct as designed (T-1235 reduced load on every-request walks), but the TTL-only design meant rebuild cost was uncapped and growing with episodic corpus size (1166 files in 2026-05, was ~400 in 2025). The latency leg of prevention only landed in T-2105 — before that, the 5-6s post-TTL rebuild was invisible (only TermLink + curl users would notice; UI users on warm hits saw 20ms).

**Prevention:** Already wired by T-2105 (`tests/playwright/test_all_routes_load_time.py`). Removing `/search` from `KNOWN_SLOW` closes the elevated cap — the global 5000ms cap now enforces. Any future regression in `_TAG_FM_CACHE` invalidation logic (e.g. stale mtime, missing key) fails the test. Class-pattern matches T-1954 (`/bvp`), T-2102 (`/approvals`), T-2106 (`/timeline`): the same TTL-only design appeared in four different blueprints; OBS-039 captures the consolidation candidate.

## Evolution

### 2026-05-30 — TTL-only caches consistently mask O(N) rebuild cost

- **What changed:** Filing assumed embeddings init was the hot path. Reality: the empty-state tag cloud (`aggregate_tags(limit=24)`) walks all episodic files on every TTL-driven rebuild. The fix shape T-2106 used (per-file mtime cache surviving outer TTL) applied cleanly here — same shape, fourth blueprint in 30 days.
- **Plan impact:** None on scope — fix matches the T-1954/T-2102/T-2106 pattern as expected. Reinforces OBS-039 (promote helper to `web/shared.py`).
- **Triggered:** None new this slice. T-2108 (/) is the remaining `KNOWN_SLOW` entry; same pattern likely applies but cockpit aggregates more sources, may need 2-3 caches.

## Recommendation

**Recommendation:** GO

**Rationale:** /search post-TTL rebuild dropped 6473ms → 33ms (200× speedup) via the same per-file mtime cache pattern proven in T-1954 (/bvp), T-2102 (/approvals), and T-2106 (/timeline). Semantic identity verified — `aggregate_tags(limit=24)` returns bit-identical output pre- and post-refactor (24/24 tags, same order). Reviewer PASS, zero findings. Playwright `test_route_load_time_bounded[/search]` passes at the global 5000ms cap with /search removed from KNOWN_SLOW. Only the visual sanity check on the tag cloud remains.

**Evidence:**
- Cold load (one-time startup): 6700ms (acceptable — pays once)
- Warm (TTL valid): 17ms
- After 65s idle, TTL expired: **33ms** (this was the 6473ms regression)
- Playwright [/search] PASS at 5000ms cap
- Reviewer T-2107 PASS, no findings
- Semantic identity: 24/24 tags identical, same order
- Same shape: web/blueprints/bvp.py:_FM_CACHE (T-1954), approvals.py:_BODY_CACHE (T-2102), timeline.py:_FM_CACHE (T-2106)

**Review URL:** http://192.168.10.107:3000/review/T-2107

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

### 2026-05-29T23:00:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2107-search-warm-load-67s-exceeds-t-2105-5s-c.md
- **Context:** Initial task creation

### 2026-05-29T23:16:21Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-47e66e68
- **Timestamp:** 2026-05-30T06:52:47Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-30T06:52:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
