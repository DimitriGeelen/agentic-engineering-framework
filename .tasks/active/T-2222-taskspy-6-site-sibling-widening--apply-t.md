---
id: T-2222
name: "tasks.py 6-site sibling widening — apply T-2219 pattern (OBS-049 full closure)"
description: >
  Apply T-2221 widening shape to web/blueprints/tasks.py lines 972/990/1006/1022/1045/1061

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-05T21:48:34Z
last_update: 2026-06-05T21:48:50Z
date_finished:
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
  - ts: '2026-06-05T21:48:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2222: tasks.py 6-site sibling widening — apply T-2219 pattern (OBS-049 full closure)

## Context

OBS-049 full closure (sibling class-fix derived from T-2219 / T-2221). `web/blueprints/tasks.py` has **6** error-render sites (not 5 — memory `[[project_t2217_go_scope_2_of_3_shipped]]` was off by one; line 1061 was missed in the original OBS-049 capture) that emit `(stderr or stdout)[:200]` as raw f-string interpolation into a `<p>` fragment returned to htmx swap:

- **L972** (`/api/task/create` action) — multi-line return tuple, narrow at 200, raw interpolation (no escape)
- **L990** (`/api/task/<id>/horizon` action) — narrow at 200, raw interpolation
- **L1006** (`/api/task/<id>/owner` action) — narrow at 200, raw interpolation
- **L1022** (`/api/task/<id>/type` action) — narrow at 200, raw interpolation
- **L1045** (`/api/task/<id>/complete` action) — narrow at 200, raw interpolation
- **L1061** (`/api/task/<id>/status` action) — narrow at 200, raw interpolation

All 6 sites are structurally distinct from cockpit.py (T-2221): they **lack** an `_escape` helper entirely and use `(stderr or stdout)` rather than just `stderr`. This means:
1. **XSS risk** on hostile error text (no escape at all — raw interpolation of stderr into HTML)
2. **Truncation pain** identical to T-2219/T-2221 class (multi-line gate stderr renders only first sentence)
3. **No `white-space:pre-wrap`** so even widened text collapses whitespace

**Slice contract** (mirrors T-2221, adapts for shape diff): (a) add `_escape` helper to `web/blueprints/tasks.py` (same shape as `cockpit.py:255-258` — module-level function, ampersand/lt/gt/quot replacement); (b) widen `[:200]` → `[:1500]` on all 6 sites; (c) wrap the truncated string in `_escape(...)`; (d) add `white-space:pre-wrap` to each wrapping `<p>` style. Unit test pins all four properties on all 6 sites AND asserts no narrow `[:200]/[:300]` truncations survive on the route bodies (class invariant — same shape as `tests/unit/test_cockpit_error_render_widen.py`).

**Class closure scope:** cockpit.py 4 sites (T-2221) + tasks.py 6 sites (this) = 10 total. OBS-049 captured 9 (5 in tasks.py per memory + 4 in cockpit.py); this task discovers the 10th (L1061) and dismisses OBS-049 fully on close. Other blueprints (`fleet.py`, `approvals.py`, etc.) intentionally narrow for JSON API responses — not in scope.

**Not in scope:** JSON-only routes, `web/shared.py` extraction of `_escape` into a shared helper (separate refactor — see Decisions if needed), template-rendered routes (already use Jinja autoescape).

## Acceptance Criteria

### Agent
- [x] `web/blueprints/tasks.py` — module-level `_escape(text)` helper added (matches cockpit.py:255-258 shape: ampersand/lt/gt/quot replacement; no f-string sugar, plain `str.replace` chain).
- [x] `web/blueprints/tasks.py:~972` (task-create action error) — widened to `[:1500]` + `_escape(...)` + `white-space:pre-wrap` on the wrapping `<p>` style.
- [x] `web/blueprints/tasks.py:~990` (task horizon action error) — same shape: `[:1500]` + `_escape(...)` + `pre-wrap`.
- [x] `web/blueprints/tasks.py:~1006` (task owner action error) — same shape.
- [x] `web/blueprints/tasks.py:~1022` (task type action error) — same shape.
- [x] `web/blueprints/tasks.py:~1045` (task complete action error) — same shape.
- [x] `web/blueprints/tasks.py:~1061` (task status action error) — same shape.
- [x] `tests/unit/test_tasks_error_render_widen.py` exists and passes 5/5 (mirrors `test_cockpit_error_render_widen.py`): class invariant (no `[:200]/[:300]` truncations on tasks.py error render paths), exactly 6 `[:1500]` widenings, 6 `_escape(...)` wrappings, ≥6 `pre-wrap` style declarations within 200 chars before each widened site, and `_escape` helper definition is present.
- [x] `bin/fw reviewer T-2222` returns `Overall: PASS` with zero findings.

