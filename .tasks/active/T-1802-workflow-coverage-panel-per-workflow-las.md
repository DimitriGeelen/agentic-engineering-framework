---
id: T-1802
name: "Workflow coverage panel: per-workflow last-dispatch timestamp — surface deprecation
  candidates (T-1799 follow-up)"
description: >
  Workflow coverage panel: per-workflow last-dispatch timestamp — surface deprecation
  candidates (T-1799 follow-up)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [web, observability]
components: [lib/workflow_coverage.py, 
      tests/unit/test_orchestrator_workflow_coverage.py, 
      tests/unit/test_workflow_coverage.py, web/blueprints/orchestrator.py, 
      web/templates/orchestrator.html]
related_tasks: [T-1776, T-1797, T-1798, T-1799, T-1800, T-1801]
arc_id: orchestrator-rethink
created: 2026-05-13T06:35:00Z
last_update: '2026-05-28T22:54:09Z'
date_finished: 2026-05-13T06:35:51Z
bvp_scores_proposed:
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 2
      D3: 3
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1802: Workflow coverage panel: per-workflow last-dispatch timestamp — surface deprecation candidates (T-1799 follow-up)

## Context

T-1799 Evolution named this as a follow-up: *"per-workflow last-dispatch timestamp on this panel (operator can see 'wf-task hasn't fired in 30 days' → maybe deprecate)"*. The current state of the live substrate proves the point — 5 of 8 declared workflows have never dispatched (`cheap-research`, `design-dialogue`, `grilling`, `inception`, `ollama-research`). Without this surface, an operator looking at `/orchestrator` cannot tell live workflows from declared-but-dead ones.

This slice joins `.context/dispatches.jsonl` (per-dispatch records with `workflow_id` + `ts`) to the Workflow coverage report at render time:

- **Helper:** add pure function `enrich_with_dispatch_recency(report, dispatches_path=None)` to `lib/workflow_coverage.py`. Takes a coverage report dict, returns a copy with each workflow row gaining `last_dispatched: ISO8601 | None` and `last_dispatch_task_id: str | None`. Pure: easy to test with fixture JSONL.
- **Template:** 5th column `Last dispatched` in the Workflow coverage table. Renders ISO date when set, `never` (muted) when None. Links to last dispatch task when known.
- **Web blueprint:** `_workflow_coverage()` calls `enrich_with_dispatch_recency` after `check_workflow_dispatcher_coverage`. Graceful when `dispatches.jsonl` missing.

Out of scope for this slice (named follow-ups, not blocking):
- Audit-time warn when workflow declared but never fired in 90 days (would be a 5th audit class).
- Deprecation workflow / removal proposal — surfaces the candidates, doesn't act on them.

## Acceptance Criteria

### Agent

**1. Helper — enrich_with_dispatch_recency**
- [x] `lib/workflow_coverage.py` exports `enrich_with_dispatch_recency(report, dispatches_path=None)`.
- [x] Reads `.context/dispatches.jsonl` (or supplied path), parses each line as JSON, groups by `workflow_id`, takes max `ts` per workflow.
- [x] Returns a NEW report dict (does not mutate input) with each `workflows[i]` row gaining `last_dispatched` (str ISO8601 or None) and `last_dispatch_task_id` (str or None).
- [x] Graceful when path missing → returns report unchanged (last_dispatched=None for every row).
- [x] Graceful when JSONL has malformed lines → skips them (matches existing helper pattern).

**2. Web blueprint integration**
- [x] `web/blueprints/orchestrator.py:_workflow_coverage()` calls `enrich_with_dispatch_recency(report)` after `check_workflow_dispatcher_coverage()`. If the enrich helper raises, the call is wrapped in try/except so the panel still renders (degrade gracefully).

**3. Template — Last dispatched column**
- [x] 5th column header `Last dispatched` after `Routable`.
- [x] When `w.last_dispatched` set: cell shows ISO date (YYYY-MM-DD). The `last_dispatch_task_id` is rendered as a link to `/tasks/T-XXX` if present.
- [x] When `w.last_dispatched` is None: cell shows `<span class="muted">never</span>`.

**4. Tests — helper**
- [x] `tests/unit/test_workflow_coverage.py` gains tests:
      - `test_enrich_with_dispatch_recency_basic` — fixture JSONL with 2 dispatches across 2 workflows → max ts per workflow surfaces.
      - `test_enrich_with_dispatch_recency_missing_path` — non-existent path → report returned with last_dispatched=None on every row.
      - `test_enrich_with_dispatch_recency_malformed_jsonl_skipped` — JSONL with a garbage line + good lines → garbage skipped, goods counted.
      - `test_enrich_with_dispatch_recency_does_not_mutate_input` — input report's workflows still lack `last_dispatched` after call.

**5. Tests — template integration**
- [x] `tests/unit/test_orchestrator_workflow_coverage.py` gains:
      - `test_panel_renders_last_dispatched_column` — fixture with dispatched workflow shows date; never-dispatched shows `never`.

**6. Verification**
- [x] `python3 -m pytest tests/unit/test_workflow_coverage.py tests/unit/test_orchestrator_workflow_coverage.py -v` exits 0.
- [x] `curl -sf "$(bin/fw watchtower url)/orchestrator" | grep -q "Last dispatched"` — live page contains the new column header.

### Human

