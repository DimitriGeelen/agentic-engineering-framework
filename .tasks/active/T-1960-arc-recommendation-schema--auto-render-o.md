---
id: T-1960
name: "arc Recommendation schema + auto-render on /arcs/<slug>/close"
description: >
  T-1959 build child A: agent writes `## Recommendation` (CLOSE/KEEP-OPEN/DEFER) on
  arc's anchor task; /arcs/<slug>/close reads it and pre-fills demo path + surfaces
  rationale/evidence inline; human action reduced to Approve/override. See T-1959
  Scope Fence for details.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [approval-ux, watchtower, arc, T-1959-followup, arc:arc-grooming]
components: [tests/playwright/test_arc_close_recommendation_panel.py, 
      tests/unit/extract_recommendation_close_keep_open.bats, 
      web/blueprints/arcs.py, web/shared.py, web/templates/arc_close.html]
related_tasks: [T-1959, T-1911]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T17:56:28Z
last_update: '2026-05-28T22:54:10Z'
date_finished: 2026-05-21T17:33:47Z
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
  - ts: '2026-05-20T18:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-20T18:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1960: arc Recommendation schema + auto-render on /arcs/<slug>/close

## Context

T-1959 (inception) decided GO on parity between arc-close and inception-decide approval surfaces. T-1911 shipped the `/arcs/<slug>/close` form, but it renders blank — the human has to recall the demo path, write the decision narrative, and answer §ACD from scratch. The agent's `## Recommendation` on the *anchor task* (the right home per T-1959 A1) has nowhere to surface near the human's decision point.

T-1960 closes that gap: extend the existing `extract_recommendation` parser (web/shared.py) to accept CLOSE/KEEP-OPEN verdicts alongside GO/NO-GO/DEFER, have `arc_close_surface` read the anchor task's Recommendation block, and render rationale/evidence inline on `/arcs/<slug>/close`. Pre-fill the demo-path field from the first `docs/reports/...` link in evidence so the human only Approves or overrides.

## Acceptance Criteria

### Agent
- [x] `extract_recommendation` in `web/shared.py` recognises `CLOSE` and `KEEP-OPEN` as verdicts (in addition to GO/NO-GO/DEFER), preserving existing GO/NO-GO/DEFER behaviour
- [x] `arc_close_surface` in `web/blueprints/arcs.py` reads the arc's anchor-task body (when present), calls `extract_recommendation`, and passes a `recommendation` dict to the template — verdict, rationale, evidence, all empty-string-safe when no anchor task or no Recommendation block
- [x] `web/templates/arc_close.html` renders a Recommendation panel above the form when a recommendation exists — verdict badge + rationale + evidence; absent panel when no recommendation
- [x] Demo-path field is pre-filled from the first `docs/reports/...` path (or URL) found in the recommendation's evidence text when no POST has occurred and no `prev_demo_value` is set
- [x] Bats unit test `tests/unit/extract_recommendation_close_keep_open.bats` pins the parser extension (CLOSE / KEEP-OPEN verdicts extracted from fixture bodies)
- [x] Playwright test `tests/playwright/test_arc_close_recommendation_panel.py` asserts the panel renders on an arc with anchor-task Recommendation (DOM-content assertions per T-1575) — no element-presence grep
- [x] `bash -n web/blueprints/arcs.py` (syntax via `python3 -c "import ast; ast.parse(open('web/blueprints/arcs.py').read())"`)
- [x] Watchtower restart + live `curl /arcs/value-prioritisation/close` confirms the panel renders with arc-006 anchor recommendation (or absence-rendering on an arc without one)

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

- [ ] [REVIEW] Recommendation panel layout reads cleanly above the close form — verdict badge prominent, rationale legible, evidence not buried, demo-path pre-fill obvious
  **Steps:**
  1. Open http://192.168.10.107:3000/arcs/value-prioritisation/close (or another arc whose anchor task has a `## Recommendation` block)
  2. Read the page top-to-bottom
  **Expected:** Recommendation panel sits between the arc header card and the §ACD prompt. Verdict (CLOSE/KEEP-OPEN/DEFER) is visually distinct from the rationale text. Evidence list is scannable. Demo-path field below shows pre-filled value from the recommendation's first `docs/reports/...` path; field is editable.
  **If not:** Note what visually clashes (verdict invisible, evidence too dense, demo-path not pre-filled).

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

