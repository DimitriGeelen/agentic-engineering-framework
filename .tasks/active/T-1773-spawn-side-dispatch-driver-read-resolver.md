---
id: T-1773
name: "spawn-side dispatch driver: read resolver envelope → spawn worker → stream
  events → emit outcome row"
description: >
  T-1700 + T-1701 both shipped worker primitives (PiWorker for pi, ollama-loop env
  wiring for litellm) but stopped at the worker. The end-to-end mechanic (user submits
  task_type → resolver builds envelope → worker fires → events streamed to .context/dispatch-blobs/<id>/events.jsonl
  → outcome row appended to dispatches.jsonl) currently has no glue. Both v1 builds
  explicitly deferred this to a unified spawn driver once two consumers existed. They
  exist now. Build lib/spawn.py that consumes a dispatch envelope and routes by worker_kind
  to the appropriate primitive. Single-file design; no premature abstraction. Closes
  the orchestrator arc's headline mechanic.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [spawn, dispatch-driver]
components: [lib/resolver.py, lib/spawn.py, tests/unit/test_resolver_run.py, 
      tests/unit/test_spawn.py]
related_tasks: [T-1700, T-1701]
arc_id: orchestrator-rethink
created: 2026-05-06T18:52:51Z
last_update: '2026-06-11T22:23:25Z'
date_finished: 2026-05-13T21:19:49Z
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
      F-RECALL: 2
      F-ORCH: 3
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=3 (body:typed-io-or-gate); F3=0
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1773: spawn-side dispatch driver: read resolver envelope → spawn worker → stream events → emit outcome row

## Context

T-1700 (litellm) and T-1701 (pi RPC) shipped worker primitives but not the
spawn-side glue. `lib/resolver.py:capture_dispatch` builds a dispatch envelope
and writes a row to `.context/dispatches.jsonl` with `outcome: pending`, but
there is no driver that reads the envelope, spawns the worker, streams events,
and finalises the outcome row.

v1 scope intentionally narrow: handle ONLY `worker_kind: pi` (the worker we
have a primitive class for). `ollama-loop`, `TermLink`, and `Task` raise
`NotImplementedError` with explicit deferral messages. Premature unification
across all four worker kinds is the trap T-1700 + T-1701 explicitly avoided.

The end-to-end mechanic this v1 enables (with pi installed):
```
fw resolver dispatch T-XXX cheap-research        # builds envelope + row
python3 -c "from spawn import spawn_dispatch; ..."  # streams events, finalises row
```

CLI integration (`fw resolver run` or `fw orchestrator dispatch`) is deferred
to a follow-up so v1 ships a tested primitive, not a half-wired CLI.

## Acceptance Criteria

### Agent

**1. Spawn primitive**
- [x] `lib/spawn.py` exists with `spawn_dispatch(envelope: dict, *, on_event=None)
      -> dict` that:
      - Routes by `envelope["worker_kind"]` to a handler
      - Returns a final outcome dict: `{"status": "success"|"error",
        "events_count": N, "events_path": <path>, "terminal_event": <dict>}`
      - For `worker_kind: pi`: instantiates `PiWorker` (using provider from
        envelope OR re-loaded workflow), streams events to
        `<blob_dir>/events.jsonl`, terminates on `agent.done` or `error`
      - For other kinds: raises `NotImplementedError` with a message naming
        the missing route AND the task ID where it'll be added
- [x] `update_outcome_row(dispatch_id: str, outcome: str, extra: dict | None)`
      finds the matching row in `.context/dispatches.jsonl` and rewrites the
      file with an updated row (single-row mutation, atomic via tmp+rename)
- [x] Module imports without pi on PATH (no module-level subprocess calls).

**2. Provider resolution**
- [x] If envelope lacks `provider`, `_spawn_pi` re-loads the workflow file from
      `_source_path` (or task_type fallback) to obtain it. Documented as the
      reason: resolver.py's envelope schema doesn't include `provider` in v1
      because it's pi-specific; adding it would mean every worker kind carries
      a field most don't need.
- [x] Resolver envelope is NOT modified (`lib/resolver.py` stays untouched).
      **Verified:** `git diff --stat origin/master...HEAD -- lib/resolver.py` empty.

**3. Unit tests (mocked PiWorker)**
- [x] `tests/unit/test_spawn.py` covers:
      - pi route: events streamed to events.jsonl in declared blob_dir
      - pi route: terminal `agent.done` → outcome `success`
      - pi route: terminal `error` → outcome `error`, captures retryable flag
      - other worker_kinds raise NotImplementedError with the deferral message
      - `update_outcome_row` rewrites the matching row atomically
      - `update_outcome_row` is a no-op (returns False) when dispatch_id absent
- [x] All tests pass: `python3 -m pytest tests/unit/test_spawn.py -v` exits 0
      (13/13 passing in 0.10s).

**4. Build report**
- [x] `docs/reports/T-1773-spawn-driver.md` documents the v1-only scope
      (pi-only), the explicit deferral list (ollama-loop, TermLink, Task),
      sketch-vs-implementation diff, and what CLI integration looks like in v2.

### Human

