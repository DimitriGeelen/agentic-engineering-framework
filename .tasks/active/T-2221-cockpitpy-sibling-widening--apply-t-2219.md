---
id: T-2221
name: "cockpit.py sibling widening — apply T-2219 escape+pre-wrap+1500 pattern to
  4 scan/action error renders (OBS-049 partial closure)"
description: >
  cockpit.py sibling widening — apply T-2219 escape+pre-wrap+1500 pattern to 4 scan/action
  error renders (OBS-049 partial closure)

status: started-work
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-05T20:53:56Z
last_update: '2026-07-07T10:45:06Z'
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
  - ts: '2026-06-05T21:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T16:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-13T18:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-07T10:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-05T21:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2221: cockpit.py sibling widening — apply T-2219 escape+pre-wrap+1500 pattern to 4 scan/action error renders (OBS-049 partial closure)

## Context

OBS-049 partial closure (sibling class-fix derived from T-2219). `web/blueprints/cockpit.py` has 4 sites that render `_escape(stderr[:N])` where N ∈ {200, 300} for scan/action error fragments returned to htmx swap:
- **L271** (`scan_refresh`) — scan stderr at 300
- **L301** (`scan_approve`) — action stderr at 200
- **L354** (`scan_apply`) — apply stderr at 200
- **L367** (`scan_focus`) — focus-set stderr at 200

All four already escape correctly; all four lack `white-space:pre-wrap`; all four are too narrow for multi-line gate stderr. They share the same fragility class as T-2219's inception-decide warning truncation — if a gate that runs through these routes emits a multi-line block message (bullet list + bypass options), the operator sees only the first sentence and has no in-page recovery.

**Slice contract** (mirrors T-2219): widen 200/300 → 1500, keep escape, add `white-space:pre-wrap` to the wrapping `<p>` style. Unit test pins all three properties on all four sites.

**Not in scope:** tasks.py sibling sites (5 instances at lines 972/990/1006/1022/1045) — separate task; the cockpit sweep is bounded for one-commit shipping. fleet.py / approvals.py JSON API responses — intentionally narrow (machine-consumed).

## Acceptance Criteria

### Agent
- [x] `web/blueprints/cockpit.py:271` (scan_refresh error) — widened to `[:1500]` + `white-space:pre-wrap` in the inline style; `_escape(...)` unchanged.
- [x] `web/blueprints/cockpit.py:301` (scan_approve action error) — same shape: `[:1500]` + `pre-wrap` + escape.
- [x] `web/blueprints/cockpit.py:354` (scan_apply error) — same shape.
- [x] `web/blueprints/cockpit.py:367` (scan_focus error) — same shape.
- [x] Unit test `tests/unit/test_cockpit_error_render_widen.py` pins on all four sites: (a) `[:1500]` is the effective truncation, (b) `_escape(stderr` is present, (c) `white-space:pre-wrap` style on the wrapping element. Test PASSes against fixed source.
- [x] Reviewer static-scan PASS on this task.

### Human

- [ ] [REVIEW] Cockpit scan/action error fragments render cleanly when widened multi-line stderr fires
  **Steps:**
  1. Open http://192.168.10.107:3000/ (root is the cockpit dashboard — `/cockpit` is not a route)
  2. Trigger a scan-refresh / scan-action that surfaces an error (e.g. force a gate to fire). If no live trigger handy, use browser DevTools to POST `/api/scan/refresh` and observe the returned htmx fragment — or just `grep -nE 'white-space:\s*pre-wrap' web/blueprints/cockpit.py` to confirm the 4 sites carry the style.
  3. Confirm: any rendered error fragment with multi-line stderr shows full content (not clipped at the first sentence), newlines render as line breaks, no HTML-escape glitches.

  **Expected:** Error fragments fit their card width without breaking the surrounding cockpit layout; layout reads clean on dark + light palettes.

  **If not:** Note the route and the rendering glitch; screenshot for follow-up.

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

python3 -m pytest tests/unit/test_cockpit_error_render_widen.py -x -q
grep -c '\[:1500\]' web/blueprints/cockpit.py
grep -c 'white-space:pre-wrap' web/blueprints/cockpit.py
out=$(bin/fw reviewer T-2221 --no-write 2>&1); echo "$out" | grep -q "Overall:.*PASS"

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

## Recommendation

**Recommendation:** GO

**Rationale:** Pattern-matched T-2219's escape+pre-wrap+1500 shape across 4 cockpit.py sibling render sites in one slice. All 6 Agent ACs PASS; reviewer PASS first-try; unit test (5/5 PASS) pins all three properties on every widened site AND asserts no narrow-truncation form remains, so future re-narrowing fails before merge. OBS-049 partially closed (4 of 9 sibling sites; 5 remaining in tasks.py).

**Evidence:**
- 4 widened sites in `web/blueprints/cockpit.py`: scan_refresh (L271 area), scan_approve (L301 area), scan_apply (L354 area), scan_focus (L367 area).
- Unit test `tests/unit/test_cockpit_error_render_widen.py` — 5/5 PASS.
- Reviewer T-2221: PASS, 0 findings.
- Class invariant: `re.findall(r"stderr\[:(?:200|300)\]", src)` returns 0 matches (test_no_narrow_stderr_truncations_remain).
- Remaining sibling work (tasks.py 5 sites) — not bundled here; can be filed as a follow-up T-2222 if operator wants full OBS-049 closure.

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

### 2026-06-05T20:53:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2221-cockpitpy-sibling-widening--apply-t-2219.md
- **Context:** Initial task creation
