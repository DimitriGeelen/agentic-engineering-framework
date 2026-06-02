---
id: T-1788
name: "fw orchestrator status: surface model — by_model breakdown + recent-line model="
description: >
  fw orchestrator status: surface model — by_model breakdown + recent-line model=

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [cli, observability]
components: []
related_tasks: [T-1664, T-1699, T-1779]
arc_id: orchestrator-rethink
created: 2026-05-11T11:18:00Z
last_update: 2026-05-11T11:13:06Z
date_finished: 2026-05-11T11:13:06Z
---

# T-1788: fw orchestrator status — surface the model (routing decision)

## Context

The orchestrator-rethink arc's headline mechanic is:

> agent dispatches a task without specifying a model → orchestrator picks
> the model based on task_type and historical success rates → user observes
> **the routing decision** live on /orchestrator

`fw orchestrator status` today breaks down by `task_type`, `worker_kind`,
and `terminal_event` — but never surfaces `model`, which is literally
the routing decision being made. The field IS captured per dispatch
(T-1664) and present in every recent row's JSON, but the CLI display
ignores it.

This slice:
1. Adds a `By model:` breakdown section (mirrors `By worker_kind`).
2. Appends `model=<X>` to each Recent dispatches line (after worker).
3. Adds `by_model` dict to the JSON output for tooling.

Mirrors existing breakdown patterns exactly — no new infrastructure.

## Acceptance Criteria

### Agent

**1. by_model breakdown**
- [x] Status output includes a `By model:` section, mirror of `By worker_kind`.
- [x] Section omitted when no dispatch carries a `model` field (legacy data).
- [x] JSON output includes `by_model` dict (Counter shape, mirror of `by_worker_kind`).

**2. Recent-line surface**
- [x] Each row in the Recent dispatches block shows `model=<X>` after `worker=<Y>`.
- [x] When `model` is missing, render `model=?` (consistent with worker_kind "?" fallback).
- [x] JSON `stats["recent"]` rows include `model` key (None when absent).

**3. Composition**
- [x] `by_model` reflects all active filters (--task, --worker-kind, --since).
- [x] No regression: existing breakdowns and recent block unchanged.

**4. Tests**
- [x] `tests/unit/test_orchestrator_status_terminal_events.py` extends with:
      - by_model section rendered when model present
      - by_model section omitted when no model field
      - recent-line shows model=<X>
      - recent-line shows model=? when missing
      - by_model respects --worker-kind filter
      - JSON exposes by_model key
- [x] `python3 -m pytest tests/unit/test_orchestrator_status_terminal_events.py -v` exits 0.

### Human

(Mechanical / deterministic — no Human ACs.)

## Verification

python3 -m pytest tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_status_outcomes.py -v

## Recommendation

**Recommendation:** GO — surfaces the arc's headline mechanic (the routing decision).

**Rationale:** The arc demo is "user observes routing decision live". Today the CLI substrate-surface shows everything BUT the model — the substrate captures it (T-1664), the JSONL persists it, but `fw orchestrator status` never prints it. Operator who runs the command and asks "what model did the orchestrator pick?" gets no answer without a separate `jq`. With this slice, `By model:` and `model=<X>` in the recent block close that gap. Each dispatch's routing decision becomes visible at a glance, and as workflows declare different models, the breakdown shows the substrate's actual routing distribution.

**Evidence:**
- `bin/fw` orchestrator status heredoc — `by_model` Counter, render block mirror of `by_worker_kind`; recent-line appended `model=`.
- `tests/unit/test_orchestrator_status_terminal_events.py` — 6 new T-1788 tests.
- Combined regression: arc-suite green.

**Headline mechanic:** `bin/fw orchestrator status` now shows `By model:` and `model=<X>` per recent dispatch — the routing decision is finally visible on the same surface as the workload it routed.

## Evolution

### 2026-05-11 — closing the substrate-vs-display gap

- **What changed:** Re-reading the arc's headline mechanic — "user observes the routing decision live" — exposed a §ACD-shaped gap. The model field has been captured per dispatch since T-1664, but no observation surface displays it. The substrate had the data, the demo claim assumed it was visible, but the agent never wired the surface. Classic substrate-vs-deliverable conflation, caught one slice at a time.
- **Plan impact:** No new infrastructure. Mirror by_worker_kind exactly: Counter, render block, JSON key. Recent-line appends `model=<X>` after `worker=<Y>` in the same printf.
- **Triggered:** None — but watch for similar substrate-vs-surface gaps (e.g. effort, prompt_template_sha, workflow_resolved_via — all captured, all unsurfaced).

## Decisions

## Updates

### 2026-05-11T11:18:00Z — task-created
- **Action:** Created task; arc-tagged orchestrator-rethink
- **Context:** Surface routing decision (model) on the same CLI surface that already shows workload breakdowns

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6bc16fa2
- **Timestamp:** 2026-06-02T14:59:44Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-11T11:13:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