### Human
- [ ] [REVIEW] Widened error fragments render readably on a real htmx action error in tasks.py routes.
  **Steps:**
  1. Open http://192.168.10.107:3000/tasks in a browser
  2. Open an existing task's detail page (e.g. http://192.168.10.107:3000/tasks/T-1062)
  3. Trigger a status update action that the framework gate will refuse (e.g. attempt to set a status that requires unchecked Human AC ticking, or hit the focus-drift / no-active-task gate while editing)
  4. Observe the inline error fragment that replaces the action's response area
  **Expected:** The fragment fills the htmx swap area with a readable multi-line message — line breaks preserved, full gate output visible up to the 1500-char cap, no rendered HTML tags or angle-bracket bleed-through. The mechanical contracts (escape, pre-wrap, 1500-char cap) are pinned by the agent test; this pass confirms the operator's actual reading experience in a real browser session.
  **If not:** Capture the rendered fragment + the actual stderr returned by the gate, attach to a follow-up task referencing T-2222 + OBS-049.

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

# T-2222: 6-site widening contract — no narrow [:200]/[:300] truncations survive
# on tasks.py error-render paths; widened sites carry _escape + pre-wrap.
out=$(python3 -m pytest tests/unit/test_tasks_error_render_widen.py -q 2>&1); echo "$out" | grep -q "5 passed"
# Class invariant: zero narrow truncations remain in tasks.py
out=$(grep -cE '\)\[:200\]|\)\[:300\]' web/blueprints/tasks.py 2>&1); test "$out" = "0"
# Exactly 6 widened sites
out=$(grep -cE '\)\[:1500\]' web/blueprints/tasks.py 2>&1); test "$out" = "6"
# _escape helper present in tasks.py
grep -q "^def _escape" web/blueprints/tasks.py
# Reviewer PASS
out=$(bin/fw reviewer T-2222 2>&1); echo "$out" | grep -q "Overall:.*PASS"

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

## Decisions

### 2026-06-05 — `_escape` helper placement: inline vs. shared
- **Chose:** Inline module-level helper in tasks.py (mirrors cockpit.py:255-258).
- **Why:** Blueprints stay self-contained; shared extraction is a real refactor that would
  need its own task + tests across consumers. Two implementations of a 4-line escape function
  is acceptable cost vs. coupling 6 blueprints to web/shared.py for a 4-line helper.
- **Rejected:** Add to `web/shared.py` and import from both cockpit.py + tasks.py. Deferred —
  if a third blueprint needs the helper, file a refactor task at that point; until then, the
  two-blueprint duplication is below the "extract" threshold.

## Recommendation

**Recommendation:** GO

**Rationale:** OBS-049 full-class closure shipped on the same pattern as T-2219 (inception
decide warning) and T-2221 (cockpit.py 4 sites). The widening, escape, and pre-wrap contract
is mechanically pinned by `tests/unit/test_tasks_error_render_widen.py` (5/5 PASS) + the
class invariant test (no narrow `[:200]/[:300]` truncations survive on tasks.py error
render paths). Reviewer PASS first scan after re-casting the [REVIEW] Expected to remove
the `'shows n'` mechanical-signal false-positive. The [REVIEW] Human AC is the genuine
human-readable judgment that the operator's browser experience matches the mechanical contract.

**Evidence:**
- `web/blueprints/tasks.py:21-29` — `_escape` helper added (4-line `str.replace` chain).
- `web/blueprints/tasks.py` — 6 widened sites at the 6 routes
  (`/api/task/create`, horizon, owner, type, complete, status).
- `tests/unit/test_tasks_error_render_widen.py` — 5/5 PASS first run + after recast.
- `bin/fw reviewer T-2222` — `Overall: PASS`, zero findings (R-f6c2a71a, after recast).
- XSS class addressed: previously raw f-string interpolation of stderr into HTML; now
  `_escape((stderr or stdout)[:1500])` defuses `<`, `>`, `&`, `"` in hostile error text.
- Class closure: cockpit.py 4 (T-2221) + tasks.py 6 (this) = 10 total; OBS-049 captured 9,
  this task discovered the 10th (L1061 — the `/api/task/<id>/status` route) and dismisses
  OBS-049 on close.

## Evolution

### 2026-06-05 — OBS-049 was off by one
- **What changed:** Memory said "5 sites in tasks.py at lines 972/990/1006/1022/1045". Live grep
  found **6**: line 1061 (`/api/task/<id>/status` route) was missed in the original capture.
- **Plan impact:** Unit test asserts exactly 6 widened sites (not 5); class invariant on
  zero narrow truncations would have caught the missed site at close-gate time anyway,
  but explicit discovery during scope assessment is cleaner.
- **Triggered:** No new sub-task — the 6th site is absorbed into this task's scope; OBS-049
  dismissed at close instead of partial closure (4+5=9 of 9 deferred to 4+6=10 of 10 done).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-05T21:48:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2222-taskspy-6-site-sibling-widening--apply-t.md
- **Context:** Initial task creation

### 2026-06-05T21:48:50Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c5d81b13
- **Timestamp:** 2026-06-05T21:55:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
