---
id: T-1805
name: "pause_requested terminal_event class — substrate recognition (dispatch-safety
  slice 1)"
description: >
  pause_requested terminal_event class — substrate recognition (dispatch-safety slice
  1)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [slice-1]
components: [lib/outcome.py, lib/resolver.py, lib/spawn.py, 
      tests/unit/test_outcome.py, tests/unit/test_spawn.py]
related_tasks: []
arc_id: dispatch-safety
created: 2026-05-13T15:01:56Z
last_update: '2026-06-11T22:23:25Z'
date_finished: 2026-05-13T15:09:23Z
bvp_scores_proposed:
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1805: pause_requested terminal_event class — substrate recognition (dispatch-safety slice 1)

## Context

Slice 1/5 of the dispatch-safety arc. Substrate-only — teaches `lib/spawn.py`, the dispatches.jsonl outcome row, and `fw outcome list`/`fw outcome read` to recognize `pause_requested` as a valid terminal_event class without yet requiring any Worker to actually emit it. This is the foundation: subsequent slices (Resolver preamble, workflow schema, Watchtower surface, re-dispatch chain) all assume the substrate already knows what a pause is. See ADR-0004 and CONTEXT.md Q15.

## Acceptance Criteria

### Agent
- [x] `lib/spawn.py` recognizes `pause_requested` as a terminal event in all three dispatchers (`_spawn_pi`, `_spawn_ollama_loop`, `_spawn_termlink`). When emitted, the terminal_event dict is captured as the dispatch's terminal_event.
- [x] When terminal_event.type == `pause_requested`, the dispatch outcome status is `paused` (new third value, joins `success` and `error`).
- [x] `update_outcome_row` accepts `paused` as a valid status without raising.
- [x] `lib/outcome.py` recognizes the new `paused` status: `fw outcome list` displays a `[paused]` indicator on rows with this status; `fw outcome read` surfaces the pause-specific fields (`question`, `assessment`, `state_ref`) from terminal_event when its type is `pause_requested`.
- [x] Unit test: synthetic dispatch where Worker yields a `pause_requested` event → spawn outcome returns `status: paused`, dispatch row has `outcome: paused` + terminal_event captured. One test per dispatcher.
- [x] Unit test: `outcome.list_outcomes` / `outcome.read_outcome` rendering surfaces pause-specific fields.
- [x] No regression in existing `success` / `error` paths — all existing `tests/unit/test_spawn.py` and `tests/unit/test_outcome*.py` tests still pass.

### Human
- [ ] [REVIEW] Confirm the substrate change matches ADR-0004's intent — `pause_requested` is the Worker-emitted event class; `paused` is the dispatch outcome status. Both are minimal additions; no existing behavior changes.
  **Steps:**
  1. Read ADR-0004 (`docs/adr/0004-worker-uncertainty-handling-pause-not-timeout-severity-times-likelihood-trigger-peer-consult-deferred.md`) — focus on the "Consequences" section
  2. Read the diff in `lib/spawn.py` and `lib/outcome.py`
  3. Verify the naming matches: terminal_event class = `pause_requested`; outcome status = `paused`
  **Expected:** Names match ADR-0004's intent. No surprising additions beyond the recognition layer (no Resolver changes, no workflow schema changes — those are slices 2/3).
  **If not:** Note the divergence and which name/decision in ADR-0004 should be the canonical one.

## Verification

# Shell commands that MUST pass before work-completed.

python3 -m pytest tests/unit/test_spawn.py -q
# T-2766: was `pytest tests/unit/test_outcome_read.py tests/unit/test_outcome_list.py
# -q 2>&1 | tail -5 || pytest tests/unit/ -k outcome -q`. Neither named file has ever
# existed (git log --all --diff-filter=A is empty for both), so the `||` arm was the
# sole executor from the day this was written — and its population is `-k outcome`
# across the whole suite (70 tests, 4 files), not this task's deliverable. It was
# reporting another component's failures as T-1805's. Re-pointed at the file this
# task's own `components:` declares and its commit modified; fallback dropped.
python3 -m pytest tests/unit/test_outcome.py -q
python3 -c "import sys; sys.path.insert(0, 'lib'); from spawn import _PAUSE_EVENT_TYPE; assert _PAUSE_EVENT_TYPE == 'pause_requested', f'pause event class drift: {_PAUSE_EVENT_TYPE!r}'"
python3 -c "import sys; sys.path.insert(0, 'lib'); from spawn import _VALID_OUTCOME_STATUSES; assert 'paused' in _VALID_OUTCOME_STATUSES, f'paused status missing from VALID set: {_VALID_OUTCOME_STATUSES}'"

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

