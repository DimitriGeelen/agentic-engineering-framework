---
id: T-1980
name: "T-1978 sibling: show BVP scores/cost on task detail page (/tasks/T-XXX)"
description: >
  T-1978 sibling: show BVP scores/cost on task detail page (/tasks/T-XXX)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [arc:value-prioritisation, bvp, watchtower, web-ui]
components: [tests/playwright/test_arc_detail_bvp.py, tests/playwright/test_task_detail_bvp.py, tests/playwright/test_tasks_listing_bvp.py, web/blueprints/tasks.py, web/templates/base.html, web/templates/_partials/bvp_badge.html, web/templates/task_detail.html, web/templates/tasks.html]
related_tasks: [T-1978, T-1956, T-1929]
arc_id: value-prioritisation
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-21T13:46:27Z
last_update: 2026-05-22T07:16:56Z
date_finished: 2026-05-22T07:16:56Z
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
  - ts: '2026-05-21T14:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-21T14:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-1980: T-1978 sibling: show BVP scores/cost on task detail page (/tasks/T-XXX)

## Context

Human round-trip on arc-006 surfaced a visibility gap: BVP scores and composite are visible on `/bvp` (scatter) and `/arcs/<id>` (T-1978 constituent table) but NOT on the individual task surface (`/tasks/T-XXX`). To answer "what's this task's BVP?" the user has to leave the task page and find it in another view. This is a per-task render gap, same class as T-1956 (arc-detail BVP) and T-1978 (arc constituent BVP).

Smallest deliverable: a BVP block on `/tasks/T-XXX` reusing the same `web.blueprints.bvp` helpers (no math drift between surfaces).

## Acceptance Criteria

### Agent
- [x] `web/blueprints/tasks.py` exposes a `_task_bvp_data(task_data)` helper returning `{mode, scores, bvp_raw, bvp_norm, cost, cost_source, weights}`. Mode is `confirmed` when `bvp_scores:` is present, `proposed` when only `bvp_scores_proposed:` is present, `none` when neither.
- [x] `task_detail` route computes `bvp = _task_bvp_data(task_data)` and passes to the template.
- [x] `web/templates/task_detail.html` renders a `<section class="bvp-block">` showing per-driver scores (D1-D4 + any free drivers), BVP_norm (3dp), BVP_raw (int), Cost (3dp), Cost source (composite/tshirt/default-medium), provenance label (Confirmed/Proposed/None).
- [x] When mode == 'none', the section renders a single-line muted hint linking to `/bvp` rather than a numeric grid (avoid empty zero-rows).
- [x] Math drift impossible: the helper uses `_compute_bvp`, `_compute_cost`, `_resolve_cost_estimate`, `_latest_proposed_scores` from `web.blueprints.bvp` (same code path as `/bvp` and `/arcs/<id>`).
- [x] Playwright pin: `tests/playwright/test_task_detail_bvp.py` opens a task with confirmed scores → BVP block visible → `BVP_norm` row present with `\d+\.\d{3}` number.
- [x] All existing Playwright still green: `pytest tests/playwright/test_arc_detail_bvp.py` → 22 passed, 1 skipped (arc-at-cap defensive skip added).

