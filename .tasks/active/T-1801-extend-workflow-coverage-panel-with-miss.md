---
id: T-1801
name: "extend Workflow coverage panel with missing-provider class — web parity for
  T-1800 (sibling to T-1799)"
description: >
  extend Workflow coverage panel with missing-provider class — web parity for T-1800
  (sibling to T-1799)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [web, observability]
components: [tests/unit/test_orchestrator_workflow_coverage.py, 
      web/templates/orchestrator.html]
related_tasks: [T-1776, T-1797, T-1798, T-1799, T-1800]
arc_id: orchestrator-rethink
created: 2026-05-13T06:25:23Z
last_update: '2026-05-28T22:54:09Z'
date_finished: 2026-05-13T06:29:52Z
bvp_scores_proposed:
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 4
      D3: 3
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=4 (body:fw-audit-or-doctor);
      D3=3 (body:component-discoverability); D4=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1801: extend Workflow coverage panel with missing-provider class — web parity for T-1800 (sibling to T-1799)

## Context

T-1800 added a second failure class to the audit-time workflow coverage check: **pi workflows lacking a `provider` field**. `lib/spawn._spawn_pi` raises `SpawnError` at runtime when both envelope and workflow lack a provider — T-1800 surfaces it at audit time. T-1799 surfaced the *unroutable worker_kind* class on `/orchestrator`, but the missing-provider class only appears in `fw audit` output today. This slice closes the visibility parity gap: the web panel currently shows `report["unroutable_workflows"]` but ignores `report["pi_workflows_missing_provider"]`, so an operator looking at the page sees `OK` even when the audit would FAIL.

Surface changes (mirror existing panel rhythm):
- **Workflow table:** add a `provider` column (4th column). Empty cell when not pi; cell with warning style when pi-without-provider.
- **Status badge:** today derives from `report["ok"]` only via `unroutable_workflows`. Switch to using `report["ok"]` directly — the helper already ANDs both classes.
- **Footer line:** add "Missing provider: wf-X, wf-Y" line when `pi_workflows_missing_provider` non-empty (parallel to the existing "Declarable but unroutable" line).

The helper (`lib/workflow_coverage.check_workflow_dispatcher_coverage`) already returns both classes — no helper change needed. This is a pure render-layer slice.

## Acceptance Criteria

### Agent

**1. Template — provider column**
- [x] `web/templates/orchestrator.html` workflow coverage table has a 4th column header `provider` between `worker_kind` and `Routable`.
- [x] Each row renders `workflow.provider` when set, `—` when empty.
- [x] When `workflow.worker_kind == "pi"` AND `workflow.provider` is empty, the cell carries a visible warn marker (e.g. `<span class="badge-warn">missing</span>` or equivalent — must be distinguishable from a normal empty cell).

**2. Template — missing-provider footer**
- [x] When `workflow_coverage.pi_workflows_missing_provider` is non-empty, a footer line renders listing the workflow names. Format mirrors the existing `Declarable but unroutable` line.
- [x] When empty, no orphan label appears.

**3. Template — status badge respects both classes**
- [x] The OK/FAIL badge derives from `workflow_coverage.ok` directly (not from `unroutable_workflows` length). A pi workflow with missing provider but no unroutable workflows produces FAIL.

**4. Tests**
- [x] New test `test_panel_renders_provider_column` — pi workflow with provider renders the value; non-pi workflow renders `—`.
- [x] New test `test_panel_flags_pi_missing_provider` — pi workflow without provider produces FAIL badge AND a footer line containing the workflow name AND a row marker (warn class or text).
- [x] Existing tests in `tests/unit/test_orchestrator_workflow_coverage.py` remain green (6 → ≥8 total).

**5. Verification**
- [x] `python3 -m pytest tests/unit/test_orchestrator_workflow_coverage.py -v` exits 0.
- [x] `curl -sf "$(bin/fw watchtower url)/orchestrator" | grep -q "provider"` — live page contains the new column header.

### Human