### 2026-05-13 — `_classify_status` extracted as helper
- **What changed:** Pre-existing dispatchers each computed status inline (`pi`: `"error" if terminal.type=="error" else "success"`; `ollama-loop`/`TermLink`: `"error" if is_error else "success"`). With pause as a third class, inlining the three-way logic in each dispatcher would duplicate it. Extracted `_classify_status(terminal)` as a single source of truth — all three dispatchers call it. Pause-precedence semantics (a paused Worker has not attempted the work; pause beats success/error classifications) live in one place.
- **Plan impact:** No scope change; cleaner shape. The slice's first AC ("recognizes pause_requested as a terminal event") is now a one-line change per dispatcher + the helper.
- **Triggered:** None — internal refactor.

### 2026-05-13 — outcome.py and resolver.py BOTH render pause fields
- **What changed:** Originally only outcome.py was in scope. `lib/resolver.py:cmd_run` and `cmd_explain` also render terminal_event sub-fields (mirror of T-1778). Skipping them would create a forensics inconsistency — `fw outcome read` shows pause fields, but `fw resolver explain` of the same dispatch wouldn't.
- **Plan impact:** One extra `Edit` to `lib/resolver.py`. ACs widened to cover both surfaces.
- **Triggered:** None.

### 2026-05-13 — list-line question is truncated at 40 chars
- **What changed:** Question text in `_terminal_suffix` is truncated with ellipsis if > 40 chars. Long pause questions would otherwise blow out the one-line list-row format.
- **Plan impact:** None to ACs (still a single line per row). The test `test_cmd_list_truncates_long_pause_question` pins the contract.
- **Triggered:** None.

## Decisions

### 2026-05-13 — naming: `paused` for outcome status, `pause_requested` for event type
- **Chose:** Outcome status field becomes one of `success | error | paused`. The Worker-emitted terminal event has `type: pause_requested`.
- **Why:** Two distinct concepts deserve two distinct names. `paused` is an outcome state (joins `success`/`error` as terminal states of a dispatch). `pause_requested` is the event the Worker emitted to signal that state. Conflating them (e.g. `outcome: paused_awaiting_resolution`) would couple the event taxonomy to the status taxonomy unnecessarily.
- **Rejected:** `paused_awaiting_resolution` as outcome status — verbose, redundant (awaiting-resolution is implied by the status being `paused` and the event being present). ADR-0004's "Outcome row marks `terminal_event: paused_awaiting_resolution`" phrasing was imprecise; reconcile in a CONTEXT.md or ADR-0004 follow-up if needed (Evolution log if it bites).

### 2026-05-13 — slice scope
- **Chose:** Recognition layer only — no Worker behavior change, no schema change, no Resolver change.
- **Why:** Smallest viable vertical slice. Lets subsequent slices (Resolver preamble, schema, Watchtower, re-dispatch) build on a proven substrate. If recognition turns out to be harder than expected, we learn now before building anything on top.
- **Rejected:** Bundle with Resolver preamble (slice 2). Would conflate the "substrate recognizes" change with the "Workers emit" change, doubling the diff and the test surface in one task.

## Recommendation

**Recommendation:** GO

**Rationale:** Substrate now recognizes `pause_requested` as a terminal event class across all three Worker dispatchers (pi, ollama-loop, TermLink). Outcome status correctly classifies pause separately from success/error. Both forensic surfaces (`fw outcome read|list`, `fw resolver run|explain`) render pause-specific fields. 12 new tests pass; all 56 existing tests still pass (no regression). The slice is foundational — slices 2-5 build on this without changing it.

**Evidence:**
- `lib/spawn.py`: added `_PAUSE_EVENT_TYPE` constant + `_VALID_OUTCOME_STATUSES` set + `_classify_status` helper; three dispatchers updated to recognize pause as terminal
- `lib/outcome.py`: `_terminal_suffix` + `cmd_read` + `_event_summary` render pause fields (question, severity, likelihood, state_ref)
- `lib/resolver.py`: `cmd_run` + `cmd_explain` mirror the same pause surface
- 68 unit tests pass (56 pre-existing + 12 new) — `tests/unit/test_spawn.py tests/unit/test_outcome.py`
- 77 tests pass across resolver+outcome+spawn together (no resolver regression)
- AC verification commands all green: `_PAUSE_EVENT_TYPE == 'pause_requested'`, `'paused' in _VALID_OUTCOME_STATUSES`

**Next steps (slice 2):** Resolver risk-policy preamble — baseline severity×likelihood preamble injected into every dispatch prompt so Workers learn when to emit pause. Without slice 2, slice 1 is correct but inert (no Worker emits pause yet).

## Updates

### 2026-05-13T15:01:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1805-pauserequested-terminalevent-class--subs.md
- **Context:** Initial task creation

### 2026-05-13T15:03:49Z — status-update [task-update-agent]
- **Change:** tags: +arc:dispatch-safety

### 2026-05-13T15:03:49Z — status-update [task-update-agent]
- **Change:** tags: +slice-1

## Reviewer Verdict (v1.4)

- **Scan ID:** R-026383c8
- **Timestamp:** 2026-05-18T09:30:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-13T15:09:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
