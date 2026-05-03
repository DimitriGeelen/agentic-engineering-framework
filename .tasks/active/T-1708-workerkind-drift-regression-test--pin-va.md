---
id: T-1708
name: "worker_kind drift regression test — pin validator + dispatcher in sync"
description: >
  Pin the worker_kind drift class. T-1706 added `ollama-loop` to the termlink dispatcher's `--worker-kind` flag but missed `VALID_WORKER_KINDS` in `bin/fw`'s workflow validator → `fw doctor` silently failed on the new workflow until T-1707 caught it. Test asserts the validator set and the dispatcher case-statement stay in sync, so the next worker_kind addition can't ship half-wired.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc:orchestrator-rethink]
components: []
related_tasks: [T-1706, T-1707]
created: 2026-05-03T22:44:23Z
last_update: 2026-05-04T00:30:00Z
date_finished: null
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
- [ ] New test file `tests/unit/test_worker_kind_drift.bats` exists with 4+ tests:
      - `VALID_WORKER_KINDS` in `bin/fw` includes Task, TermLink, pi, ollama-loop
      - `agents/termlink/termlink.sh` `--worker-kind` accepts `""|claude|ollama-loop`
      - Every TermLink-routed kind in `VALID_WORKER_KINDS` has a case branch in termlink.sh
        (drift detector — fails when validator gains a TermLink kind without dispatcher update)
      - termlink.sh `--worker-kind` rejects unknown kinds (negative pin)
- [ ] All new tests pass.
- [ ] No regression: `bats tests/unit/test_doctor_scope_tags.bats` (10) and
      `bats tests/unit/test_boundary_hook_arguments.bats` (28) still pass.

## Verification

bash -n bin/fw
bash -n agents/termlink/termlink.sh
bats tests/unit/test_worker_kind_drift.bats
bats tests/unit/test_doctor_scope_tags.bats

## Updates

### 2026-05-03T22:44:23Z — task-created
- Filed as antifragile follow-up to drift caught in T-1707.
