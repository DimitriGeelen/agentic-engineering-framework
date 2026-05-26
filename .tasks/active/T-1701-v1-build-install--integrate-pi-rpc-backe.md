---
id: T-1701
name: "v1 build: install + integrate pi RPC backend for worker_kind=pi dispatch"
description: >
  Build follow-up to T-1692 GO. npm install -g @mariozechner/pi-coding-agent, pi /login
  (one-time interactive), implement lib/pi_worker.py (~80 LOC subprocess.Popen with
  JSONL framing, NOT readline), wire into lib/resolver.py as worker_kind=pi path,
  ship cheap-research.yaml workflow, smoke-test dispatch + verify cost=0 subscription
  path, induce 429 to verify retryable extraction. See T-1692 ## Recommendation for
  full 8-step scope.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [pi, subscription-llm]
components: [lib/pi_worker.py, lib/resolver.py, lib/spawn.py, tests/unit/test_pi_worker.py, tests/unit/test_resolver_run.py, tests/unit/test_spawn.py]
related_tasks: [T-1692, T-1696, T-1693, T-1694]
arc_id: orchestrator-rethink
created: 2026-05-03T15:47:11Z
last_update: 2026-05-26T21:50:17Z
date_finished: 2026-05-26T21:50:17Z
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 4
      D4: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=4
      (body:framework-level-ux); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1701: v1 build: install + integrate pi RPC backend for worker_kind=pi dispatch

## Context

Build follow-up to T-1692 GO (`docs/reports/T-1692-pi-rpc-integration.md`). v1 ships
the agent-deliverable substrate so Human ACs can run the live install + smoke-test
without reblocking on code. Sibling pattern: T-1700 (litellm proxy adapter) — same
"agent ships code + harness, human runs the install + measures real traffic" split.

The pi binary is NOT installed on this anchor (`command -v pi` empty). The four
agent-deliverable parts are independent of pi being installed: PiWorker is unit-
tested with mocked subprocess; cheap-research.yaml is schema-validated by
`fw resolver workflows`; fw doctor's pi-installed gate already lands in T-1694
(verify it WARNs correctly when pi missing + workflow declares worker_kind: pi).

Agent does NOT touch lib/resolver.py — `pi` is already in VALID_WORKER_KINDS
(line 59) since T-1696. The worker_kind validation is dispatch-prep only;
spawn-side execution belongs to the v1 build's PiWorker class, consumed by a
later spawn-side driver (out of scope here, same as T-1700 deferred its claude-p
spawn driver to a later v2 task).

## Acceptance Criteria

### Agent

**1. PiWorker implementation**
- [x] `lib/pi_worker.py` exists with `PiWorker` class implementing the T-1692
      sketch: `subprocess.Popen` with `bufsize=1` + line-buffered I/O,
      `text=True`, explicit `\n` line splitting (never `readline`), JSONL framing
      with `\r` strip on read, `--mode rpc --provider $P --model $M --no-session`
      argv per pi RPC docs.
- [x] PiWorker exposes `prompt(message: str) -> Iterator[dict]` yielding events
      until `agent.done` or `error`.
- [x] PiWorker exposes `close()` that closes stdin and waits ≤5s for the child
      (no orphaned pi processes after a clean dispatch).
- [x] `lib/pi_worker.py` imports cleanly even when pi is not on PATH (no
      module-level `subprocess.run(["pi", ...])` — the Popen call only fires on
      `PiWorker(...)` construction).

**2. Workflow file**
- [x] `.context/project/workflows/cheap-research.yaml` exists with:
      - `worker_kind: pi`
      - `model: claude-3-5-sonnet-latest` (via Anthropic Pro subscription)
      - `provider: anthropic` (passed to pi RPC)
      - `task_type: cheap-research`
      - `prompt_template: prompts/default.md`
      - `cost_cap_usd: 0.0` (subscription path)
      - schema-valid per `fw doctor` workflow lint (Q14)
- [x] `bin/fw resolver workflows` lists `cheap-research.yaml` with
      `worker=pi  model=claude-3-5-sonnet-latest`.

**3. Unit tests (mocked subprocess)**
- [x] `tests/unit/test_pi_worker.py` covers:
      - JSONL framing: multi-line stdout parsed event-by-event
      - prompt() yields all events up to and including `agent.done`
      - prompt() yields up to and including `error` then stops
      - prompt() does not split on U+2028/U+2029 (anti-readline regression pin)
      - close() does not raise on already-exited subprocess
