---
id: T-1774
name: "fw resolver run: CLI integration of spawn driver — one-line dispatch+spawn
  end-to-end"
description: >
  T-1773 shipped lib/spawn.py callable from Python but the human-facing #H1 still
  requires a multi-line python one-liner. Add a  subcommand to lib/resolver.py that
  combines  +  into a single call. CLI-only — no new architecture, just glue. Replaces
  T-1773 #H1's python -c with .

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [cli, spawn]
components: [lib/resolver.py, tests/unit/test_resolver_run.py]
related_tasks: [T-1773, T-1701]
arc_id: orchestrator-rethink
created: 2026-05-06T19:05:44Z
last_update: '2026-06-11T22:23:25Z'
date_finished: 2026-05-13T21:20:14Z
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
---

# T-1774: fw resolver run: CLI integration of spawn driver — one-line dispatch+spawn end-to-end

## Context

T-1773 shipped `lib/spawn.py` with a callable Python API. T-1773 #H1 currently
asks the human to run a multi-line `python3 -c "..."` invocation to dispatch.
This task adds a `run` subcommand to `lib/resolver.py` so the human can run a
single command: `bin/fw resolver run T-XXX <task_type>`.

CLI-only — no new architecture. resolver.py already has `cmd_dispatch` that
calls `resolve()` and prints the envelope; `cmd_run` reuses that same
`resolve()` call and pipes the envelope into `spawn.spawn_dispatch`. The
`spawn` import is lazy so existing `dispatch | workflows | explain` callers
don't pay for it.

Exit-code design: 0 success, 1 infrastructure error (resolver/spawn/import),
2 worker terminal error (agent.done with type=error). The third exit code lets
shell callers distinguish "framework broke" from "worker reported error".

## Acceptance Criteria

### Agent

**1. CLI surface**
- [x] `lib/resolver.py:cmd_run(args)` exists; `main()` registers a `run`
      subparser with the same args as `dispatch` (`task_id`, `task_type`,
      `--var`, `--json`) plus exit-code semantics noted in the docstring.
- [x] Lazy import of `spawn` (deferred to inside `cmd_run`) so resolver
      callers that don't need spawn don't pay for it.
- [x] `bin/fw resolver --help` lists `run` subcommand alongside dispatch /
      workflows / explain. **Verified:** `{dispatch,run,explain,workflows}`.
- [x] `bin/fw resolver run --help` shows the run-specific flags.
      **Verified:** `task_id`, `task_type`, `--json`, `--var KEY=VALUE`.

**2. Exit codes**
- [x] Returns 0 on `outcome.status == "success"`.
- [x] Returns 1 on resolver errors, spawn import failures, NotImplementedError
      from spawn (worker_kind not yet routed), and `SpawnError`.
- [x] Returns 2 on `outcome.status == "error"` (worker terminal error).

**3. Unit test (mocked spawn_dispatch)**
- [x] `tests/unit/test_resolver_run.py` covers:
      - happy path: cmd_run returns 0, prints status=success
      - worker error: cmd_run returns 2 when terminal_event.type == "error"
      - NotImplementedError from spawn → cmd_run returns 1 with stderr message
      - SpawnError from spawn → cmd_run returns 1 with stderr message
      - --json flag emits parseable JSON
- [x] `python3 -m pytest tests/unit/test_resolver_run.py -v` exits 0
      (7 passed in 0.07s).

**4. T-1773 #H1 simplified**
- [x] T-1773's Human AC #H1 step 3 is updated from the multi-line `python -c`
      to a single command: `bin/fw resolver run T-1773 cheap-research`.
      (Edit only the Steps section; do not check the AC checkbox.)

### Human

