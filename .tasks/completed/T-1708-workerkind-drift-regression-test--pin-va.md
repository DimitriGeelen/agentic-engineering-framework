---
id: T-1708
name: "worker_kind drift regression test — pin validator + dispatcher in sync"
description: >
  Pin the worker_kind drift class. T-1706 added `ollama-loop` to the termlink dispatcher's `--worker-kind` flag but missed `VALID_WORKER_KINDS` in `bin/fw`'s workflow validator → `fw doctor` silently failed on the new workflow until T-1707 caught it. Test asserts the validator set and the dispatcher case-statement stay in sync, so the next worker_kind addition can't ship half-wired.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [tests/unit/test_worker_kind_drift.bats]
related_tasks: [T-1706, T-1707]
arc_id: orchestrator-rethink
created: 2026-05-03T22:44:23Z
last_update: 2026-05-03T23:38:43Z
date_finished: 2026-05-03T23:38:43Z
---

# T-1708: worker_kind drift regression test — pin validator + dispatcher in sync

## Context

Origin: 2026-05-04 T-1707 implementation. Running `bin/fw doctor` for verification surfaced a fresh `FAIL`:
`worker_kind='ollama-loop' not in ['Task', 'TermLink', 'pi']`. T-1706 had wired `ollama-loop`
into the termlink dispatcher (`--worker-kind` flag + run.sh dispatch logic) and the workflow YAML
(`worker_kind: ollama-loop`), but missed the workflow schema validator's `VALID_WORKER_KINDS`
constant in `bin/fw`. The dispatcher and validator drifted silently — nothing tested they
remain in sync. T-1707 fixed the constant; this task pins the invariant so it can't drift again.

The drift surface is wide: a new worker_kind requires updates in
- `bin/fw` `VALID_WORKER_KINDS` (validator)
- `agents/termlink/termlink.sh` `--worker-kind` case statement (acceptor)
- `agents/termlink/termlink.sh` run.sh dispatch logic (executor)
- Workflow YAML files declaring the kind

This test pins the first two surfaces — sufficient to catch the T-1706→T-1707 incident class.

## Acceptance Criteria

### Agent
- [x] New test file `tests/unit/test_worker_kind_drift.bats` exists with 4+ tests.
      **Verified:** 6 tests filed (4 required + 2 bonus pinning run.sh executor branch
      and ollama-tool-loop.py existence).
- [x] All new tests pass.
      **Verified:** 6/6 pass.
- [x] No regression: `bats tests/unit/test_doctor_scope_tags.bats` (10) and
      `bats tests/unit/test_boundary_hook_arguments.bats` (28) still pass.
      **Verified:** 38/38 still pass alongside the 6 new ones.

## Recommendation

**Recommendation:** SHIP — pure pin, no behaviour change.

**Rationale:**
The T-1706 → T-1707 sequence caught a real drift bug: dispatcher and
validator were out of sync for ~1 day before `fw doctor` surfaced it.
This test makes that class of drift impossible to ship silently again.

**Evidence:**
- `tests/unit/test_worker_kind_drift.bats` — 6/6 pass
- Commit `66e06dbf5` — implementation

## Verification

bash -n bin/fw
bash -n agents/termlink/termlink.sh
bats tests/unit/test_worker_kind_drift.bats
bats tests/unit/test_doctor_scope_tags.bats

## RCA

**Symptom:** `fw doctor` emitted `FAIL  Workflow schema: 1 error(s) ... worker_kind='ollama-loop' not in ['Task', 'TermLink', 'pi']` on the ollama-research workflow file shipped by T-1706. Surfaced by chance during T-1707 verification — could have stayed undetected until the next time someone ran the workflow lint, days or weeks out.

**Root cause:** worker_kind is encoded in **two unrelated places**: the workflow validator (`VALID_WORKER_KINDS` in `bin/fw`) and the dispatcher acceptor (`--worker-kind` case in `agents/termlink/termlink.sh`). T-1706 updated the dispatcher half but missed the validator half. The two halves had no shared source of truth and no test asserting they stay aligned.

**Why structurally allowed:** No test crosses the validator/dispatcher boundary. A new worker_kind that's added to one but not the other will type-check, parse-check, and pass `bash -n` on both files — and will only surface the gap when a workflow file using the new kind hits the validator at runtime. The framework had test coverage for "validator accepts X" and "dispatcher accepts X" independently, but no test asserting "validator-set ⊆ dispatcher-set ∪ {non-TermLink kinds}".

**Prevention:** This task — `tests/unit/test_worker_kind_drift.bats`. The drift detector test extracts `VALID_WORKER_KINDS` from `bin/fw`, excludes the kinds documented as non-TermLink-routed (Task, pi, the alias TermLink), and asserts every remaining kind appears in the dispatcher's case statement. Adding a kind to one side without the other now fails CI loudly.

The narrower fix (T-1707's bonus commit pulling `ollama-loop` into `VALID_WORKER_KINDS`) addressed the symptom; this test addresses the structural blindness so the next worker_kind addition can't ship half-wired.

## Updates

### 2026-05-03T22:44:23Z — task-created
- Filed as antifragile follow-up to drift caught in T-1707.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-42fa286d
- **Timestamp:** 2026-06-02T14:59:14Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-03T23:38:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
