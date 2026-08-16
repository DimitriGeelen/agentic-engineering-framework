---
id: T-2035
name: "Cockpit 22s load — per-file memoize JSONL session parsing"
description: >
  Cockpit 22s load — per-file memoize JSONL session parsing

status: work-completed
workflow_type: build
owner: agent
horizon:
arc_id: watchtower-redesign
tags: [arc:watchtower-redesign, perf, watchtower, cockpit]
components: []
related_tasks: [T-1954, T-1235, T-803, T-2020]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-25T07:58:20Z
last_update: '2026-08-16T22:24:51Z'
date_finished: 2026-05-25T08:04:33Z
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
  - ts: '2026-05-25T08:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-25T08:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:51Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2035: Cockpit 22s load — per-file memoize JSONL session parsing

## Context

The cockpit landing page (`/`) takes **22s** to load on the live server; `/tasks` 8.5s.
Profiling the `index()` helpers (web/blueprints/core.py) found the dominant cost is
`_get_token_usage()` → `_load_all_sessions()` (web/blueprints/costs.py) at **9.8s**.
The T-1235 cache (120s TTL) is keyed on *file count*, so every TTL expiry re-parses
**all** session JSONL transcripts (655MB current + 560MB + 132MB + … ≈ 1.5GB) just to
pick up the one growing current-session file. Historical files never change yet are
re-read every time. Sibling perf precedent: T-1954 (BVP /bvp 17.9s → cache).

Fix: memoize `_parse_session` per file keyed on (mtime, size). Unchanged historical
files parse once per process. The growing current-session file is parsed
**incrementally** — seek to the last consumed offset, parse only appended complete
lines, merge the (additive) stats. This unblocks the arc-007 ux-review `--sweep`
tooling too (its Playwright 15s `goto` timeout was tripping on the 22s `/`).

## Acceptance Criteria

### Agent
- [x] `_parse_session` memoized per-file by (st_mtime, st_size); an unchanged file returns cached stats without re-reading (unit test) — `test_unchanged_file_returns_same_object`
- [x] Growing current-session file parsed incrementally — seek to last offset, parse only appended complete lines, merge additive stats; incremental result == from-scratch full parse (unit test asserts equality) — `test_incremental_growth_equals_full` + real-corpus totals identical (44482406724)
- [x] Truncation/rotation safe — if the file shrinks below the cached size, full re-parse (unit test) — `test_truncation_triggers_full_reparse`
- [x] Token numbers unchanged — project token totals match a cold full parse: 44482406724 == 44482406724 (cold vs post-expiry)
- [x] Steady-state (post-warmup) cockpit `/` load drops below 6s (was 22s) — measured 1.6s; post-TTL-expiry path 10.62s → 0.001s (7913×)
- [x] No regression — `/` and `/costs` return HTTP 200; `tests/unit/lib_costs.bats` (26 ok) and `tests/unit/test_bvp_blueprint_cost.py` (20 passed) pass

### Human
<!-- No Human ACs. Caching-only change to a data helper (_parse_session): byte-identical
     render output, so no visual delta for a human to review. The render-surface gate
     (P-013) fires on the web/blueprints/ path; bypassed at close with --skip-render-review
     (logged Tier-2), rationale: "caching-only; no template/render-output change; widget
     correctness covered by the incremental==full Agent AC". Number correctness is
     Agent-verifiable, not taste. -->

## Verification

python3 -c "import sys; sys.path.insert(0,'.'); from web.blueprints.costs import _parse_session_cached, _parse_session; print('memo helper present')"
python3 -m pytest tests/unit/test_costs_incremental_parse.py -q
if command -v bats >/dev/null; then bats tests/unit/lib_costs.bats; else echo "bats not installed - skipped"; fi
python3 -m pytest tests/unit/test_bvp_blueprint_cost.py -q
curl -sf -o /dev/null -w "costs http=%{http_code}\n" http://localhost:3000/costs
curl -sf -o /dev/null -w "index http=%{http_code}\n" http://localhost:3000/

## RCA

**Symptom:** Watchtower cockpit landing page (`/`) takes 22s to load; `/tasks` 8.5s.
Playwright-based tooling (`fw ux-review --sweep`) fails with a 15s `goto` timeout on `/`.