- [ ] [REVIEW] **#H1: End-to-end smoke (after T-1701 #H1 + #H2)**
      **Steps:**
      1. With pi installed + /login complete: `cd /opt/999-Agentic-Engineering-Framework && bin/fw resolver run T-1773 cheap-research`
      2. Verify: `tail -1 .context/dispatches.jsonl | python3 -c "import sys,json; r=json.loads(sys.stdin.read()); print(r['outcome'])"`
      **Expected:** stdout shows `status: success`, `events_count > 0`, exit code 0; `.context/dispatches.jsonl` last row has `outcome: success` (not `pending`).
      **If not:** add `--json` to step 1 for full structured outcome; check pi binary on PATH, check workflow loaded provider correctly, check blob_dir is writable. (T-1774 added the single-line CLI; the prior multi-line `python -c` invocation is no longer needed.)

## Verification

# Files exist
test -f lib/spawn.py
test -f tests/unit/test_spawn.py
test -f docs/reports/T-1773-spawn-driver.md
# Module imports cleanly without pi on PATH
python3 -c "import sys; sys.path.insert(0,'lib'); import spawn; assert hasattr(spawn,'spawn_dispatch') and hasattr(spawn,'update_outcome_row')"
# Unit tests pass
python3 -m pytest tests/unit/test_spawn.py -v
# (Note: the v1 "resolver untouched" claim was verified at commit time —
#  see Recommendation ## Evidence. It is intentionally not a long-lived
#  Verification gate because legitimate v2 work — `fw resolver run`
#  CLI integration — will modify resolver.py and that's not a regression.)

## Recommendation

**Recommendation:** GO — pi route shipped, v2 routes (ollama-loop, TermLink, Task) explicitly deferred to follow-ups.

**Rationale:** This is the missing glue that turned T-1700 + T-1701 from "worker primitives exist" into "the orchestrator-rethink arc has a callable end-to-end mechanic for the pi worker_kind". `spawn_dispatch` consumes a resolver envelope, runs the pi worker, streams events to disk, and atomically updates the dispatches.jsonl outcome row — closing the round-trip the arc was designed to enable. Tests pin all four critical surfaces: pi route success, pi route error, worker_kind routing matrix, and dispatches.jsonl row mutation. Resolver was NOT touched (verified via git diff against origin/master) — `provider` is loaded from the workflow file for pi dispatches rather than polluting the envelope schema with a pi-specific field.

The three deferred routes (ollama-loop, TermLink, Task) raise `NotImplementedError` with messages that name T-1773 so future grep-for-deferral lands correctly. Premature unification across all four worker kinds is the same trap T-1700 + T-1701 explicitly avoided in their own scopes.

**Evidence:**
- `lib/spawn.py` — 175 LOC; `spawn_dispatch()`, `update_outcome_row()`, `_spawn_pi()`, `SpawnError`
- `tests/unit/test_spawn.py` — 13 tests, `python3 -m pytest tests/unit/test_spawn.py -v` → 13 passed in 0.10s
- `docs/reports/T-1773-spawn-driver.md` — outcome contract, deferred-route rationale, architectural decisions, forward-look
- Resolver untouched: `git diff --stat origin/master...HEAD -- lib/resolver.py` empty

**Headline mechanic:** `spawn_dispatch(envelope)` runs end-to-end for `worker_kind=pi`, streams events to `<blob_dir>/events.jsonl`, finalises the row in `dispatches.jsonl`. Live observation requires Human AC #H1 (which itself depends on T-1701 #H1 + #H2 — pi installed + /login). Until then, the mechanic is provable via unit tests (PiWorker mocked) and via the explicit Python one-liner in #H1's Steps. The agent has shipped what the agent can ship; the live mechanic is gated on the human-only install of pi.

## Evolution

### 2026-05-06 — provider field belongs to the worker, not the envelope

- **What changed:** First impulse was to add `provider` to the resolver envelope so spawn could read it directly. Second pass realized `provider` is pi-specific (other worker kinds don't use it) and adding it would pollute every dispatch row + envelope.
- **Plan impact:** Scope cut: lib/resolver.py stays untouched. Cost: pi handler does an extra YAML re-read per dispatch. Trade is worth it (one disk read vs. permanent schema pollution).
- **Triggered:** Documented as Decision in docs/reports/T-1773-spawn-driver.md §"Architectural decisions". No new sub-task.

### 2026-05-06 — pi-only v1, three explicit NotImplementedError routes

- **What changed:** Initial mental model was "ship spawn driver for all four worker_kinds at once." Caught the same trap T-1700 + T-1701 already navigated: only one worker primitive (PiWorker) exists, so unifying across four routes would mean fabricating three. Pi-only is the right v1 scope.
- **Plan impact:** Three deferred routes; T-1773 closes; CLI integration deferred to a small v2 follow-up.
- **Triggered:** No new task filed — the v2 follow-up is already implicit ("when ollama-loop primitive matures, extend `_DISPATCHERS`"). Filing a task now would be premature.

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

### 2026-05-06T18:52:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1773-spawn-side-dispatch-driver-read-resolver.md
- **Context:** Initial task creation

### 2026-05-06T18:54:00Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5781d0c1
- **Timestamp:** 2026-06-11T11:49:45Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `test -f tests/unit/test_spawn.py`

- **Suppressed:** 1 (by override)
  - human-ac-mechanical-signal @ AC#1 (Human)
### 2026-05-13T21:19:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
