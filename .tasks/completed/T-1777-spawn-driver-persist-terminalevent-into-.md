---
id: T-1777
name: "spawn driver: persist terminal_event into dispatches.jsonl outcome row for
  one-shot forensics"
description: >
  spawn driver: persist terminal_event into dispatches.jsonl outcome row for one-shot
  forensics

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [spawn, observability]
components: [bin/fw, lib/outcome.py, lib/resolver.py, lib/spawn.py, 
      tests/unit/test_orchestrator_status_terminal_events.py, 
      tests/unit/test_outcome.py, tests/unit/test_resolver_run.py, 
      tests/unit/test_spawn.py]
related_tasks: [T-1773, T-1775]
arc_id: orchestrator-rethink
created: 2026-05-09T21:25:53Z
last_update: '2026-08-16T22:24:44Z'
date_finished: 2026-05-13T21:09:52Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:44Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1777: spawn driver: persist terminal_event into dispatches.jsonl outcome row for one-shot forensics

## Context

T-1773 spawn driver currently writes only `outcome` + `events_count` into
the dispatches.jsonl row. To inspect the terminal event (for ollama-loop:
`{"type":"result", "is_error":bool, "result":"..."}`; for pi:
`{"type":"agent.done"}` or `{"type":"error", "retryable":bool}`), callers
must open the events.jsonl blob and tail-read.

`fw outcome read` is the one-shot forensics tool. It currently joins
dispatches.jsonl + dispatch-outcomes.jsonl. Adding `terminal_event` to the
dispatch row makes "what happened, in one sentence" available without a
second file open. For ollama-loop this includes the model's `result` text
(short generation summary); for pi this includes retryable flag for failed
runs.

One-line change in `spawn_dispatch`: pass `terminal_event` into the `extra`
dict given to `update_outcome_row`. The function already merges arbitrary
keys; no schema bump in `update_outcome_row` itself.

## Acceptance Criteria

### Agent

**1. spawn_dispatch persists terminal_event**
- [x] `lib/spawn.py:spawn_dispatch` adds `terminal_event` to the `extra` dict
      passed to `update_outcome_row` (alongside `events_count`). When the
      worker has no terminal event (timeout, crash mid-stream), the field is
      omitted (no null write).
- [x] Result row in dispatches.jsonl carries the merged data after `spawn_dispatch`
      completes — verified via the existing finalisation test path.

**2. Tests**
- [x] `tests/unit/test_spawn.py` adds:
      - pi route: terminal_event captured in dispatches row (`agent.done` shape)
      - ollama-loop route: terminal_event captured (`result` shape with `is_error`)
      - terminal_event omitted from row when None (e.g. early failure)
- [x] `python3 -m pytest tests/unit/test_spawn.py -v` exits 0 (19/19 pass; was 16, +3 T-1777 tests).

**3. No regression**
- [x] Existing 16 spawn tests still pass (all 19 now pass, the new 3 are additive).
- [x] `tests/unit/test_resolver_run.py` 7/7 pass (cmd_run prints terminal type unchanged).
- [x] `tests/unit/test_ollama_loop.py` 13/13 pass.

### Human

(All ACs are mechanical / deterministic — Agent-verifiable. No Human ACs needed.)

## Verification

# Run extended spawn tests + resolver_run regression
python3 -m pytest tests/unit/test_spawn.py tests/unit/test_resolver_run.py tests/unit/test_ollama_loop.py -v

## Recommendation

**Recommendation:** GO — single-line spawn change + 3 tests, no schema bump in update_outcome_row.

**Rationale:** `update_outcome_row` already accepts a generic `extra` dict; spawn_dispatch now passes `terminal_event` into it conditionally (omitted when None). The dispatches.jsonl row gains one optional field; readers that don't know about it ignore it. `fw outcome read` joining dispatches + dispatch-outcomes can now surface the terminal event in one open instead of two.

**Evidence:**
- `lib/spawn.py:spawn_dispatch` — extra dict gains `terminal_event` when present
- `tests/unit/test_spawn.py` — 19/19 pass (3 new T-1777 tests; 0 regressions)
- `tests/unit/test_resolver_run.py` — 7/7 pass (no contract drift in cmd_run)
- `tests/unit/test_ollama_loop.py` — 13/13 pass

**Headline mechanic:** dispatches.jsonl rows now carry `terminal_event` post-spawn; tail-read shows what terminated each dispatch without opening events.jsonl.

## Evolution

### 2026-05-09 — terminal_event omitted (not null) when absent

- **What changed:** First sketch wrote `terminal_event: null` for every row. Realized: makes every legacy row look schema-broken and wastes bytes on the common-success case where the terminal event is uninformative anyway. Switched to omit-when-None.
- **Plan impact:** One extra check (`if outcome.get("terminal_event") is not None`) before merging the field. Test added explicitly for the omit-on-None path.
- **Triggered:** No new task — pinned the contract via test.

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

## Updates

### 2026-05-09T21:25:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1777-spawn-driver-persist-terminalevent-into-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-86d67546
- **Timestamp:** 2026-06-02T14:59:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-13T21:09:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
