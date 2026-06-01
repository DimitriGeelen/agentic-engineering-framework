---
id: T-2105
name: "per-route load-time playwright guard — catch next T-1954/T-2102/T-2083-class
  perf regression"
description: >
  T-2102 RCA flagged this as the deferred class-level prevention: a per-route
  Playwright load-time guard that fails fw test playwright the moment a new
  Watchtower page enters the 5s+ class. Mirrors test_all_routes_height.py
  shape — same exhaustive route discovery (T-2042 discover_get_routes), same
  parametrize-over-every-route mechanism. Closes the leg of the prevention
  ladder where T-1954, T-2102, and T-2083 each shipped silently for days
  before someone noticed the page felt slow.
status: work-completed
workflow_type: build
owner: agent
horizon: null
arc_id: watchtower-redesign
tags: [arc-007, perf, test-infra, T-1954-cluster, watchtower]
components: []
related_tasks: [T-1954, T-2102, T-2083, T-2104, T-2048, T-2106, T-2107, T-2108]
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-29T22:45:05Z
last_update: 2026-05-29T23:06:23Z
date_finished: 2026-05-29T23:06:23Z
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
  - ts: '2026-05-29T23:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-29T23:00:03Z'
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
---

# T-2105: per-route load-time playwright guard — catch next T-1954/T-2102/T-2083-class perf regression

## Context

T-2102's RCA flagged the gap directly:

> 9 instances of slow-aggregation pages have shipped (`/bvp` T-1954, `/inception` T-2083, `/approvals` this task) — symptom-class but no class-level prevention test yet. The next sibling task should add `tests/playwright/test_all_routes_load_time.py` — a per-route load-time guard (cap, e.g. 5s) as a sibling to `test_all_routes_height.py`. That would catch the next instance the moment it lands.

T-2104 added conftest warm-up for the known slow set (/approvals, /inception, /tasks, /timeline, /bvp). With warm caches, every Watchtower route should render in under a generous cap; any route that doesn't is either a new T-1954-class regression (cache missing) or a genuinely too-heavy aggregator (needs splitting). Either way the guard should fail loudly.

This is the second leg of the prevention ladder. `test_all_routes_height.py` (T-2048) catches unbounded scrollHeight; this catches unbounded load time. Together they protect the visual and the latency budget.

## Acceptance Criteria