- [x] All tests pass: `python3 -m pytest tests/unit/test_pi_worker.py -v` exits 0
      (10/10 passing, 0.05s).

**4. fw doctor gate (T-1694 wiring already shipped — verify behavior)**
- [x] With `cheap-research.yaml` present + pi NOT on PATH, `fw doctor` emits
      a host-scope WARN line matching
      `pi not installed.*workflows declaring worker_kind: pi will fail`.
      **Verified live:** `WARN  [host] pi not installed; workflows declaring worker_kind: pi will fail`.
- [x] With pi installed (or no pi-using workflow), `fw doctor` does NOT emit
      that line. (Cannot test "pi installed" branch without install — Human AC.)
      **Verified branch 2 (no workflow):** prior to creating cheap-research.yaml the line was absent. Branch 1 (pi installed) is the Human AC #H1+#H3 path.

**5. Build report**
- [x] `docs/reports/T-1701-pi-rpc-build.md` exists with: install-prereq one-liner
      for the human, file inventory, sketch-vs-implementation diff (any
      deviations from T-1692 sketch documented), unit-test results table,
      explicit list of what's deferred to Human ACs (#H1–#H4 below) with reason.

### Human

- [ ] [RUBBER-STAMP] **#H1: Install pi**
      **Steps:**
      1. `cd /opt/999-Agentic-Engineering-Framework && npm install -g @mariozechner/pi-coding-agent`
      2. `command -v pi && pi --version`
      **Expected:** pi binary on PATH, version prints (any 0.x or 1.x).
      **If not:** check Node.js ≥18 (`node -v`), npm prefix (`npm config get prefix`),
      and install report at `docs/reports/T-1701-pi-rpc-build.md` §Install troubleshooting.

- [ ] [RUBBER-STAMP] **#H2: pi /login (Anthropic Pro)**
      **Steps:**
      1. `pi /login` (interactive — paste subscription token when prompted)
      2. `ls ~/.pi/agent/` — should show credential files
      **Expected:** auth persists; `pi --provider anthropic --model claude-3-5-sonnet-latest "hello"` returns a response without re-prompting.
      **If not:** `pi /logout && pi /login`; verify Anthropic Pro subscription still active at console.anthropic.com.

