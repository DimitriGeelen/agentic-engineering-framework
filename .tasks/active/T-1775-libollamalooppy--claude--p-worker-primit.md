---
id: T-1775
name: "lib/ollama_loop.py — claude -p worker primitive (2nd worker_kind route)"
description: >
  lib/ollama_loop.py — claude -p worker primitive (2nd worker_kind route)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [spawn, worker-primitive]
components: [lib/ollama_loop.py, lib/spawn.py, tests/unit/test_ollama_loop.py, 
      tests/unit/test_spawn.py]
related_tasks: [T-1700, T-1773, T-1774]
arc_id: orchestrator-rethink
created: 2026-05-09T21:08:55Z
last_update: '2026-08-16T22:23:59Z'
date_finished: 2026-05-13T21:20:30Z
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
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=3 (body:typed-io-or-gate); F3=1
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:23:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1775: lib/ollama_loop.py — claude -p worker primitive (2nd worker_kind route)

## Context

T-1773 shipped `lib/spawn.py` with pi-only routing. Three worker_kinds raise
`NotImplementedError`. The first that can be unblocked is `ollama-loop` —
T-1700 already shipped the litellm proxy and the `claude -p` invocation
pattern with redirected env vars (ANTHROPIC_BASE_URL → localhost:4000) is
proven in `agents/termlink/termlink.sh:714`. What's missing is a Python
primitive that wraps that pattern into a callable analogous to
`PiWorker.prompt()`, so `spawn._spawn_ollama_loop` can route through it.

This task ships `lib/ollama_loop.py:OllamaLoopWorker` and registers
`ollama-loop` in `spawn._DISPATCHERS`. CLI integration through
`fw resolver run` works automatically because cmd_run is worker-kind-agnostic.

The mechanic: `subprocess.Popen(["claude","-p",prompt,"--model",M,
"--output-format","stream-json","--verbose"], env=...)` reads stream-json
events from stdout line-by-line and yields parsed dicts. Terminal event is
`{"type":"result", ...}` (claude -p emits this when generation completes).

## Acceptance Criteria

### Agent

**1. Worker primitive**
- [x] `lib/ollama_loop.py:OllamaLoopWorker` exists with the same surface as `PiWorker`:
      - `__init__(model, cwd, env, allowed_tools, binary="claude")` — Popen claude -p
        with `--output-format stream-json --verbose`, line-buffered, text mode
      - `prompt(message) -> Iterator[dict]` — writes prompt arg directly to argv
        (claude -p reads prompt as positional, not stdin), streams parsed events
        from stdout, yields each, terminates on `type=result` or process exit
      - `close() -> int` — graceful close (wait ≤5s) → kill (wait ≤2s) fallback
      - Context manager (`__enter__`/`__exit__`)
- [x] Tools flag: if `allowed_tools` non-empty, pass `--tools t1,t2,...`. Empty list = no flag (claude -p default catalogue).

**2. Spawn driver routing**
- [x] `lib/spawn.py:_DISPATCHERS["ollama-loop"]` registered to `_spawn_ollama_loop`.
- [x] `_spawn_ollama_loop(envelope, on_event)` mirrors `_spawn_pi`:
      streams events to `<blob_dir>/events.jsonl`, returns same outcome dict
      shape (`status, events_count, events_path, terminal_event`).
- [x] env merging: `os.environ` + `envelope["env"]` (envelope overrides). The
      ANTHROPIC_BASE_URL/ANTHROPIC_API_KEY redirection is what makes this an
      "ollama-loop" rather than "real Anthropic" call.
- [x] Terminal event for ollama-loop is `type=result` (with `is_error: bool`
      sub-field). Map `is_error=True` → `status=error`, else `success`.
- [x] `worker_kind: ollama-loop` no longer in the NotImplementedError
      deferral list (now only TermLink + Task remain deferred).

**3. Unit tests (mocked claude binary)**
- [x] `tests/unit/test_ollama_loop.py` covers:
      - module import without claude on PATH
      - prompt() yields parsed stream-json events
      - terminal `type=result, is_error=False` → success path
      - terminal `type=result, is_error=True` → error path
      - tools flag built correctly from allowed_tools list
      - env merging: envelope env overrides os.environ
      - close() idempotent + kills hung process
      - context manager closes on exit
      - U+2028 / U+2029 anti-readline sentinel (same as PiWorker)
- [x] `tests/unit/test_spawn.py` extended:
      - ollama-loop route success → status=success
      - ollama-loop route error → status=error
      - ollama-loop NOT in NotImplementedError matrix anymore (only TermLink, Task)
- [x] `python3 -m pytest tests/unit/test_ollama_loop.py tests/unit/test_spawn.py -v` exits 0 (29/29 passing in 0.15s)

