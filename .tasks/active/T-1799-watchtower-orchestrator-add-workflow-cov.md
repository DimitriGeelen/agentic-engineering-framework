---
id: T-1799
name: "Watchtower /orchestrator: add Workflow coverage panel — surface T-1798 audit
  check on web (matrix of workflow × worker_kind × routable)"
description: >
  Watchtower /orchestrator: add Workflow coverage panel — surface T-1798 audit check
  on web (matrix of workflow × worker_kind × routable)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [web, observability]
components: [tests/unit/test_orchestrator_workflow_coverage.py, 
      web/blueprints/orchestrator.py, web/templates/orchestrator.html]
related_tasks: [T-1776, T-1797, T-1798]
arc_id: orchestrator-rethink
created: 2026-05-12T22:08:26Z
last_update: '2026-08-16T22:23:59Z'
date_finished: 2026-05-12T22:11:39Z
bvp_scores_proposed:
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 4
      D3: 5
      D4: 0
      F1: 1
      F2: 0
    rationale: "D1=3 (body:test-or-audit-check); D2=4 (body:fw-audit-or-doctor); D3=5
      (body:new-collab-mode); D4=0 (no-signal); F1=1 (body/tag hits for 'F1': 1);
      F2=0 (no-signal)"
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 4
      D3: 5
      D4: 0
      F-RECALL: 0
      F-ORCH: 2
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=4 (body:fw-audit-or-doctor); 
      D3=5 (body:new-collab-mode); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-ORCH=2 (components:substrate-edit); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:23:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 4
      D3: 5
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=4 (body:fw-audit-or-doctor); 
      D3=5 (body:new-collab-mode); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1799: Watchtower /orchestrator: add Workflow coverage panel — surface T-1798 audit check on web (matrix of workflow × worker_kind × routable)

## Context

T-1798 added the audit-time check for workflow → dispatcher coverage. Today
the only surface is `fw audit` output (cron, daily). This slice surfaces
the same data on `/orchestrator` so operators can see the coverage matrix
at a glance — same antifragility move as T-1792..T-1796 (substrate
observability that was CLI-only → web).

Panel shape (mirrors prior orchestrator panels):
- Header: "Workflow coverage" + status badge (OK / FAIL based on
  `report["ok"]`)
- Table: rows per workflow (name, declared worker_kind, routable yes/no)
- Footer line: "Declarable but unroutable: {Task}" (visibility)

## Acceptance Criteria

### Agent

**1. Helper function**
- [x] `_workflow_coverage()` added to `web/blueprints/orchestrator.py`.
- [x] Wraps `lib.workflow_coverage.check_workflow_dispatcher_coverage()`,
      returns its dict directly. Graceful on import failure (returns
      `{"available": False}`).

**2. Template panel**
- [x] New `<h2>Workflow coverage</h2>` panel between Outcome quality and
      Learned routing.
- [x] Table columns: Workflow / worker_kind / Routable (yes/no badge).
- [x] Footer line shows `Declarable but unroutable: X` set.
- [x] Empty-state when helper unavailable.

**3. Tests**
- [x] `tests/unit/test_orchestrator_workflow_coverage.py` covers:
      - returns dict shape from helper
      - panel renders rows for each workflow
      - routable workflow gets badge-ok, unroutable gets badge-warn
      - empty-state when helper unavailable
      - declarable_but_unroutable footer line surfaces

**4. Verification**
- [x] `python3 -m pytest tests/unit/test_orchestrator_workflow_coverage.py -v` exits 0
- [x] Live render confirms panel appears at `/orchestrator` and shows
      current 8-workflow matrix.

### Human

- [ ] [REVIEW] Panel placement: Workflow coverage sits between Outcome
      quality and Learned routing without breaking the established rhythm.
      **Steps:**
      1. Open `http://localhost:3000/orchestrator` in a browser.
      2. Verify panel order: Dispatch substrate → Outcome quality →
         Workflow coverage → Learned routing.
      **Expected:** Four panels stack cleanly, consistent column rhythm.
      **If not:** Note rendering issue + screenshot.

## Verification

python3 -m pytest tests/unit/test_orchestrator_workflow_coverage.py -v

## Recommendation

**Recommendation:** GO — web parity for T-1798's audit-time visibility.

**Rationale:** T-1798 added the audit-time check; today it only surfaced via `fw audit` output (cron, daily). This slice mirrors the same data on `/orchestrator` so operators see the coverage matrix at a glance. Same antifragility move as T-1792..T-1796: substrate observability that was CLI-only → web-visible. The new panel sits between Outcome quality and Learned routing, completing the arc story top-down (Dispatch → Outcome → Coverage → Learned routing). Helper `_workflow_coverage()` is a thin facade over `lib.workflow_coverage.check_workflow_dispatcher_coverage`; graceful when not importable.

**Evidence:**
- `web/blueprints/orchestrator.py:_workflow_coverage()` — pure facade; graceful on import failure.
- `web/blueprints/orchestrator.py:orchestrator_page` — passes `workflow_coverage` payload to template.
- `web/templates/orchestrator.html` — new Workflow coverage panel: OK/FAIL header, per-workflow table with worker_kind + routable badge, footer line surfacing routable dispatchers + declarable-but-unroutable set.
- `tests/unit/test_orchestrator_workflow_coverage.py` — 6 tests (helper shape, unroutable flagging, panel renders, FAIL state, interactive-cell, declarable-but-unroutable footer).
- Arc-suite regression: 116/116 green (was 110/110).
- Live render confirmed: panel shows 8 workflows, "Routable dispatchers: TermLink, ollama-loop, pi", "Declarable but unroutable: Task".

**Headline mechanic:** Open `/orchestrator` → scroll past Outcome quality → see Workflow coverage panel → at a glance, which workflows route, which don't, and what the unroutable surface is.

## Evolution

### 2026-05-12 — web parity for T-1798

- **What changed:** The helper turned out to be a 17-line facade — `lib/workflow_coverage` already returns exactly the dict the template needs, so the web blueprint just imports + decorates with `available: True`. Empty-state and FAIL-state both render off the same payload (no separate code paths). The `lib/` symlink in the test fixture is the only test-infra wrinkle: web/shared.PROJECT_ROOT-resolving import wants to find the helper relative to the test's tmp project, so the fixture symlinks lib/ → REPO_ROOT/lib.
- **Plan impact:** The substrate observability story on `/orchestrator` is now four panels deep: Dispatch substrate (what got picked) → Outcome quality (did it work?) → Workflow coverage (could it have worked?) → Learned routing (what should win next?). The fourth panel was the missing prevention surface; it now closes the substrate-vs-display gap for T-1776's class of issue.
- **Triggered:** None autonomously. Natural follow-ups: (a) provider-coverage check (pi workflows declare a `provider` field; an unrouted provider raises SpawnError at runtime — same antifragility shape); (b) per-workflow last-dispatch timestamp on this panel (operator can see "wf-task hasn't fired in 30 days" → maybe deprecate).

## Decisions

## Updates

### 2026-05-12T22:08:26Z — task-created
- **Action:** Created task
- **Context:** T-1798 audit-check needed a web parity slice

## Reviewer Verdict (v1.4)

- **Scan ID:** R-58f15cf6
- **Timestamp:** 2026-05-18T09:30:55Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `_workflow_coverage()` added to `web/blueprints/orchestrator.py`.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/orchestrator.py in: `_workflow_coverage()` added to `web/blueprints/orchestrator.py`.`
### 2026-05-12T22:11:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