python3 -c "import ast; ast.parse(open('web/blueprints/arcs.py').read())"
python3 -c "import ast; ast.parse(open('web/shared.py').read())"
bats tests/unit/extract_recommendation_close_keep_open.bats
FW_TEST_PORT=3000 python3 -m pytest tests/playwright/test_arc_close_recommendation_panel.py -q
out=$(curl -s http://localhost:3000/arcs/value-prioritisation/close 2>&1); [[ "$out" == *"arc-close-hdr"* ]]

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

### 2026-05-21 — verdict-extension vs new arc-side schema
- **What changed:** T-1959 Scope Fence A1 named CLOSE/KEEP-OPEN as the arc-anchor verdicts. The existing `extract_recommendation` parser in `web/shared.py` already serves /review and /approvals for inception-decide (GO/NO-GO/DEFER). Extending one regex alternation gives us four arc-close-bearing verdicts everywhere `extract_recommendation` is called, with no schema bifurcation.
- **Plan impact:** No new arc-side YAML schema; the anchor task body remains the single source of truth.
- **Triggered:** Documented the verdict vocabulary in the bats fixture so future agents see CLOSE/KEEP-OPEN as first-class.

### 2026-05-21 — render-layer markdown pre-render (no jinja filter)
- **What changed:** Initially tried to use a `render_md_safe` jinja filter that doesn't exist. The existing pattern across `/review` and `/tasks/<id>` is pre-render in the blueprint (`render_markdown_safe(rationale)`) and pass `_html` keys to the template.
- **Plan impact:** Helper returns `rationale_html` + `evidence_html`; template just `| safe`-renders the strings.
- **Triggered:** Same shape as `review.py:163-168` — kept the cross-surface conformance instead of inventing a filter.

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

**Recommendation:** GO

**Rationale:** Closes T-1959's load-bearing gap (A1, A2): the agent's CLOSE/KEEP-OPEN advisory now lives on the anchor task's `## Recommendation` block AND surfaces inline on `/arcs/<slug>/close` so the human approves with full context instead of filling a blank form. Single-regex parser extension keeps schema unified across inception-decide and arc-close. Demo path pre-fill removes the recall-from-memory step at decision time. Render-surface gate satisfied by the [REVIEW] AC; all 9 bats + 5 Playwright + curl smoke pass; no blast-radius (helper-add only).

**Evidence:**
- `web/shared.py`: `extract_recommendation` regex extended `(KEEP-OPEN|NO-GO|CLOSE|GO|DEFER)` — alternation order preserves GO/NO-GO precedence (NO-GO before GO; KEEP-OPEN, CLOSE on the inside)
- `web/blueprints/arcs.py`: new `_anchor_recommendation(arc)` helper resolves anchor task in active/ or completed/, pre-renders rationale/evidence HTML via `render_markdown_safe`, extracts first `docs/reports/*` or `https?://...` from evidence as `suggested_demo`
- `web/blueprints/arcs.py`: `arc_close_surface` passes `recommendation=` to template; `prev_demo_value` falls back to `suggested_demo` on GET
- `web/templates/arc_close.html`: new `.anchor-rec` section above the form with verdict badge, rationale, evidence, demo pre-fill hint
- bats `tests/unit/extract_recommendation_close_keep_open.bats` (9 tests, all PASS) — CLOSE/KEEP-OPEN extracted, GO/NO-GO/DEFER regression-guarded, case-insensitive, absent-section handled
- Playwright `tests/playwright/test_arc_close_recommendation_panel.py` (5 tests, all PASS) — DOM-content assertions per T-1575: panel renders, badge shows canonical verdict, anchor link present, rationale substantive, panel positioned above form
- Live smoke: `curl /arcs/value-prioritisation/close` renders verdict-GO panel with T-1915 rationale + evidence; `curl /arcs/orchestrator-rethink/close` same shape; `curl /arcs/dispatch-safety/close` 302→/arcs/dispatch-safety (closed-arc gate, expected)
- Absence-rendering: helper returns `present: False` on no-anchor and nonexistent-anchor; template's `{% if recommendation and recommendation.present %}` suppresses the panel cleanly

**Review on Watchtower:** http://192.168.10.107:3000/review/T-1960

## Updates

### 2026-05-20T17:56:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1960-arc-recommendation-schema--auto-render-o.md
- **Context:** Initial task creation

### 2026-05-21T17:22:18Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.4)

- **Scan ID:** R-26ca5868
- **Timestamp:** 2026-05-21T17:34:01Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — `web/templates/arc_close.html` renders a Recommendation panel above the form when a recommendation exists — verdict badge + rationale + evidence; absent panel when no recommendation
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/arc_close.html in: `web/templates/arc_close.html` renders a Recommendation panel above the form when a recommendation exists — verdict badge + rationale + evidence; abse`

### 2026-05-21T17:33:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