- [ ] [REVIEW] **#H3: Live smoke dispatch (cost=0 subscription verified)**
      **Steps:**
      1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw resolver dispatch T-1701 cheap-research --dry-run` (verify envelope shape only — no spawn)
      2. `cd /opt/999-Agentic-Engineering-Framework && python3 tools/t1701-pi-smoke.py "summarise the framework's three priority horizons"` (live spawn via PiWorker)
      3. Check `.context/dispatches.jsonl` last row: `worker_kind: pi`, `cost_usd: 0`, `pi_session_id` present.
      **Expected:** events stream to stdout ending with `{"type": "agent.done"}`; total cost = 0; no errors.
      **If not:** check pi process didn't crash (`ps aux | grep pi`); check the harness's structured event log at `docs/reports/T-1701-pi-rpc-build.md` §smoke-test for known event shapes.

- [ ] [REVIEW] **#H4: 429 retryable extraction**
      **Steps:**
      1. Use a free-tier provider that rate-limits aggressively (Hugging Face Inference API per T-1692 plan): `python3 tools/t1701-pi-smoke.py --provider huggingface --model meta-llama/Llama-3.2-1B-Instruct --induce-429 "anything"`
      2. Inspect the captured event log at `.context/dispatch-blobs/<latest>/events.jsonl`
      3. Verify the harness's `retryable` extraction: `grep '"retryable": true' .context/dispatch-blobs/<latest>/error.json`
      **Expected:** at least one event with `type: error` AND extracted `retryable: true` (or equivalent retryable flag).
      **If not:** capture the full error event shape and add to T-1692's RPC-contract notes; if HF doesn't 429, switch to OpenAI free-tier or reduce delay between requests.

## Verification

# Files exist
test -f lib/pi_worker.py
test -f .context/project/workflows/cheap-research.yaml
test -f tests/unit/test_pi_worker.py
test -f docs/reports/T-1701-pi-rpc-build.md
# Workflow YAML is valid + has the required fields
python3 -c "import yaml,sys; d=yaml.safe_load(open('.context/project/workflows/cheap-research.yaml')); assert d.get('worker_kind')=='pi' and d.get('task_type')=='cheap-research', d"
# Resolver lists it with concrete worker (line is indented; match anywhere)
{ bin/fw resolver workflows 2>&1 || true; } | grep -E "cheap-research\.yaml.*worker=pi.*model=claude"
# pi_worker module imports cleanly without pi on PATH (no top-level subprocess call)
python3 -c "import sys; sys.path.insert(0,'lib'); import pi_worker; assert hasattr(pi_worker,'PiWorker')"
# Unit tests pass
python3 -m pytest tests/unit/test_pi_worker.py -v
# fw doctor warns when pi missing + workflow uses worker_kind=pi (host-scope WARN)
{ bin/fw doctor 2>&1 || true; } | grep -qE "pi not installed.*worker_kind: pi"
# fw doctor still shows no FAIL lines (only WARNs are acceptable)
# L-387 fix: avoid mid-pipe grep that exits 1 on no-match under pipefail
bin/fw doctor > /tmp/.t1701-doctor 2>&1 || true; test "$(grep -cE '^\s*FAIL' /tmp/.t1701-doctor)" = "0"

## Recommendation

**Recommendation:** GO — agent-deliverable substrate complete; live install + smoke-test deferred to Human ACs by design (sibling pattern to T-1700).

**Rationale:** The four agent ACs that don't depend on a live pi binary are all green: `lib/pi_worker.py` (124 LOC, 10/10 unit tests passing), `cheap-research.yaml` workflow (resolver lists it with concrete `worker=pi  model=claude-3-5-sonnet-latest`), `fw doctor` runtime gate verified WARNing correctly when pi is missing + workflow declares `worker_kind: pi`, and `docs/reports/T-1701-pi-rpc-build.md` documents the install-prereq one-liner + sketch-vs-implementation diff + Human AC handoff. Resolver was untouched because `pi` is already in `VALID_WORKER_KINDS` since T-1696. The four Human ACs (#H1 install, #H2 /login, #H3 live smoke, #H4 429 retryable) are documented with copy-pasteable steps and cannot be agentic — `pi /login` is interactive per T-1692's caveat. The 10 unit tests pin the JSONL framing contract from pi's RPC docs (most importantly the U+2028/U+2029 anti-readline invariant), so the wrapper is regression-protected against the canonical Node-readline mistake the upstream maintainer explicitly warns about.

**Evidence:**
- `lib/pi_worker.py` — 124 LOC; `class PiWorker` with `prompt()`, `close()`, context manager protocol
- `tests/unit/test_pi_worker.py` — 10 tests, `python3 -m pytest tests/unit/test_pi_worker.py -v` → 10 passed in 0.05s
- `.context/project/workflows/cheap-research.yaml` — schema-valid, listed by `bin/fw resolver workflows` as `cheap-research.yaml  worker=pi  model=claude-3-5-sonnet-latest`
- `bin/fw doctor` live output: `WARN  [host] pi not installed; workflows declaring worker_kind: pi will fail` (FAIL count = 0)
- `docs/reports/T-1701-pi-rpc-build.md` — sketch-vs-implementation diff documents 5 deviations, install troubleshooting table, deferred-Human-AC rationale per item

**Headline mechanic (v1 substrate):** `bin/fw resolver workflows` lists cheap-research with concrete worker/model + `bin/fw doctor` emits the WARN — both observable on this anchor *now*. The end-to-end user-visible mechanic ("user submits cheap-research → gets pi response, cost=0") only fires after Human AC #H3 — that's the live mechanic, gated on #H1+#H2. Per CLAUDE.md §Arc Completion Discipline, this distinction is acknowledged: v1 ships substrate, v1's headline mechanic is dispatch-prep visibility, the arc-level user-visible mechanic remains gated on the human-only install.

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

### 2026-05-03T15:47:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1701-v1-build-install--integrate-pi-rpc-backe.md
- **Context:** Initial task creation

### 2026-05-06T18:40:24Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9e2b85c9
- **Timestamp:** 2026-05-26T21:53:44Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-26T21:50:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