### Agent
- [x] `tests/playwright/test_all_routes_load_time.py` exists and mirrors `test_all_routes_height.py` shape — exhaustive route discovery via `_load_uxr().discover_get_routes()`, parametrize over every route (47 routes discovered, asserted >5 by `test_routes_discovered_exhaustively`).
- [x] Test uses **prime + measure** pattern (first goto warms blueprint caches, second goto is timed); asserts measured wall-clock under `LOAD_CAP_MS = 5000` (5s — matches T-2102 RCA's suggested cap). Prime+measure avoids cache-TTL-expiry noise during the 4-minute parametric run (47 routes × ~3s each ≫ 30s `_TASK_CACHE_TTL`).
- [x] Test passes on every currently-discovered route on a warm server: 49 passed / 0 failed in 267s. Three pre-existing slow routes (`/timeline` 8.3s, `/search` 6.7s, `/` 5.1s) are gated through `KNOWN_SLOW` with elevated caps + tracking tasks (T-2106/T-2107/T-2108 filed). Fixing each closes its KNOWN_SLOW exemption — the dict is a TODO list, not a forever-list.
- [x] A guardrail test (`test_load_cap_is_documented`) asserts `LOAD_CAP_MS` provenance comment (T-2102 RCA reference) is present in source so future bumps stay auditable.
- [x] No regression on the existing height guard (`test_all_routes_height.py::test_routes_discovered_exhaustively` still passes).

### Human
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

# Structural smoke — the test file is wired correctly. (Full parametric run takes
# ~270s; recorded in task body Evolution. Verification just confirms the mechanism.)
test -f tests/playwright/test_all_routes_load_time.py
PYTHONPATH=. timeout 30 python3 -m pytest "tests/playwright/test_all_routes_load_time.py::test_routes_discovered_exhaustively" "tests/playwright/test_all_routes_load_time.py::test_load_cap_is_documented" --tb=line > /tmp/.t2105.out 2>&1
out=$(cat /tmp/.t2105.out); echo "$out" | grep -q "2 passed"
# Provenance: LOAD_CAP_MS comment cites T-2102.
grep -q "T-2102" tests/playwright/test_all_routes_load_time.py
# Sibling height guard still green (no regression).
PYTHONPATH=. timeout 60 python3 -m pytest "tests/playwright/test_all_routes_height.py::test_routes_discovered_exhaustively" --tb=line > /tmp/.t2105b.out 2>&1
out=$(cat /tmp/.t2105b.out); echo "$out" | grep -q "1 passed"

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

## Evolution

### 2026-05-30 — KNOWN_SLOW emerged from baseline

- **What changed:** First parametric run with cap=5000ms (no priming) found 3 routes (`/`, `/search`, `/timeline`) over the cap. Not a regression — these had always been slow; the guard simply had never measured. The initial AC said "add slow routes to warm-up list" but the real issue surfaced in re-run: even with conftest warm-up active, the suite walks 47 routes × ~2-3s = ~150s, during which the 30s `_TASK_CACHE_TTL` expires multiple times — by the time we hit `/timeline` (last alphabetically) the warm-up was 4 TTL-cycles stale.
- **Plan impact:** Switched from "warm-up list" to **prime + measure per route** (first goto warms, second goto measured). Measures honest warm-cache UX, independent of suite walk order. Plus a `KNOWN_SLOW: {route → (cap, task_id)}` dict that elevates per-route caps with a tracking task — turns "list of slow routes" into "list of follow-ups", because each entry has a task whose closure removes the entry.
- **Triggered:** T-2106 (`/timeline` 8.3s), T-2107 (`/search` 6.7s), T-2108 (`/` 5.1s) filed as deferred follow-ups. Each carries the same T-1954-pattern fix shape.

## Decisions

### 2026-05-30 — prime + measure over conftest warm-up extension

- **Chose:** per-test prime hit before measurement, no expansion to conftest `_warm_slow_routes()`.
- **Why:** conftest warm-up runs once at suite start; with 30s `_TASK_CACHE_TTL` and a 4-minute suite, every route past the first ~10 measures a cold cache. Prime+measure isolates the steady-state UX metric per-route, making the test independent of suite walk order and TTL.
- **Rejected:**
  - Bump `_TASK_CACHE_TTL` to 300s — fixes the symptom by hiding the staleness; users still pay cold-start every 5 minutes. Cleaner to fix per-page via T-1954-pattern mtime caches (per-file invalidation, no fixed TTL).
  - Run pytest with `-x` after first failure — debugging-friendly but masks the systemic class. Better to see all routes' measurements in one pass.
  - Pin the cap at 8000ms (generous enough to cover current slow set) — would let `/metrics` (4-5s warm cold-start prone) silently grow. Tight 5000ms cap with KNOWN_SLOW exemptions surfaces growth at the right time.

### 2026-05-30 — KNOWN_SLOW dict over xfail markers

- **Chose:** `KNOWN_SLOW: dict[str, tuple[int, str]]` — per-route elevated cap + tracking task ID.
- **Why:** xfail would let the route silently regress further (xfail expects failure; doesn't measure degree). Elevated-cap-with-task makes the exemption load-bearing: each KNOWN_SLOW entry is a TODO with an owner, and the test still enforces "don't get worse than today's measured baseline + headroom". Fixing the underlying perf issue (per the linked task) lets you DELETE the entry, dropping back to the strict 5000ms cap.
- **Rejected:**
  - `pytest.xfail`/`pytest.skip` — exemption-only; doesn't enforce a ratchet.
  - Hard-code one global "lenient" cap — defeats the per-route signal.

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

### 2026-05-29T22:45:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2105-per-route-load-time-playwright-guard--ca.md
- **Context:** Initial task creation

### 2026-05-29T22:45:36Z — status-update [task-update-agent]
- **Change:** tags: +T-1954-cluster

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0deb1b96
- **Timestamp:** 2026-05-29T23:06:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-29T23:06:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