### Human
- [ ] [REVIEW] BVP block scannability — open `/tasks/T-1976` or `/tasks/T-1978` and confirm: BVP scores read at a glance, provenance is unambiguous (proposed vs confirmed visually distinct), Cost is contextualized (you understand whether it's composite or fallback). Numbers match what `/bvp` shows for the same task.
  **Steps:**
  1. Open http://192.168.10.107:3000/tasks/T-1976
  2. Scroll to the BVP block (below Recommendation/Reviewer)
  3. Note the BVP_norm number
  4. Open http://192.168.10.107:3000/bvp and Ctrl-F for T-1976
  5. Compare BVP_norm values
  **Expected:** Numbers identical; block visually distinct; provenance label clear.
  **If not:** Note the discrepancy and which surface is wrong.

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

### 2026-05-21 — Per-task BVP block surfaces the arc-scoped driver gap
- **What changed:** Shipping per-task BVP on `/tasks/T-XXX` made the asymmetry between arc-rollup (scoped drivers contribute) and per-task (D1-D4 only) visible. The block correctly renders what's in `bvp_scores:` and `_compute_bvp` output, but the missing scoped-driver contribution wasn't a defect — it surfaced an unanswered design question.
- **Plan impact:** T-1980's own scope stays as-shipped (display per-task BVP). The asymmetry question is out of scope here.
- **Triggered:** T-1981 inception ("how should arc-scoped drivers contribute to per-task BVP?") filed 2026-05-21; T-1982 (BVP chip on /tasks listing) carried the parity forward to kanban + list view.

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

**Rationale:** Closes the per-task BVP visibility gap that the user surfaced after T-1978. The `/tasks/T-XXX` page now shows the same scores and composite that `/bvp` and `/arcs/<id>` show, sharing the math via the existing `web.blueprints.bvp` helpers — drift impossible by construction. Three rendering modes (confirmed / proposed / none) each have a distinct visual treatment and the "View on /bvp →" link gives one-click cross-surface navigation.

**Evidence:**
- `web/blueprints/tasks.py:21-72` — `_task_bvp_data` helper.
- `web/blueprints/tasks.py:653-654` — route wires `bvp = _task_bvp_data(task_data)` and passes to render_page.
- `web/templates/task_detail.html:313-371` — `<section class="bvp-block">` with confirmed/proposed/none branches.
- `tests/playwright/test_task_detail_bvp.py` — 5/5 green: block renders, h3 heading present, mode attribute set, BVP_norm has 3dp number, link to /bvp present.
- `tests/playwright/test_arc_detail_bvp.py` — 22 passed, 1 defensively skipped (arc-at-cap). Pre-existing T-1976 test made defensive against arc reaching M2 cap.
- Live smoke: `curl http://localhost:3000/tasks/T-1978` → contains `<section class="bvp-block" data-bvp-mode="proposed">`.

## Updates

### 2026-05-21T13:46:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1980-t-1978-sibling-show-bvp-scorescost-on-ta.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-a263ed42
- **Timestamp:** 2026-05-22T07:16:56Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 4

**Per-AC findings:**

- **AC#1 (Agent)** — `web/blueprints/tasks.py` exposes a `_task_bvp_data(task_data)` helper returning `{mode, scores, bvp_raw, bvp_norm, cost, cost_source, weights}`. Mode is `confirmed` when `bvp_scores:` is present, `pr
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/tasks.py in: `web/blueprints/tasks.py` exposes a `_task_bvp_data(task_data)` helper returning `{mode, scores, bvp_raw, bvp_norm, cost, cost_source, weights}`. Mode`
- **AC#3 (Agent)** — `web/templates/task_detail.html` renders a `<section class="bvp-block">` showing per-driver scores (D1-D4 + any free drivers), BVP_norm (3dp), BVP_raw (int), Cost (3dp), Cost source (composite/tshirt/
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/task_detail.html in: `web/templates/task_detail.html` renders a `<section class="bvp-block">` showing per-driver scores (D1-D4 + any free drivers), BVP_norm (3dp), BVP_raw`
- **AC#6 (Agent)** — Playwright pin: `tests/playwright/test_task_detail_bvp.py` opens a task with confirmed scores → BVP block visible → `BVP_norm` row present with `\d+\.\d{3}` number.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/playwright/test_task_detail_bvp.py in: Playwright pin: `tests/playwright/test_task_detail_bvp.py` opens a task with confirmed scores → BVP block visible → `BVP_norm` row present with `\d+\.`
- **AC#7 (Agent)** — All existing Playwright still green: `pytest tests/playwright/test_arc_detail_bvp.py` → 22 passed, 1 skipped (arc-at-cap defensive skip added).
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/playwright/test_arc_detail_bvp.py in: All existing Playwright still green: `pytest tests/playwright/test_arc_detail_bvp.py` → 22 passed, 1 skipped (arc-at-cap defensive skip added).`

### 2026-05-22T07:16:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
