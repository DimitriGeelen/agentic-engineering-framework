---
id: T-1800
name: "provider-coverage check — extend workflow_coverage to flag pi workflows missing
  provider field (T-1798 sibling gap)"
description: >
  provider-coverage check — extend workflow_coverage to flag pi workflows missing
  provider field (T-1798 sibling gap)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [audit, prevention, contract-gap]
components: [lib/workflow_coverage.py, 
      tests/unit/test_orchestrator_workflow_coverage.py, 
      tests/unit/test_workflow_coverage.py]
related_tasks: [T-1798, T-1797, T-1776]
arc_id: orchestrator-rethink
created: 2026-05-13T00:00:00Z
last_update: '2026-08-16T22:24:45Z'
date_finished: 2026-05-12T22:16:29Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1800: provider-coverage check — extend workflow_coverage to flag pi workflows missing provider field (T-1798 sibling gap)

## Context

T-1798 closed the worker_kind coverage gap (workflow declares `worker_kind: X`
without a spawn handler → audit FAIL). T-1800 closes the sibling gap on the
`provider` field:

```python
# lib/spawn.py:_spawn_pi
provider = envelope.get("provider") or _provider_from_workflow(envelope)
if not provider:
    raise SpawnError("pi route requires `provider` field; not in envelope "
                     "and not in workflow file for task_type={...}")
```

Any workflow declaring `worker_kind: pi` MUST also declare `provider: X`
(e.g. `anthropic`, `openai`, `huggingface`). Missing → SpawnError at runtime.
Same antifragility shape as T-1776/T-1798: audit-time detection of a
runtime-trap class.

Same approach as T-1798: extend `lib.workflow_coverage` to surface
`missing_provider_for_pi_workflows`; audit FAILs if any; web panel
extends with a footer note.

## Acceptance Criteria

### Agent

**1. Helper extension**
- [x] `lib/workflow_coverage.py:check_workflow_dispatcher_coverage()`
      returns an additional field `pi_workflows_missing_provider`:
      list of `{name, worker_kind: "pi"}` for any pi workflow lacking
      a `provider` field.
- [x] `report["ok"]` becomes False when either `unroutable_workflows`
      OR `pi_workflows_missing_provider` is non-empty.
- [x] `format_audit_line` mentions the missing-provider count when present.

**2. Audit consequence**
- [x] Audit FAIL surfaces both classes (unroutable workflow + pi-missing-
      provider) with the offending workflow name + which class.

**3. Tests**
- [x] `tests/unit/test_workflow_coverage.py` extends with:
      - pi workflow with provider → ok=True
      - pi workflow without provider → flagged in pi_workflows_missing_provider, ok=False
      - non-pi workflow without provider → not flagged (provider is pi-specific)
      - format_audit_line surfaces the missing-provider count

**4. Verification**
- [x] `python3 -m pytest tests/unit/test_workflow_coverage.py -v` exits 0
- [x] Live audit: `bash agents/audit/audit.sh -s orchestrator` still PASS
      (current workflows: cheap-research declares worker_kind: pi — confirm
      it also declares a provider).

### Human

(none — internal audit check)

## Verification

python3 -m pytest tests/unit/test_workflow_coverage.py -v
PROJECT_ROOT=$(pwd) python3 -c "import sys; sys.path.insert(0, 'lib'); import workflow_coverage; r = workflow_coverage.check_workflow_dispatcher_coverage(); assert r['ok'], f'failures: {r}'; assert 'pi_workflows_missing_provider' in r"

## Recommendation

**Recommendation:** GO — closes the sibling runtime-trap class (pi without provider).

**Rationale:** T-1798 closed half of the audit-time-prevention story (workflow declares worker_kind without handler). This slice closes the other half: a workflow declaring `worker_kind: pi` without a `provider:` field raises `SpawnError` at runtime (`lib/spawn._spawn_pi`). Same antifragility shape, same audit hook, minimal diff. The helper's return shape gains one field (`pi_workflows_missing_provider`); `report["ok"]` is AND-of-both-classes; the audit line surfaces both classes in a `;`-joined summary when present.

**Evidence:**
- `lib/workflow_coverage.py` — `_parse_workflows` now also reads `provider`; helper returns `pi_workflows_missing_provider`; `format_audit_line` surfaces both classes.
- `tests/unit/test_workflow_coverage.py` — extends from 10 → 15 tests (5 new for provider coverage: pi with provider OK, pi without provider FAIL, non-pi without provider unaffected, audit-line surfaces missing-provider, audit-line combines both classes).
- `tests/unit/test_orchestrator_workflow_coverage.py` — backfilled to pass provider= where pi workflows are written; 6/6 still green.
- Verification gate: `python3 -m pytest tests/unit/test_workflow_coverage.py tests/unit/test_orchestrator_workflow_coverage.py -v` → 21/21 passed.
- Live audit line: `all 8 workflows route to a registered dispatcher and pi workflows declare a provider; declarable-but-unroutable: ['Task']`.

**Headline mechanic:** `fw audit -s orchestrator` now FAILs on both classes of runtime-trap: (a) unroutable worker_kind, (b) pi worker without provider. The audit cron picks both up daily; web `/orchestrator` panel reflects via the same payload.

## Evolution

### 2026-05-13 — sibling gap closed; antifragility pattern proven

- **What changed:** The helper's existing structure absorbed this slice for free — `_parse_workflows` returns a per-workflow dict rather than a string; check function adds one list + one `and` in the `ok` predicate; `format_audit_line` becomes a `;`-joined parts list. Pattern: the helper is a register of structural traps; each new trap class is a new field + a few lines of detection. Future-similar (e.g. `model:` required when route_cache is consulted, `env:` required for ollama-loop) can land via the same pattern without growing the helper's interface.
- **Plan impact:** With T-1797 (route the existing gap) + T-1798 (audit-detect unroutable worker_kind) + T-1800 (audit-detect pi missing provider), the resolver→spawn substrate's runtime-trap surface is structurally covered for everything currently declarable in workflows. The web view (T-1799) surfaces the unroutable class; a follow-up slice could extend that panel with the missing-provider class — not urgent, since `fw audit` catches it daily and `/orchestrator` would only show it if a workflow regressed.
- **Triggered:** None autonomously. Natural follow-up: extend T-1799's web panel with the missing-provider class for full visibility parity.

## Decisions

## Updates

### 2026-05-13T00:00:00Z — task-created
- **Action:** Created task
- **Context:** Sibling gap to T-1798 — same antifragility shape on the provider field

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3be09df7
- **Timestamp:** 2026-06-02T14:59:47Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#7 (Agent)** — Live audit: `bash agents/audit/audit.sh -s orchestrator` still PASS
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/audit/audit.sh in: Live audit: `bash agents/audit/audit.sh -s orchestrator` still PASS`
### 2026-05-12T22:16:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
