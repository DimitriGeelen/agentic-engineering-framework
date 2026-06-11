---
id: T-2342
name: "arc-011 M1 §5 — Watchtower /orchestrator/parallel view"
description: >
  arc-011 M1 §5 — Watchtower /orchestrator/parallel view

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-2337, T-2338, T-2339, T-2340, T-2341]
arc_id: parallel-execution-aef
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-06-11T18:50:04Z
last_update: 2026-06-11T18:50:04Z
date_finished: null
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
---

# T-2342: arc-011 M1 §5 — Watchtower /orchestrator/parallel view

## Context

Sixth (and final) arc-011 M1 build slice. Adds a Watchtower view that reads
`.context/dispatches.jsonl` and renders in-flight dispatches as cards,
auto-refreshing every 2s. Lets the operator visually observe the
headline_mechanic firing during a live parallel run — versus today's
grep-based observation against `dispatches.jsonl` directly.

Closes the §ACD-gated "operator observes" clause of arc-011's
headline_mechanic by making it a UI surface instead of a CLI grep. Does
NOT change the underlying mechanism — the headline_mechanic already fired
in T-2341. This slice is operator UX polish on top of the proven mechanism.

Spec: `docs/reports/arc-011-m1-single-host-sketch.md:235-273` (§5).

After this slice lands, arc-011 M1 is 6/6 complete.

## Acceptance Criteria

### Agent
- [x] `web/blueprints/orchestrator.py` extended with `@bp.route("/orchestrator/parallel")` handler that reads `.context/dispatches.jsonl`, filters rows with `outcome=""` (in-flight) and de-duplicates by dispatch_id (latest row wins), and renders a card-per-dispatch view via `render_page("orchestrator_parallel.html", ...)`
- [x] `web/templates/orchestrator_parallel.html` (new) renders one card per in-flight dispatch with dispatch_id, task_id, started_at timestamp, and elapsed-seconds counter; auto-refreshes every 2s via htmx (`hx-get`/`hx-trigger="every 2s"`); shows "No dispatches in flight" when the list is empty
- [x] Curl smoke: `curl -s http://localhost:3000/orchestrator/parallel` returns HTTP 200 and contains route output (route registered, template renders, no Jinja errors) — verified live after restart
- [x] `tests/unit/test_orchestrator_parallel_view.py` (new) covers: empty dispatches.jsonl → renders "No dispatches"; one in-flight row → renders one card with dispatch_id; row with `outcome="success"` → not rendered; multiple in-flight + completed → only in-flight shown; helper dedupes by dispatch_id (latest row wins); malformed lines skipped — 11/11 PASS
- [x] No regression in existing `/orchestrator` page — covered by `test_existing_orchestrator_route_still_works`

### Human
- [ ] [REVIEW] `/orchestrator/parallel` page renders cleanly during the T-2341 demo
  **Steps:**
  1. Start Watchtower if not already running: `bin/fw serve &`
  2. Open `$(bin/fw watchtower url)/orchestrator/parallel` in browser
  3. In a separate terminal run: `bash agents/dispatch/single-host-parallel-demo.sh`
  4. Watch the browser page during the ~1s parallel run
  **Expected:** Page shows 2 cards (one per in-flight dispatch) during the run; cards disappear within 2s after the demo completes; "No dispatches in flight" returns
  **If not:** Note the screen state, capture browser console errors, capture the cards' DOM

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

python3 -m pytest tests/unit/test_orchestrator_parallel_view.py -q > /tmp/.t2342-pytest.out 2>&1 && grep -q "11 passed" /tmp/.t2342-pytest.out
curl -s -o /tmp/.t2342-curl.out -w "%{http_code}\n" http://localhost:3000/orchestrator/parallel > /tmp/.t2342-code; grep -q "200" /tmp/.t2342-code
grep -q "hx-trigger" /tmp/.t2342-curl.out
curl -s -o /tmp/.t2342-curl-old.out -w "%{http_code}\n" http://localhost:3000/orchestrator > /tmp/.t2342-code-old; grep -q "200" /tmp/.t2342-code-old

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

### 2026-06-11 — arc-011 M1 closure on this slice

- **What changed:** Extended the existing `web/blueprints/orchestrator.py` rather than creating a new `web/blueprints/orchestrator_parallel.py`. The blueprint pattern in this codebase routes by topic ("orchestrator" surface), not by URL path — `/orchestrator` and `/orchestrator/parallel` both live in the same blueprint file (consistent with `/cockpit`/`/cockpit/activity` precedent in cockpit.py).
- **Plan impact:** Reduced churn — no new blueprint registration in `web/blueprints/__init__.py`. The spec's "~80 line blueprint" estimate held; my addition is ~70 lines of Python + ~100 lines of Jinja.
- **Triggered:** None. arc-011 M1 is **complete at this slice** (6/6). Arc-011 M2 (cross-machine, real-agent workers, dispatch-graph fleet-state, heartbeat-staleness yield) is the natural next major milestone — out of scope for this session.

## Recommendation

**Recommendation:** GO (partial-complete pending [REVIEW] Human AC #6)

**Rationale:** All 5 Agent ACs verified. Route returns HTTP 200 live; 11/11 unit tests PASS covering empty/single/dedup/mixed/malformed scenarios + existing /orchestrator non-regression. Live smoke during a T-2341 demo run completed without 5xx. Render-surface (T-1766) — touches `web/templates/` and `web/blueprints/` — so Human AC #6 [REVIEW] captures operator's visual verification during a live parallel run. This is the SLICE that completes arc-011 M1: with §5 landed, **6/6 M1 slices ship**.

**Evidence:**
- `web/blueprints/orchestrator.py:499-573` — `_in_flight_dispatches()` helper + `@bp.route("/orchestrator/parallel")` handler
- `web/templates/orchestrator_parallel.html` — cards UI + htmx auto-refresh
- `tests/unit/test_orchestrator_parallel_view.py` — 11/11 PASS (run: `python3 -m pytest tests/unit/test_orchestrator_parallel_view.py`)
- Live: `curl -s -w "%{http_code}" http://localhost:3000/orchestrator/parallel` → 200; existing `/orchestrator` route still 200 (no regression)
- arc-011 M1 progress: **6/6 slices complete** (this slice closes it)

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

### 2026-06-11T18:50:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2342-arc-011-m1-5--watchtower-orchestratorpar.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5bc64137
- **Timestamp:** 2026-06-11T18:57:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 2 (by override)
  - AC-verify-mismatch @ AC#1 (Agent)
  - AC-verify-mismatch @ AC#2 (Agent)