- [ ] [REVIEW] Visual rhythm: the new `provider` column and missing-provider footer don't break the panel layout.
      **Steps:**
      1. Open `http://192.168.10.107:3000/orchestrator` in a browser.
      2. Scroll to the Workflow coverage panel.
      3. Confirm the table has 4 columns (Workflow / worker_kind / provider / Routable) and that pi rows show a provider value (e.g. `anthropic`).
      4. If a pi-missing-provider workflow exists in the live data, confirm the footer line lists it and the row carries a warn marker.
      **Expected:** Four columns stack cleanly, no horizontal overflow. Pi rows render provider; non-pi rows show `—`. Footer line surfaces missing-provider names when applicable.
      **If not:** Screenshot the broken layout and note the workflow names.

## Verification

python3 -m pytest tests/unit/test_orchestrator_workflow_coverage.py -v
curl -sf "$(bin/fw watchtower url)/orchestrator" | grep -q "provider"

## RCA

## Recommendation

**Recommendation:** GO — closes the visibility parity gap for T-1800's failure class.

**Rationale:** T-1799 surfaced T-1798's *unroutable worker_kind* class on the web; T-1800 added a *missing provider* class to the same audit helper but never reached the web template. Before this slice, an operator looking at `/orchestrator` saw `OK` even when `fw audit` would FAIL on a pi workflow without a provider (the FAIL message only mentioned unroutable, and the table had no provider column). The helper (`lib/workflow_coverage.check_workflow_dispatcher_coverage`) already returned both classes — pure render-layer slice. Status badge now derives from `report["ok"]` directly (ANDs both classes inside the helper), the table has a 4th `provider` column (em-dash for non-pi, value when set, `missing` warn badge when pi-without-provider), and a new footer line surfaces names when applicable.

**Evidence:**
- `web/templates/orchestrator.html:380-446` — Workflow coverage panel: provider column added, FAIL message mentions both classes, missing-provider footer surfaces names when applicable.
- `tests/unit/test_orchestrator_workflow_coverage.py` — 2 new tests (provider column, missing-provider flagging). 8/8 green.
- `tests/playwright/test_orchestrator_page.py` — new `TestWorkflowCoveragePanel` class with 3 browser-level tests (heading, 4-column header, per-row provider rendering). 10/10 green.
- Live render confirmed: `curl … | grep -c "<th>provider</th>"` → 1; "and pi workflows declare a provider" in OK message; pi rows show `anthropic`.
- Regression: 38/38 across `test_orchestrator_workflow_coverage` + `test_workflow_coverage` + `test_orchestrator_routes`.

**Headline mechanic:** Open `/orchestrator` → Workflow coverage panel → 4-column table → for any pi workflow without a provider field, the row carries a visible `missing` badge AND the footer lists the workflow name AND the status badge flips to FAIL.

## Evolution

### 2026-05-13 — web parity for T-1800

- **What changed:** The slice was even thinner than expected — the helper already returned `pi_workflows_missing_provider` (T-1800), so the template just needed to consume it. No blueprint change at all; pure template + tests. The biggest decision was per-row warn marker design — went with `<span class="badge-warn">missing</span>` to match the existing `<span class="badge-warn">no</span>` for unroutable, so visual language stays consistent. Em-dash for non-pi empty cells (matches the existing `— (interactive)` pattern in the worker_kind column).
- **Plan impact:** The Workflow coverage panel now mirrors the full audit helper surface — both failure classes visible, both with row-level markers and footer summaries. The substrate observability quartet on `/orchestrator` is complete: Dispatch substrate → Outcome quality → Workflow coverage (both classes) → Learned routing. T-1799's Evolution section named this as a follow-up; T-1800's Evolution section named it as the natural next slice. Closed.
- **Triggered:** None autonomously. Natural follow-ups remain (named in T-1799 Evolution): per-workflow last-dispatch timestamp on this panel (operator can see "wf-task hasn't fired in 30 days" → maybe deprecate).

## Decisions

## Updates

### 2026-05-13T06:25:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1801-extend-workflow-coverage-panel-with-miss.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-088e2a0b
- **Timestamp:** 2026-05-18T09:30:55Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `web/templates/orchestrator.html` workflow coverage table has a 4th column header `provider` between `worker_kind` and `Routable`.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/orchestrator.html in: `web/templates/orchestrator.html` workflow coverage table has a 4th column header `provider` between `worker_kind` and `Routable`.`
### 2026-05-13T06:29:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