- [ ] [REVIEW] **#H1: End-to-end CLI smoke (after T-1701 #H1+#H2 + pi installed)**
      **Steps:**
      1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw resolver run T-1773 cheap-research`
      2. `tail -1 .context/dispatches.jsonl` — should show `outcome: success`
      **Expected:** stdout shows status=success, events_count > 0, dispatch_id; exit code 0.
      **If not:** check pi binary; check workflow YAML loaded provider; run with `--json` to see structured outcome.

## Verification

# Files exist + module imports
test -f tests/unit/test_resolver_run.py
python3 -c "import sys; sys.path.insert(0,'lib'); import resolver; assert hasattr(resolver,'cmd_run')"
# CLI help shows the new subcommand
bin/fw resolver --help 2>&1 | grep -q "^\s*run\s"
bin/fw resolver run --help 2>&1 | grep -q "task_type"
# Unit tests pass
python3 -m pytest tests/unit/test_resolver_run.py -v
# T-1773 #H1 step 3 updated to single-line bin/fw resolver run
grep -q "bin/fw resolver run T-1773 cheap-research" .tasks/active/T-1773-spawn-side-dispatch-driver-read-resolver.md

## Recommendation

**Recommendation:** GO — minimal CLI glue, no architecture changes; T-1773 #H1 collapses from a multi-line `python -c` to a single `bin/fw resolver run` invocation.

**Rationale:** The smallest possible follow-up to T-1773. ~60 LOC in `lib/resolver.py` (cmd_run + argparse subparser), 7 unit tests pinning exit-code semantics + worker-kind matrix + JSON output. Lazy `spawn` import means existing `dispatch | workflows | explain` callers pay no extra startup cost. Exit-code design (0/1/2) lets shell callers distinguish infrastructure breaks from worker terminal errors — the tighter contract simplifies CI/audit usage.

**Evidence:**
- `lib/resolver.py` cmd_run + subparser: `{dispatch,run,explain,workflows}` shown by `bin/fw resolver --help`
- `tests/unit/test_resolver_run.py` — 7 tests, `python3 -m pytest -q` → 7 passed in 0.07s
- T-1773 #H1 step 3 simplified from `python3 -c "import sys, json; sys.path.insert(0,'lib'); ..."` to `bin/fw resolver run T-1773 cheap-research`
- Lazy spawn import verified: `import resolver` does not import `spawn` (test 1 patches `sys.modules` only after entering cmd_run)

**Headline mechanic:** `bin/fw resolver run T-XXX <task_type>` — single command, end-to-end. Live observation gated on T-1701 #H1+#H2 + T-1773 #H1, same chain as before. The change here is purely UX: the human's #H1 instruction now fits on one line.

## Evolution

### 2026-05-06 — exit-code 2 for worker terminal errors

- **What changed:** First impulse was binary 0/1 (success/anything-else). Realized shell callers can't distinguish "framework broke" from "worker reported error" without parsing the outcome dict — exactly the kind of fragility the framework's audit/CI infrastructure should avoid. Added exit code 2 for worker-reported error.
- **Plan impact:** Tightened contract: 0=success, 1=infra error, 2=worker error. Test cases added for all three.
- **Triggered:** No new task. Documented in `cmd_run` docstring.

### 2026-05-06 — lazy spawn import preserves existing-caller startup cost

- **What changed:** Module-level `from spawn import spawn_dispatch` would force every `fw resolver dispatch` and `fw resolver workflows` call to load spawn (and potentially try to import pi_worker). Lazy import inside cmd_run keeps the cold path cold.
- **Plan impact:** None — pure micro-optimisation, but worth pinning so a future "clean up imports" refactor doesn't undo it.
- **Triggered:** Documented in cmd_run inline comment.

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

### 2026-05-06T19:05:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1774-fw-resolver-run-cli-integration-of-spawn.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-bc61f668
- **Timestamp:** 2026-05-18T09:30:53Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Human)** — [REVIEW] **#H1: End-to-end CLI smoke (after T-1701 #H1+#H2 + pi installed)**
  - **human-ac-mechanical-signal** (partial, heuristic) — `matched='exit code' in Expected: stdout shows status=success, events_count > 0, dispatch_id; exit code 0.`

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `test -f tests/unit/test_resolver_run.py`
### 2026-05-13T21:20:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