**4. Build report**
- [x] `docs/reports/T-1775-ollama-loop-build.md` documents:
      - sketch-vs-implementation diff
      - tests inventory
      - architectural decisions (event format, env merging, tools flag)
      - forward-look (what's left: TermLink + Task routes)

### Human

- [ ] [REVIEW] **#H1: End-to-end ollama-loop smoke (after T-1700 #H1+#H2 — litellm running)**
      **Steps:**
      1. Verify litellm: `curl -sf http://localhost:4000/v1/models | head -1`
      2. `cd /opt/999-Agentic-Engineering-Framework && bin/fw resolver run T-1775 ollama-research`
      3. `tail -1 .context/dispatches.jsonl | python3 -c "import sys,json; r=json.loads(sys.stdin.read()); print(r.get('outcome','?'))"`
      **Expected:** stdout shows `status: success`, `events_count > 0`; dispatches.jsonl last row has `outcome: success` (not `pending`).
      **If not:** check litellm running on :4000; check claude binary on PATH; add `--json` to step 2 for full structured outcome; check workflow YAML loaded model + env vars.

## Verification

# Files exist
test -f lib/ollama_loop.py
test -f tests/unit/test_ollama_loop.py
test -f docs/reports/T-1775-ollama-loop-build.md
# Module imports cleanly without claude on PATH
python3 -c "import sys; sys.path.insert(0,'lib'); import ollama_loop; assert hasattr(ollama_loop,'OllamaLoopWorker')"
# Spawn driver routes ollama-loop (no longer raises NotImplementedError)
python3 -c "import sys; sys.path.insert(0,'lib'); import spawn; assert 'ollama-loop' in spawn._DISPATCHERS"
# Unit tests pass
python3 -m pytest tests/unit/test_ollama_loop.py tests/unit/test_spawn.py -v

## Recommendation

**Recommendation:** GO — 2nd worker route shipped, NotImplementedError matrix shrinks from 3 to 2.

**Rationale:** Builds directly on T-1700 (litellm proxy) + T-1773 (spawn driver) + T-1774 (CLI). The headline mechanic `bin/fw resolver run T-XXX <task_type>` now works for both pi (`worker_kind=pi`) and ollama-loop (`worker_kind=ollama-loop`) routes. CLI integration is automatic — `cmd_run` is worker-kind-agnostic, and the same `_DISPATCHERS` registry it dispatches into now has both routes. Tests pin all critical surfaces: 13 ollama_loop unit tests (single-shot prompt, env merging, tools flag, terminal-event mapping, anti-readline) + 3 spawn extension tests (route success, route error, env+tools forwarding) + the existing deferral-matrix test now correctly asserts only TermLink + Task remain stubbed. No regression in the 17 pi/resolver_run tests.

**Evidence:**
- `lib/ollama_loop.py` — 142 LOC; `OllamaLoopWorker` (Popen `claude -p` with stream-json), `prompt()` single-shot, `close()` graceful+kill, context manager
- `lib/spawn.py` — `_spawn_ollama_loop` handler (+56 LOC), `_DISPATCHERS["ollama-loop"]` registered, NotImplementedError message updated to reference T-1775
- `tests/unit/test_ollama_loop.py` — 13 tests, all passing
- `tests/unit/test_spawn.py` — 16 tests (3 new for ollama-loop), all passing
- `docs/reports/T-1775-ollama-loop-build.md` — sketch-vs-implementation diff (5 deviations), test inventory, architectural decisions, forward-look

**Headline mechanic:** `bin/fw resolver run T-XXX ollama-research` resolves to ollama-loop dispatch — workflow loads model + env (ANTHROPIC_BASE_URL → localhost:4000 litellm) + allowed_tools, spawn driver routes to `_spawn_ollama_loop`, OllamaLoopWorker runs `claude -p` with stream-json output, events stream to `<blob_dir>/events.jsonl`, dispatches.jsonl row finalised. Live observation gated on T-1700 #H1+#H2 (litellm running on :4000 + claude binary on PATH).

## Evolution

### 2026-05-09 — claude -p is single-shot, prompt via argv (not stdin)

- **What changed:** First sketch mirrored PiWorker exactly: long-lived subprocess, prompt via stdin, multiple prompt() calls per instance. Investigation of `agents/termlink/termlink.sh:714` revealed `claude -p` reads prompt as positional argv arg, not stdin — the binary doesn't have an RPC mode like pi does. Each prompt() call must spawn a fresh process.
- **Plan impact:** OllamaLoopWorker is single-shot — second prompt() call raises RuntimeError. The dispatch unit is one envelope = one worker = one prompt = one process. This is honest about the protocol shape; pretending otherwise would have meant building a turn-coordinator that the binary doesn't support.
- **Triggered:** Documented as architectural decision in build report. No new task.

### 2026-05-09 — terminal event differs across worker_kinds; outcome contract still unifies

- **What changed:** PiWorker terminates on `agent.done`; claude -p terminates on `type=result` (with `is_error: bool` sub-field). First impulse was to translate ollama-loop's terminal event to look like agent.done at the worker level. Rejected: that's protocol-mixing. The cleaner shape is to keep each worker honest about its own terminal event format, and have the spawn driver apply the right error-mapping per route.
- **Plan impact:** `_spawn_pi` reads `terminal["type"] == "error"`; `_spawn_ollama_loop` reads `terminal["is_error"]`. Outcome contract (the dict returned to callers) unified — `status, events_count, events_path, terminal_event`. The `terminal_event` field carries each route's native shape; consumers that care can inspect it.
- **Triggered:** No new task. Different routes will likely have different terminal-event shapes; the unified outcome contract is the right abstraction layer.

### 2026-05-09 — env merge: os.environ + overlay, not envelope-only

- **What changed:** Initial sketch: pass envelope["env"] as `subprocess.Popen(env=...)` directly. Realized this strips PATH, HOME, and everything else — claude binary wouldn't even resolve. The fix: merge os.environ + overlay envelope["env"] on top.
- **Plan impact:** Pinned in `_build_env`. Tests pin precedence (overlay overrides) and inheritance (os.environ keys preserved unless overridden). Documented in build report.
- **Triggered:** No new task — this is a core invariant of the worker.

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

### 2026-05-09T21:08:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1775-libollamalooppy--claude--p-worker-primit.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0244378d
- **Timestamp:** 2026-06-11T11:49:45Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `test -f tests/unit/test_ollama_loop.py`

- **Suppressed:** 1 (by override)
  - human-ac-mechanical-signal @ AC#1 (Human)
### 2026-05-13T21:20:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
