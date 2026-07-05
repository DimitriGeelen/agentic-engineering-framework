---
id: T-2349
name: "T-2347a Slice A1 — arc_detail.html Close-arc button + collapsible CLI fallback"
description: >
  Replace inline CLI block at web/templates/arc_detail.html:417-447 with primary Close-arc
  button linking to /arcs/<slug>/close (form route exists at web/blueprints/arcs.py:1253).
  Keep three-question prose. Move CLI into collapsible details fallback for headless
  contexts. Add Playwright pin to guard button presence.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, arc-mechanics, ux]
components: [web/templates/arc_detail.html]
related_tasks: [T-2347, T-1911, T-2348]
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
created: 2026-06-12T10:38:21Z
last_update: 2026-07-05T00:30:20Z
date_finished: 2026-07-05T00:30:20Z
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
  - ts: '2026-06-12T10:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-13T18:00:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-02T16:15:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      audit_severity: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); 
      audit_severity=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-12T10:45:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2349: T-2347a Slice A1 — arc_detail.html Close-arc button + collapsible CLI fallback

## Context

Slice A1 of T-2347a (arc-action Watchtower UX). `web/templates/arc_detail.html` (~line 417-447) hands the operator a raw `fw arc close` CLI block; the Watchtower close form already exists at `/arcs/<slug>/close` (`web/blueprints/arcs.py:1253`). Replace the inline CLI with a primary Close-arc button linking to the form; keep the three-question §ACD prose; move the CLI into a collapsible `<details>` fallback for headless contexts (per CLAUDE.md §Arc Action Handoffs — URL primary, CLI fallback).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Non-closed arc detail page shows a primary "Close this arc" button/link to `/arcs/<slug>/close`; the three-question §ACD prose stays
- [x] The `fw arc close` CLI block moves inside a collapsed `<details>` fallback (not removed — headless contexts still need it)
- [x] Playwright test pins: button href present on a non-closed arc; CLI block inside details; closed arcs render neither (T-971 rule)

### Human
- [ ] [REVIEW] Close-arc button placement reads clean on the arc detail page
  **Steps:**
  1. Open `{watchtower_url}/arcs/<any in-progress arc>` (list at `{watchtower_url}/arcs`)
  2. Scroll to the §Arc Completion Discipline section: check the button leads, the CLI is tucked in the collapsed fallback, nothing is crowded
  **Expected:** the close path is obvious at a glance; the three-question prose still frames it
  **If not:** note the crowded/odd element; agent adjusts spacing or wording

## Verification

# Origin-based checks (MAIN's branch lags origin/master where this lands).
git show origin/master:web/templates/arc_detail.html > /tmp/.t2349-tpl && grep -q "close-arc-button" /tmp/.t2349-tpl
grep -q "close-arc-cli-fallback" /tmp/.t2349-tpl
grep -q "fw arc close" /tmp/.t2349-tpl
git show origin/master:tests/playwright/test_arc_close_button.py > /tmp/.t2349-pw && grep -q "close-arc-button" /tmp/.t2349-pw

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

## Recommendation

**Recommendation:** GO — approve the render.

**Rationale:** The primary affordance is now the guided `/arcs/<slug>/close` form (per §Arc Action Handoffs, T-2347); the CLI and §ACD gate prose are preserved verbatim inside a collapsed fallback, so headless contexts lose nothing. Both directions pinned by Playwright.

**Evidence:**
- `web/templates/arc_detail.html`: `.close-arc-button` → `/arcs/<slug>/close`, CLI in `<details class="close-arc-cli-fallback">`
- `tests/playwright/test_arc_close_button.py`: open arc shows button + collapsed CLI; closed arc renders neither (2/2 pass)

## Updates

### 2026-06-12T10:38:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2349-t-2347a-slice-a1--arcdetailhtml-close-ar.md
- **Context:** Initial task creation

### 2026-07-05T00:24:40Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d41341c0
- **Timestamp:** 2026-07-05T00:30:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-05T00:30:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
