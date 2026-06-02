---
id: T-1798
name: "workflow-dispatcher coverage check — fw audit flags worker_kind declarations without a spawn handler (T-1776 prevention)"
description: >
  workflow-dispatcher coverage check — fw audit flags worker_kind declarations without a spawn handler (T-1776 prevention)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [audit, prevention, contract-gap]
components: [C-004, lib/workflow_coverage.py, tests/unit/test_workflow_coverage.py]
related_tasks: [T-1776, T-1797]
arc_id: orchestrator-rethink
created: 2026-05-13T00:00:00Z
last_update: 2026-05-12T22:07:37Z
date_finished: 2026-05-12T22:07:37Z
---

# T-1798: workflow-dispatcher coverage check — fw audit flags worker_kind declarations without a spawn handler (T-1776 prevention)

## Context

T-1776 was discovered at *runtime* — someone tried to run the default fallback
path and hit `NotImplementedError`. That class of contract gap (workflow
declares `worker_kind: X` but spawn driver has no handler for X) should be
caught at *audit time*, not when a real dispatch fires.

**The structural shape:**
- Workflows live at `.context/project/workflows/*.yaml`; many declare
  `worker_kind: pi|ollama-loop|TermLink|Task` (free-form within
  `VALID_WORKER_KINDS` per `lib/resolver.py`).
- The spawn driver routes via `lib/spawn._DISPATCHERS` — a dict whose keys
  are the *actually-routable* subset.
- The gap: `VALID_WORKER_KINDS - _DISPATCHERS.keys()` is a non-empty
  declarable-but-unroutable set. Any workflow declaring a key from that set
  is a runtime trap.

**This task adds an audit check** that:
1. Scans all `.context/project/workflows/*.yaml` for `worker_kind` declarations
2. Imports `lib.spawn` to read the routable set
3. Reports any workflow whose worker_kind is unroutable as an audit FAIL
4. Surfaces "currently declarable-but-unroutable" set for visibility

Antifragility: T-1776 hit at runtime → T-1797 routed it → T-1798 prevents
the next instance from ever reaching runtime.

## Acceptance Criteria

### Agent

**1. Coverage helper**
- [x] `lib/workflow_coverage.py` exports `check_workflow_dispatcher_coverage()`
      returning `{"workflows": [...], "unroutable_workflows": [...],
      "declarable_but_unroutable": [...], "ok": bool}`.
- [x] Graceful on missing workflows directory or unparseable YAML files
      (returns ok=True with empty lists rather than crashing the audit).

**2. Audit wiring**
- [x] `agents/audit/audit.sh` orchestrator section calls the coverage helper
      and emits PASS/FAIL based on the result.
- [x] FAIL when any workflow declares an unroutable worker_kind, with the
      offending workflow name + worker_kind in the mitigation hint.

**3. Tests**
- [x] `tests/unit/test_workflow_coverage.py` covers:
      - all-routable case → ok=True, empty unroutable lists
      - unroutable workflow → ok=False, workflow appears in unroutable_workflows
      - missing workflows dir → ok=True, empty results
      - malformed YAML → graceful skip, not crash
      - workflow without worker_kind → counted as workflow but not unroutable

**4. Verification**
- [x] `python3 -m pytest tests/unit/test_workflow_coverage.py -v` exits 0
- [x] Current state passes: all 5 worker_kind-declaring workflows route to
      registered dispatchers (after T-1797).

### Human

(none — this is an internal audit check; verification is mechanical)

## Verification

python3 -m pytest tests/unit/test_workflow_coverage.py -v
python3 -c "import sys; sys.path.insert(0, 'lib'); import workflow_coverage; r = workflow_coverage.check_workflow_dispatcher_coverage(); assert r['ok'], f'unroutable: {r[\"unroutable_workflows\"]}'"

## Recommendation

**Recommendation:** GO — convert runtime trap to audit-time visibility.

**Rationale:** T-1776 was discovered at runtime ("dispatch crashed with NotImplementedError"). T-1797 routed the missing case. T-1798 prevents the next instance: `fw audit -s orchestrator` now cross-references every workflow's `worker_kind` against `lib/spawn._DISPATCHERS.keys()` and FAILs if any declared worker_kind has no handler. The helper is decoupled from audit.sh (pure Python returning structured output) so unit tests pin behavior independently of the shell driver. Current state: 8 workflows audited, all routable (PASS). Declarable-but-unroutable set: `{Task}` — surfaced for visibility but not flagged (no workflow declares it).

**Evidence:**
- `lib/workflow_coverage.py` — pure helper; `check_workflow_dispatcher_coverage()` returns ok/workflows/unroutable_workflows/declarable_but_unroutable; graceful on missing dir, malformed YAML, non-dict YAML root, missing PyYAML.
- `agents/audit/audit.sh` orchestrator section — emits `[PASS]`/`[FAIL]` based on helper output. Tested live: `[PASS] Workflow dispatcher coverage: all 8 workflows route to a registered dispatcher; declarable-but-unroutable: ['Task']`.
- `tests/unit/test_workflow_coverage.py` — 10 tests (all-routable, no-worker_kind, unroutable Task, garbage worker_kind, missing dir, malformed YAML, non-dict root, declarable_but_unroutable invariant, format_audit_line pass/fail).
- Verification gate: `python3 -m pytest tests/unit/test_workflow_coverage.py -v` → 10/10 passed.
- Live audit: `bash agents/audit/audit.sh -s orchestrator` exits 0 with the new PASS line and no audit fails.

**Headline mechanic:** Cron audit (`fw audit`, runs every 15 min) now prints `[PASS] Workflow dispatcher coverage: all N workflows route to a registered dispatcher`. If anyone declares an unroutable worker_kind in a workflow, the next audit cycle FAILs with the workflow name + bad worker_kind in the mitigation hint — before any dispatch ever fires.

## Evolution

### 2026-05-13 — T-1776 prevention landed

- **What changed:** The check turned out to be a clean two-set comparison: `VALID_WORKER_KINDS - _DISPATCHERS.keys()` is the "declarable but unroutable" surface, and workflows mentioning anything in that set are runtime traps. Today the surface is just `{Task}`; if a future arc adds a new worker_kind to VALID before wiring its dispatcher, the audit will surface the gap on the very next cycle.
- **Plan impact:** The orchestrator arc's substrate-coverage trio is now: T-1776 (discovery filing) → T-1797 (route the existing case) → T-1798 (prevent the next case). With this slice, the resolver→spawn coverage matrix is structurally guarded — adding worker_kinds without handlers is a visible audit failure, not a latent runtime trap.
- **Triggered:** None autonomously. Natural follow-up if the arc continues: same coverage shape for `provider` (pi-specific subfield), where a workflow declaring an unrouted provider would hit `SpawnError` at runtime.

## Decisions

## Updates

### 2026-05-13T00:00:00Z — task-created
- **Action:** Created task
- **Context:** T-1776 prevention slice — convert runtime trap to audit-time visibility

## Reviewer Verdict (v1.5)

- **Scan ID:** R-339c071e
- **Timestamp:** 2026-06-02T14:59:46Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — `agents/audit/audit.sh` orchestrator section calls the coverage helper
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/audit/audit.sh in: `agents/audit/audit.sh` orchestrator section calls the coverage helper`
### 2026-05-12T22:07:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
