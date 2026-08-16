---
id: T-2034
name: "Move Arcs nav item from Architecture back to Work — human IA override of T-2008
  design-spec placement"
description: >
  Move Arcs nav item from Architecture back to Work — human IA override of T-2008
  design-spec placement

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [arc:watchtower-redesign, ui, watchtower, nav, ia]
components: [tests/playwright/test_breadcrumb.py, 
      tests/playwright/test_nav_subsections.py, tests/playwright/test_pins.py, 
      tests/unit/test_breadcrumb.py, tests/unit/test_nav_subsections.py, 
      web/shared.py]
related_tasks: [T-2008, T-1989, T-1987]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-24T16:21:51Z
last_update: '2026-08-16T22:24:04Z'
date_finished: 2026-05-26T06:52:05Z
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
  - ts: '2026-05-24T16:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-24T16:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:30Z'
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
  - ts: '2026-08-16T22:24:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2034: Move Arcs nav item from Architecture back to Work — human IA override of T-2008 design-spec placement

## Context

T-2008 (arc-007 S2a) moved **Arcs** from the **Work** nav group → **Architecture**, "per design"
(the Claude Design bundle's `nav-patterns.jsx` grouped Arcs with the structural views Fabric/Explorer/
Terminal/Sessions). T-2008's `[REVIEW]` Human AC for that exact move was never checked. The human
surfaced the placement as wrong ("why has arc been moved back to architecture from tasks??") —
exercising that pending review and **overriding the design**: arcs are groupings of tasks (work-
planning artifacts), so they belong under **Work** next to Tasks/BVP. This task reverses the move.

The breadcrumb index (`nav_breadcrumb`) is auto-derived from `NAV_GROUPS`, so the `/arcs` crumb
follows the group automatically — only the doc-comment example and the tests that pinned the
Architecture placement need updating.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Arcs leaf appears under **Work** in `NAV_GROUPS` and no longer under Architecture (`web/shared.py`)
- [x] `nav_group_labels("Work")` contains `"Arcs"`; `nav_group_labels("Architecture")` does not
- [x] `/arcs/arc-007` breadcrumb resolves to `["Work", "Arcs", "arc-007"]` (auto-derived; was Architecture) — unit test + live server both confirm
- [x] Stale tests flipped: `test_nav_subsections.py` + `test_breadcrumb.py` (unit + playwright) assert Work, not Architecture; `test_pins.py` nav-target updated
- [x] Breadcrumb doc-comment example in `web/shared.py` updated (`/arcs/arc-007 -> [(Work...`)
- [x] `pytest tests/unit/test_nav_subsections.py tests/unit/test_breadcrumb.py` passes (10/10); playwright nav+breadcrumb pass (7/7)

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
- [ ] [REVIEW] Arcs reads correctly under Work and the four nav groups still feel balanced
  **Steps:**
  1. Open http://192.168.10.107:3000/ (any nav layout)
  2. Open the **Work** dropdown — confirm **Arcs** sits between Tasks and BVP
  3. Open the **Architecture** dropdown — confirm Arcs is gone (Fabric / Explorer / Terminal / Sessions remain)
  4. Click **Work › Arcs**, then open any arc — confirm the breadcrumb reads **Work › Arcs › arc-NNN**
  **Expected:** Arcs feels at home under Work next to Tasks; no group looks lopsided; breadcrumb says Work
  **If not:** Note which group it should live in instead and I'll re-place it

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
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.
python3 -c "import sys; sys.path.insert(0,'.'); from web.shared import nav_group_labels; assert 'Arcs' in nav_group_labels('Work'); assert 'Arcs' not in nav_group_labels('Architecture'); print('nav placement OK')"
python3 -m pytest tests/unit/test_nav_subsections.py tests/unit/test_breadcrumb.py -q

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

### 2026-05-24 — design-spec IA decision reversed by human review
- **What changed:** T-2008 implemented the design bundle's IA literally (Arcs → Architecture). The
  design's grouping rationale ("arcs are architectural narratives") lost to the user's mental model
  ("arcs are groupings of tasks → Work"). The design bundle is an input, not an authority — the
  human's IA judgment overrides it. T-2008's own `[REVIEW]` AC existed precisely to catch this and
  was the right gate; it just sat unchecked.
- **Plan impact:** The arc-007 "follow the design" default needs an asterisk for IA/placement
  decisions — those are taste calls the human owns, not mechanical token swaps. Don't treat the
  design bundle as settled IA without the per-decision [REVIEW] landing.
- **Triggered:** This task (T-2034). No new sub-tasks — single-leaf move.

## Decisions

### 2026-05-24 — Arcs belongs under Work, not Architecture
- **Chose:** Move Arcs back to the **Work** nav group (between Tasks and BVP).
- **Why:** Arcs are groupings of tasks — work-planning artifacts the user reaches for alongside
  Tasks/BVP/Inception. The user surfaced the Architecture placement as surprising twice.
- **Rejected:** Keeping Arcs under Architecture (the design-bundle IA) — the design grouped it with
  structural/topology views (Fabric/Explorer), but that rationale didn't match how the user thinks
  about arcs. Human IA judgment > design-bundle default (sovereignty).

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

- **Recommendation:** GO
- **Rationale:** Reverses the T-2008 design-spec placement per your expressed preference. Arcs now
  sits under **Work** (between Tasks and BVP); the breadcrumb auto-follows. All 6 Agent ACs pass and
  the reviewer is PASS with no findings. The one Human AC is the eyes-on taste check — does Arcs feel
  at home under Work and do the four nav groups still look balanced.
- **Evidence:**
  - `web/shared.py` NAV_GROUPS: Arcs leaf moved Architecture → Work; breadcrumb doc-comment updated
  - `nav_group_labels` check: Arcs ∈ Work, Arcs ∉ Architecture (passes)
  - Unit: `test_nav_subsections.py` + `test_breadcrumb.py` flipped and green (10/10)
  - Playwright DOM proof: `test_arcs_lives_under_work` + breadcrumb htmx-nav assert "Work › Arcs" (7/7)
  - Live :3000 server: `/arcs/arc-007` breadcrumb renders **"Work › Arcs › arc-007"**
  - Reviewer R-0b319170: PASS, needs_human=no, findings none

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-24T16:21:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2034-move-arcs-nav-item-from-architecture-bac.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4f89acf6
- **Timestamp:** 2026-05-26T06:52:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-26T06:52:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