**Root cause:** `_get_token_usage()` (cockpit widget, T-803) calls `_load_all_sessions()`
which parses every session JSONL transcript (≈1.5GB across 71 files). The T-1235 cache
is keyed on *file count* with a 120s TTL — so each expiry re-parses **all** files,
including ~850MB of historical transcripts that never change, just to refresh the one
growing current-session file. On a low-traffic dev server, loads land >120s apart, so
nearly every load pays the full ≈9.8s parse.

**Why structurally allowed:** The T-1235 cache invalidation proxy (file *count*) diverged
from the real invariant (per-file *content*). Count is stable while the current file grows,
so the cache is simultaneously too coarse (re-parses unchanged files on expiry) and the
TTL too short to mask it. No perf budget/test guards page load time — the same blind spot
T-1954 hit on `/bvp` (17.9s) independently.

**Prevention:** Per-file memo keyed on (mtime, size) makes the cache key track the real
invariant; the incremental==full unit test pins correctness so future edits can't silently
break token totals. (A page-load-time perf budget across blueprints would generalise the
guard — noted as a candidate follow-up, not in scope here: one task = one deliverable.)

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

### 2026-05-25 — discovered via the arc-007 review pass, not redesign scope
- **What changed:** This started as a critical eyes-on review of shipped arc-007
  surfaces. The very first step (a `--sweep` capture) failed on Playwright's 15s
  `goto` timeout — surfacing that the cockpit takes 22s. The slowness is *pre-existing*
  (token widget T-803 + cache T-1235), not an arc-007 regression, but it both degrades
  the redesigned cockpit and blocks the arc's own review tooling.
- **Plan impact:** The review pass is blocked until `/` is fast enough for Playwright;
  this perf fix becomes the prerequisite for resuming the sweep-based review.
- **Triggered:** This task (T-2035). Also noted in passing: a malformed-YAML-frontmatter
  parse error on T-1934 (logged on every `get_all_task_metadata`) — separate one-bug-one-task,
  to be filed after this lands.

### 2026-05-25 — incremental beats plain memo because the current file is 655MB
- **What changed:** Plain (mtime,size) memo frees the ~850MB of historical files but
  still re-parses the 655MB *growing* current session on every TTL expiry (~4s alone).
  Because every stat is an additive sum, seek-to-offset incremental parsing is exact,
  so it's worth the small extra code to also memoize the current file's parsed prefix.
- **Plan impact:** AC set extended from "per-file memo" to include incremental append
  parsing + a truncation/rotation guard + an incremental==full equality test.
- **Triggered:** unit test `tests/unit/test_costs_incremental_parse.py`.

## Recommendation

**Recommendation:** GO

**Rationale:** The cockpit landing page is ~14× faster (22.4s → 1.6s) and the recurring
re-parse on every 120s cache expiry is gone (10.62s → 0.001s, 7913×). Token totals are
byte-identical before/after (44482406724), pinned by an `incremental == full` unit test
plus truncation/rotation and partial-line guards. No render output changed — this is a
data-helper caching fix — so there is no visual delta to review (render-surface gate
bypassed at close via `--skip-render-review`, logged). Reviewer PASS, needs_human=no.

**Evidence:**
- `web/blueprints/costs.py`: `_parse_session_cached` (per-file memo on mtime+size) + `_accumulate` (seek-to-offset incremental fold); `_load_all_sessions` now calls it.
- Live timing: `/` 22.4s → 1.6s; `/costs` 0.03s. Post-expiry path 10.62s → 0.001s with warm memo, totals identical.
- `tests/unit/test_costs_incremental_parse.py` — 5 passed (memo identity, incremental==full, truncation, partial-line).
- Regression: `lib_costs.bats` 26 ok; `test_bvp_blueprint_cost.py` 20 passed; `/` + `/costs` HTTP 200.
- Reviewer R-5b2b6c00 PASS, no findings.

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

### 2026-05-25T07:58:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2035-cockpit-22s-load--per-file-memoize-jsonl.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8248987f
- **Timestamp:** 2026-06-02T15:00:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-25T08:04:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
