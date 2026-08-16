---
id: T-1797
name: "TermLink worker primitive — lib/termlink_worker.py wraps fw termlink dispatch
  (T-1776 Option A)"
description: >
  TermLink worker primitive — lib/termlink_worker.py wraps fw termlink dispatch (T-1776
  Option A)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [spawn, termlink, worker-primitive]
components: [lib/spawn.py, lib/termlink_worker.py, tests/unit/test_spawn.py, 
      tests/unit/test_termlink_worker.py]
related_tasks: [T-1776, T-1773, T-1775, T-1700, T-1701]
arc_id: orchestrator-rethink
created: 2026-05-12T21:51:51Z
last_update: '2026-08-16T22:23:59Z'
date_finished: 2026-05-12T21:57:27Z
bvp_scores_proposed:
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 0
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=0 
      (no-signal); D4=2 (body:env-class-handled); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 1
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=0 
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); 
      F-ORCH=1 (body:hand-wired-dispatch); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:23:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=0 
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=1 (body/components:prompt-incidental); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1797: TermLink worker primitive — lib/termlink_worker.py wraps fw termlink dispatch (T-1776 Option A)

## Context

T-1776 surfaced the fallback-workflow contract gap: `default.yaml` declares
`worker_kind: TermLink` but `lib/spawn._DISPATCHERS` has no TermLink entry, so
the most-default path through the resolver→spawn substrate raises
NotImplementedError. The human picked **Option A** — build a Python primitive
that mirrors `OllamaLoopWorker` and wraps the existing `fw termlink dispatch`
shell command, then wire it into `lib/spawn._DISPATCHERS["TermLink"]`.

This closes the trap: the default-fallback dispatch path can finally complete
end-to-end. It also unlocks any workflow that wants TermLink's session
isolation (independent OS process, observable from outside, survives parent
context compaction) for heavier multi-file work.