- [ ] [REVIEW] Deprecation signal usefulness: scan the `Last dispatched` column on `/orchestrator` and confirm the panel surfaces the deprecation candidates without ambiguity.
      **Steps:**
      1. Open `http://192.168.10.107:3000/orchestrator` in a browser.
      2. Scroll to the Workflow coverage panel.
      3. Confirm `default`, `escalation-triage`, `prompt-triage` rows show a date.
      4. Confirm `cheap-research`, `design-dialogue`, `grilling`, `inception`, `ollama-research` rows show `never`.
      **Expected:** Five-column table reads left-to-right as "what is it / what kind / what auth / can it route / when did it last run". `never` cells visually distinguishable from missing-provider/unroutable warnings.
      **If not:** Screenshot + note which row reads ambiguously.

## Verification

python3 -m pytest tests/unit/test_workflow_coverage.py tests/unit/test_orchestrator_workflow_coverage.py -v
curl -sf "$(bin/fw watchtower url)/orchestrator" | grep -q "Last dispatched"

## RCA

## Recommendation

**Recommendation:** GO — surfaces 5 deprecation candidates that were invisible from the web before this slice.

**Rationale:** The Workflow coverage panel told operators *what could route*, not *what was actually being used*. Live data proves the point — 8 workflows declared, 5 never dispatched (`cheap-research`, `design-dialogue`, `grilling`, `inception`, `ollama-research`). Before this slice, those were indistinguishable from active workflows on `/orchestrator`; an operator would have to drop into CLI `fw orchestrator status --recent N` to find them. Now the 5th column reads "Last dispatched" with ISO date + task link for fired workflows, `never` (muted) for dead ones — at-a-glance deprecation candidate detection.

Pure helper extension (`enrich_with_dispatch_recency`) keeps the audit-time check fast (audit doesn't read dispatches.jsonl). Web blueprint joins at render time with a try/except shield so dispatch-side issues never kill the coverage panel.

**Evidence:**
- `lib/workflow_coverage.py:enrich_with_dispatch_recency()` — pure: returns deep copy, never mutates input, graceful on missing path / malformed JSONL.
- `web/blueprints/orchestrator.py:_workflow_coverage()` — calls enrich after coverage check, wrapped in try/except for resilience.
- `web/templates/orchestrator.html:380-462` — 5th column `Last dispatched`; renders ISO date + linked task ID OR `<span class="muted">never</span>`.
- `tests/unit/test_workflow_coverage.py` — 4 new tests (basic, missing-path, malformed-jsonl, no-mutation). 19/19 green.
- `tests/unit/test_orchestrator_workflow_coverage.py` — 1 new test (renders Last dispatched column). 9/9 green.
- Regression: 53/53 across orchestrator unit + playwright suite.
- Live render confirmed: `default` → 2026-05-03 → T-1698; `escalation-triage` → 2026-05-05 → T-1120; `prompt-triage` → 2026-05-05 → T-1738; 5 dead workflows → `never`.

**Headline mechanic:** Open `/orchestrator` → Workflow coverage panel → scan the 5th column → instantly see which workflows are dead (deprecation candidates) without dropping into CLI.

## Evolution

### 2026-05-13 — per-workflow recency on Workflow coverage panel

- **What changed:** Helper extension stayed pure by design — `enrich_with_dispatch_recency` takes a report and returns an enriched copy with `copy.deepcopy`, so callers (including the in-progress unit tests) can't accidentally mutate the input through the helper. The "graceful on path missing" branch matters more than it looks: a fresh consumer project has no `dispatches.jsonl`, and without this guard the entire `/orchestrator` panel would crash on first render. Try/except in the blueprint is belt-and-braces.
- **Plan impact:** The Workflow coverage panel is now 5-column and tells a complete story: identity (Workflow) → kind (worker_kind) → auth (provider) → routability (Routable) → liveness (Last dispatched). Each column answers one question an operator would otherwise have to script. The substrate observability quartet on `/orchestrator` is now Dispatch substrate → Outcome quality → Workflow coverage (5 columns, 2 failure classes + liveness) → Learned routing.
- **Triggered:** Named follow-up from T-1799 + T-1801 Evolution sections; surfaced 5 deprecation candidates in the live substrate. Out-of-scope follow-ups remain: (a) audit-time warn for workflows declared but never fired in 90 days (5th audit class — would push coverage to FAIL on stale workflows); (b) deprecation workflow / removal proposal (surfaces them, doesn't act).

## Decisions

## Updates

### 2026-05-13T06:35:00Z — task-created
- **Action:** Created task
- **Context:** Natural follow-up named in T-1799 Evolution + T-1801 Evolution; 5 of 8 declared workflows never dispatched on the live substrate.

## Reviewer Verdict (v1.4)

- **Scan ID:** R-5ddaeb93
- **Timestamp:** 2026-05-18T09:30:56Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#2 (Agent)** — Reads `.context/dispatches.jsonl` (or supplied path), parses each line as JSON, groups by `workflow_id`, takes max `ts` per workflow.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/dispatches.jsonl in: Reads `.context/dispatches.jsonl` (or supplied path), parses each line as JSON, groups by `workflow_id`, takes max `ts` per workflow.`
- **AC#6 (Agent)** — `web/blueprints/orchestrator.py:_workflow_coverage()` calls `enrich_with_dispatch_recency(report)` after `check_workflow_dispatcher_coverage()`. If the enrich helper raises, the call is wrapped in try
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/orchestrator.py in: `web/blueprints/orchestrator.py:_workflow_coverage()` calls `enrich_with_dispatch_recency(report)` after `check_workflow_dispatcher_coverage()`. If th`

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `python3 -m pytest tests/unit/test_workflow_coverage.py tests/unit/test_orchestrator_workflow_coverage.py -v`
### 2026-05-13T06:35:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
