---
id: T-1778
name: "fw resolver run/explain — surface terminal_event sub-fields (retryable, is_error)
  for one-look forensics"
description: >
  fw resolver run/explain — surface terminal_event sub-fields (retryable, is_error)
  for one-look forensics

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [cli, observability]
components: [lib/outcome.py, lib/resolver.py, tests/unit/test_outcome.py, 
      tests/unit/test_resolver_run.py]
related_tasks: [T-1774, T-1777]
arc_id: orchestrator-rethink
created: 2026-05-10T05:32:24Z
last_update: '2026-08-16T22:24:44Z'
date_finished: 2026-05-13T21:10:06Z
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

# T-1778: fw resolver run/explain — surface terminal_event sub-fields (retryable, is_error) for one-look forensics

## Context

T-1777 persists `terminal_event` into `dispatches.jsonl` rows, but the
human-facing CLI surfaces still only show `terminal: <type>`. For pi error
events the `retryable` flag is the most important detail (drives 429
backoff decisions); for ollama-loop result events `is_error` distinguishes
"model said error" from "model produced output". Both sub-fields are
already in the dict — just not printed.

`cmd_run` (line ~624) and `cmd_explain` (line ~655) need a small extension
to print the sub-fields when present.

## Acceptance Criteria

### Agent

**1. cmd_run terminal sub-fields**
- [x] When `terminal_event.type == "error"` and `retryable` key exists,
      print `retryable:       <bool>` after `terminal:`.
- [x] When `terminal_event.type == "result"` and `is_error` key exists,
      print `is_error:        <bool>` after `terminal:`.
- [x] Other terminal types (e.g. `agent.done`) print only the type — no
      noise from missing sub-fields.

**2. cmd_explain surface terminal_event**
- [x] When the row has a `terminal_event` field, print:
      `terminal:       <type>` and (if applicable) `retryable:` / `is_error:`.
      Same logic as cmd_run.
- [x] If row lacks `terminal_event`, no terminal lines printed (legacy rows).

**3. Tests**
- [x] `tests/unit/test_resolver_run.py` adds:
      - cmd_run pi error path prints `retryable: True` line (extends existing test)
      - cmd_run ollama-loop success path prints `is_error: False` line
      - cmd_run agent.done path does NOT print retryable/is_error
- [x] `python3 -m pytest tests/unit/test_resolver_run.py -v` exits 0 (9/9 pass; +2 new T-1778 tests)
- [x] No regression: full spawn + ollama_loop + resolver_run suites pass (41/41).

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

### Human

(Mechanical / deterministic — no Human ACs.)

## Verification

python3 -m pytest tests/unit/test_resolver_run.py tests/unit/test_spawn.py tests/unit/test_ollama_loop.py -v

## Recommendation

**Recommendation:** GO — surfaces the data that T-1777 persists. cmd_run + cmd_explain now print retryable/is_error sub-fields when applicable; agent.done events stay quiet (no noise).

**Rationale:** T-1777 added `terminal_event` to the dispatch row but kept the CLI quiet on sub-fields. For pi 429 retries, `retryable: True/False` is the single most important detail; for ollama-loop dispatches `is_error: True/False` distinguishes "model said error" from "model produced output". Both already in the dict — this is pure formatting. Tests pin the three branches: pi error shows retryable, ollama-loop result shows is_error, agent.done shows neither. Existing tests that asserted only `terminal: <type>` still pass.

**Evidence:**
- `lib/resolver.py:cmd_run` lines 624-630 — sub-field branch
- `lib/resolver.py:cmd_explain` post-outcome line — surfaces persisted terminal_event from row
- `tests/unit/test_resolver_run.py` — 9/9 pass (+2 new T-1778 tests, 1 existing extended)
- Full regression: 41/41 across spawn + ollama_loop + resolver_run

**Headline mechanic:** `bin/fw resolver run T-XXX <task_type>` now shows retryable/is_error inline. `bin/fw resolver explain <dispatch_id>` surfaces the same from the persisted row.

## Evolution

### 2026-05-10 — quiet on agent.done; vocal on error/result

- **What changed:** Considered printing the sub-field block unconditionally (would print "retryable: -" for agent.done events). Rejected: every successful pi dispatch would carry a meaningless line. The right shape is: print only what's informative for THIS terminal type. Tests pin the quiet path for agent.done explicitly.
- **Plan impact:** Branch logic in cmd_run / cmd_explain on `te["type"]` before printing sub-fields. Three branches: error+retryable / result+is_error / other (silent).
- **Triggered:** No new task — pinned via test.

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

### 2026-05-10T05:32:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1778-fw-resolver-runexplain--surface-terminal.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e476925c
- **Timestamp:** 2026-06-02T14:59:40Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-13T21:10:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