**Pattern parity with `OllamaLoopWorker`:**
- Same `prompt(message) -> Iterator[event]` shape
- Same `close()` cleanup
- Same context-manager support
- Terminal event is `{"type": "result", "is_error": bool, ...}` (claude -p's
  stream-json contract, which TermLink's run.sh writes to `result.jsonl`)

**Differences forced by the substrate:**
- `OllamaLoopWorker` spawns `claude -p` in-process and streams stdout directly.
- `TermLinkWorker` invokes `fw termlink dispatch` (which spawns claude inside
  a separate TermLink/PTY session asynchronously), then `fw termlink wait`s
  for the worker, then reads the on-disk `result.jsonl` and yields events.
- Eventing is "post-hoc replay" rather than live stream — TermLink's whole
  point is process isolation, so we get the final event file, not stdout.

## Acceptance Criteria

### Agent

**1. Primitive module**
- [x] `lib/termlink_worker.py` defines class `TermLinkWorker` with:
      `__init__(model, cwd, task_id, env, allowed_tools, task_type, timeout, fw_bin, name)`,
      `prompt(message) -> Iterator[dict]` (single-shot; dispatch → wait → replay),
      `close()` (best-effort), and context-manager protocol.
- [x] Mirrors `OllamaLoopWorker`'s shape so `lib/spawn._spawn_termlink` can
      be a near-copy of `_spawn_ollama_loop` (only the worker class differs).

**2. Spawn driver wiring**
- [x] `lib/spawn.py` adds `_spawn_termlink(envelope, on_event)` handler.
- [x] `_DISPATCHERS["TermLink"] = _spawn_termlink` registered.
- [x] `NotImplementedError` branch in `spawn_dispatch` no longer triggers
      for `worker_kind="TermLink"` (only `Task` remains).

**3. Tests — primitive**
- [x] `tests/unit/test_termlink_worker.py` covers:
      - argv shape for dispatch invocation (task_id, name, model, env, tools)
      - prompt() yields events parsed from result.jsonl
      - prompt() terminates on `{"type": "result"}` event
      - close() is idempotent + safe when never launched
      - context-manager protocol
      - re-prompt raises RuntimeError (single-shot)
      - malformed result.jsonl lines skipped

**4. Tests — spawn route**
- [x] `tests/unit/test_spawn.py` extends with TermLink route test:
      `_DISPATCHERS["TermLink"]` is wired; an envelope with
      `worker_kind=TermLink` no longer raises NotImplementedError
      (uses monkeypatched TermLinkWorker).

**5. Verification gate**
- [x] `python3 -m pytest tests/unit/test_termlink_worker.py tests/unit/test_spawn.py -v` exits 0.

### Human

- [ ] [REVIEW] **Live dispatch smoke (optional)** — confirm a real dispatch
      through `default.yaml` no longer crashes.
      **Steps:**
      1. `cd /opt/999-Agentic-Engineering-Framework`
      2. `bin/fw resolver dispatch T-1797 ad-hoc-test --dry-run` — inspect
         envelope; should declare `worker_kind: TermLink`.
      3. `bin/fw resolver run T-1797 ad-hoc-test` (live) — should complete
         (success or worker-internal failure), NOT raise NotImplementedError.
      **Expected:** Spawn driver routes TermLink path; events.jsonl populated;
      dispatches.jsonl outcome != "error: NotImplementedError".
      **If not:** Note which step crashed and what the traceback says.

## Verification

python3 -m pytest tests/unit/test_termlink_worker.py tests/unit/test_spawn.py -v

## Recommendation

**Recommendation:** GO — closes T-1776 contract gap; default-fallback path now ships end-to-end.

**Rationale:** Before this slice, any dispatch through `default.yaml` (declared `worker_kind: TermLink`) raised `NotImplementedError` at spawn time — the most-default path through the substrate was a trap. `TermLinkWorker` is a thin (~200 LOC) Python primitive mirroring `OllamaLoopWorker`'s shape (single-shot `prompt(message) -> Iterator[event]`, `close()`, context-manager); the divergence is forced by TermLink's process-isolation model (we invoke `fw termlink dispatch`, wait for the worker, then replay events from on-disk `result.jsonl` rather than streaming stdout). Spawn handler `_spawn_termlink` is a near-copy of `_spawn_ollama_loop`. The terminal-event shape is identical (`{"type": "result", "is_error": bool}`), so outcome quality aggregation (T-1796) works against TermLink dispatches with zero further changes.

**Evidence:**
- `lib/termlink_worker.py` — new module; class `TermLinkWorker` wraps `fw termlink dispatch` + `fw termlink wait` + result.jsonl replay; preserves the worker dir for post-mortem forensics (T-1777-style trail).
- `lib/spawn.py` — `_spawn_termlink` handler added; `_DISPATCHERS["TermLink"]` registered; NotImplementedError branch narrowed to `Task` only.
- `tests/unit/test_termlink_worker.py` — 14 tests covering argv shape (3), prompt() flow (6), and lifecycle (3).
- `tests/unit/test_spawn.py` — 3 new TermLink route tests (wired, error-terminal, forwards-args) replacing the now-stale "TermLink raises NotImplementedError" assertion.
- Verification gate: `python3 -m pytest tests/unit/test_termlink_worker.py tests/unit/test_spawn.py -v` → 35/35 passed.
- Live dry-run: `bin/fw resolver dispatch T-1797 ad-hoc-test --dry-run` confirms default-fallback envelope still declares `worker_kind: TermLink` (the spawn-side now routes it instead of crashing).

**Headline mechanic:** `bin/fw resolver run T-XXX <any-unknown-task-type>` → resolver falls back to default.yaml → spawn driver routes `worker_kind=TermLink` → `TermLinkWorker.prompt()` → `fw termlink dispatch ... --task T-XXX` → worker runs in isolated PTY → `fw termlink wait` blocks → events replayed from result.jsonl → outcome row finalised.

## Evolution

### 2026-05-12 — T-1776 Option A landed

- **What changed:** The TermLink wrapper turned out to be smaller than the original ~150 LOC estimate (it's a thin facade over `fw termlink dispatch` which already does the real spawn work). The interesting design choice was *not* cleaning up the worker dir in `close()` — the dir holds the post-mortem trail (meta.json, result.jsonl, exit_code) that downstream tooling reads (`fw outcome read`, route_cache record-outcome). Premature cleanup would erase it. `fw termlink cleanup` owns dir teardown and runs on its own cadence.
- **Plan impact:** With this slice, the `_DISPATCHERS` set in `lib/spawn.py` covers 3 of 4 declared worker_kinds (pi, ollama-loop, TermLink); only `Task` remains. That last one is a sub-agent dispatch (Claude Code Task tool) and is *not* a resolver→spawn shape — it lives at a different layer. So in practice the substrate's worker-routing matrix is now complete for resolver-side dispatch. The default-fallback trap T-1776 surfaced is closed.
- **Triggered:** None autonomously. Follow-up candidates: (a) live dispatch smoke test once budget allows; (b) close T-1776 via `fw task review` with this as the resolution evidence.


## Updates

### 2026-05-12T21:51:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1797-termlink-worker-primitive--libtermlinkwo.md
- **Context:** T-1776 Option A picked by human — build TermLink Python primitive

## Reviewer Verdict (v1.4)

- **Scan ID:** R-7dc83247
- **Timestamp:** 2026-05-18T09:30:55Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-12T21:57:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
