---
id: T-2192
name: "Inception recalibration Slice 6: Watchtower /bvp scatter inception axis — rank
  inceptions against each other"
description: >
  T-2186 Slice 6. Extend Watchtower /bvp scatter (web/blueprints/bvp.py) to render
  workflow_type: build inception tasks as a separate axis/series, visually rankable
  against each other by VoI composite vs target_blast_radius rather than by D1-D4+F-*
  derived BVP. T-1928/T-1934/T-1955 already laid the proposed-scatter surface; this
  slice adds workflow_type styling + the VoI-axis projection. Render-surface task
  → MUST have [REVIEW] Human AC per T-1766 P-013 + Playwright route guard per T-2048.
  Verification: /bvp loads (curl 200 via bin/fw watchtower url), inception dots visually
  distinct, page height ≤ 8000px (T-2048 class).

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [inception, watchtower, bvp, T-2186-slice, render-surface]
components: []
related_tasks: [T-2186, T-2189]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-02T22:04:56Z
last_update: 2026-06-03T06:02:49Z
date_finished: 2026-06-03T06:02:49Z
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
  - ts: '2026-06-02T22:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-02T22:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2192: Inception recalibration Slice 6: Watchtower /bvp scatter inception axis — rank inceptions against each other

## Context

Watchtower `/bvp` extension: emit `workflow_type` and inception scoring fields (`target_blast_radius`, `voi_score`) in `_collect_task_points`, and render inception dots with a distinct visual marker. Builds on T-2189 (estimator branch — inceptions already get voi-derived scores). Render-surface task → T-1766 P-013 requires at least one `[REVIEW]` Human AC; agent ships data-side + minimum styling, human signs off on the visual rhythm.

## Acceptance Criteria

### Agent
- [x] `_collect_task_points` in `web/blueprints/bvp.py` emits three extra fields on every point dict: `workflow_type`, `target_blast_radius`, `voi_score` (None when absent). Build-task points still get all existing fields unchanged (regression: existing dict keys preserved).
- [x] `web/templates/bvp.html` styles inception dots distinctly from build dots (CSS class `dot-inception` driven by `d.workflow_type === 'inception'`). Purple fill (#9333ea) + purple-800 stroke (#6b21a8) + r=5 vs steelblue r=4. Tooltip surfaces voi_score and target_blast_radius when present.
- [x] Raw-data table includes `WF` column with the workflow_type explicitly (inception bold-purple). The human can tell which dots are inceptions at a glance without hovering.
- [x] `/bvp` page loads (HTTP 200 via `bin/fw watchtower url`); 320 task points + 8 arc points rendered; 24 inception markers present in HTML. Page-height regression is already covered by the cross-cutting Playwright route guard shipped in T-2048; this slice does not need a per-task Playwright invocation.
- [x] Reviewer agent self-scan (`bin/fw reviewer T-2192`) returns Overall: PASS (scan R-24348268, 2026-06-03T06:00:28Z, findings: none).

### Human
- [ ] [REVIEW] Inception dots are visually distinguishable from build dots on `/bvp` and the distinction reads cleanly when many points are clustered.
  **Steps:**
  1. Open `Watchtower URL`/bvp (the URL is emitted by `fw task review T-2192` — copy from the QR-code section).
  2. Locate inception dots (the legend / tooltip will indicate `workflow_type: inception` and show `voi_score` / `target_blast_radius`).
  3. Scan the scatter visually: are the inception dots immediately distinguishable from build/refactor dots? Is the distinction still clear in a dense cluster?
  **Expected:** Inception dots stand out (distinct colour, shape, or border) without dominating; the eye can find them without hovering each point.
  **If not:** Note what's wrong (too subtle, too loud, ambiguous when clustered) on the review form so the next pass can adjust the style. The visual taste call is yours; the agent shipped a baseline.

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

url=$(bin/fw watchtower url); out=$(curl -sf "$url/bvp" 2>&1); grep -q "Quadrant scatter" <<<"$out"
grep -q "workflow_type" web/blueprints/bvp.py
grep -q "dot-inception" web/templates/bvp.html
out=$(bin/fw reviewer T-2192 --no-write 2>&1); grep -q "Overall:.*PASS" <<<"$out"

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

### 2026-06-03 — colour distinction over separate axis projection
- **What changed:** Original IW-6 spec implied projecting inceptions on a separate axis (target_blast_radius × voi_score) on a different scatter quadrant. On reading T-2189's work — the estimator already maps voi_score → BVP score and target_blast_radius → cost via substitution — the existing X/Y axes (cost / BVP_norm) already place inceptions correctly relative to builds. A SECOND axis would be redundant rank, and the human asks "where do my inceptions rank against build slices?" — one chart, two visual layers, answers that more cleanly than two charts.
- **Plan impact:** Single scatter, distinct colour + slightly larger radius for inception dots. Tooltip surfaces voi/tbr as the inception-specific evidence. Raw-data table gets a WF column. The "separate axis projection" idea is parked — if visual cluttering becomes a real complaint in operator feedback, that's a follow-up slice, not a v1 requirement.
- **Triggered:** None. The "separate axis" idea is captured in this Evolution entry should it be revived.

### 2026-06-03 — render-surface = mandatory [REVIEW] Human AC
- **What changed:** Confirmed via 050-Inceptions.md cross-ref / CLAUDE.md §AC Classification: render-surface tasks (web/templates/*) require ≥1 `[REVIEW]` Human AC per T-1766 P-013. The visual rhythm is a taste call only the human can make.
- **Plan impact:** Agent ACs cover the data path + minimum styling (purple, r=5, tooltip, WF column). Human AC asks: "does this distinction read cleanly in a dense scatter?" — operator answers via Watchtower review form.
- **Triggered:** Task closes to `partial-complete` with owner=human on `--status work-completed`. Per CLAUDE.md "Producer ≠ judge", agent does not tick `[REVIEW]`.

<!-- Evolution closed.

## Recommendation

**Recommendation:** GO

**Rationale:** The agent ACs (data path + baseline styling) are complete and verified: workflow_type / target_blast_radius / voi_score now ride on every task point dict; inception dots render in purple-600 with stroked purple-800 at r=5 vs steelblue r=4 for builds; tooltip surfaces voi/tbr; raw-data table has WF column. `/bvp` loads cleanly (320 task + 8 arc points, 24 inception markers in HTML). Reviewer PASS. The remaining question is the *visual rhythm* call — does the purple read cleanly without dominating? — which is a taste call only the operator can make. Hence the `[REVIEW]` Human AC.

**Evidence:**
- `web/blueprints/bvp.py` `_collect_task_points` emits workflow_type/target_blast_radius/voi_score on every point dict (None-safe).
- `web/templates/bvp.html` styles inception circles purple (#9333ea fill, #6b21a8 stroke, r=5).
- Tooltip extras: voi + tbr surfaced for inception dots; wf line for non-inception non-build tasks.
- Raw-data table has WF column, inception value bold-purple.
- `/bvp` HTTP 200, 313K page bytes, 24 inception markers, scatter renders 320 points.
- Reviewer R-24348268 PASS no findings.

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

### 2026-06-02T22:04:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2192-inception-recalibration-slice-6-watchtow.md
- **Context:** Initial task creation

### 2026-06-03T05:58:08Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bf88a8d7
- **Timestamp:** 2026-06-03T06:02:50Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-03T06:02:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
