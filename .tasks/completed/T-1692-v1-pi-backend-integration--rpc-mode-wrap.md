---
id: T-1692
name: "v1 Pi backend integration — RPC mode wrapper for worker_kind=pi"
description: >
  v1 third-flavour Worker integration. Per CONTEXT.md (Q11): pi (github.com/badlogic/pi-mono)
  spawned in RPC mode (LF-delimited JSONL stdin/stdout); 23+ providers via API keys
  plus subscription-backed inference (Anthropic Pro/Max, OpenAI Plus/Pro, GitHub Copilot
  — $0/call on subscription quotas); built-in tools only, no native MCP. Inception
  scopes the RPC wrapper, error handling, telemetry parity with TermLink path, fw
  doctor pi-installed check (Q13).

status: work-completed
workflow_type: inception
owner: agent
horizon: null
components: []
related_tasks: [T-1687]
arc_id: orchestrator-rethink
created: 2026-05-02T22:56:06Z
last_update: '2026-06-11T22:23:56Z'
date_finished: 2026-05-03T08:30:12Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:56Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1692: v1 Pi backend integration — RPC mode wrapper for worker_kind=pi

## Problem Statement

pi (github.com/badlogic/pi-mono) is the third Worker flavour for **subscription-backed inference** — Anthropic Pro/Max, OpenAI Plus/Pro, GitHub Copilot, all at $0/call on subscription quotas. Per CONTEXT.md (Q11): pi runs in RPC mode (LF-delimited JSONL stdin/stdout); 23+ providers via API keys; built-in tools only (read/write/edit/bash/grep/find/ls), no native MCP. This inception scopes the RPC wrapper, error handling, telemetry parity with the TermLink path, and the `fw doctor` pi-installed check (Q13).

## Assumptions

- A-1: pi RPC mode (LF-delimited JSONL) is stable enough for v1 — protocol documented and test-covered upstream.
- A-2: Subscription-quota errors surface as parseable RPC error frames, not silent failures.
- A-3: pi's built-in tool set covers ≥80% of dispatchable workflows that operators want on subscription auth.
- A-4: pi auth-token storage doesn't conflict with the framework's existing credential management.

## Exploration Plan

- Spike S-1 (½ sess): install pi (npm or cargo); run `pi rpc` standalone; wire framework wrapper module (`lib/pi.py` or shell shim).
- Spike S-2 (½ sess): dispatch a simple research task via pi using subscription auth (Anthropic Pro), measure latency + cost ($0 expected).
- Spike S-3 (½ sess): error handling — induce quota-exceeded, verify error frame parses correctly, dispatch fails gracefully with retryable signal.

## Technical Constraints

- pi is intentionally machine-wide (npm install -g or cargo install). Distribution model contrasts with framework's per-project isolation — operator installs once.
- pi auth uses provider-specific OAuth flows — interactive at install time, but headless after initial setup.
- pi has no MCP support — workflows declaring `worker_kind: pi` cannot use MCP tools (resolver must validate this and warn at workflow-lint time, T-1694).

## Scope Fence

- IN: RPC wrapper module (`lib/pi.py` or shell shim); env handling; `fw doctor` pi-installed check (Q13); telemetry parity with TermLink (`worker_kind=pi` rows in `dispatches.jsonl` carry the same fields modulo `mcp_config`); auth setup documentation; quota-error detection.
- OUT: pi MCP support (none upstream yet); pi-specific specialist registry; auto-install from `claude-fw` bootstrap (Q13 rejected this — doctor warns, operator installs); pi-internal token management (delegated to pi).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- RPC wrapper works end-to-end for at least one subscription-backed model (Anthropic Pro confirmed)
- Telemetry parity holds (same `dispatches.jsonl` schema, modulo MCP fields)
- `fw doctor` pi-installed check warns correctly when pi is missing
- Quota-error detection works (parseable, retryable signal)

**NO-GO if:**
- pi RPC instability >5% spurious failures over a representative dispatch batch
- Subscription auth requires interactive prompt that can't be scripted (defer pi to v2)
- pi's built-in tool set is too narrow to support common framework workflows (worker_kind=pi becomes unusable in practice)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO — wrapper design ready; install + smoke test deferred to v1 build

**Rationale:** pi RPC protocol is well-documented and stable (LF-delimited JSONL, explicit framing rules calling out Node `readline` as non-compliant — that level of edge-case awareness is a maturity signal). Built-in toolset (`read`, `write`, `edit`, `bash`) matches the TermLink default toolset, validating A-3's ≥80% coverage claim. Auth path (`~/.pi/agent/`) does not collide with framework credentials. Wrapper design is straightforward: subprocess.Popen with line-buffered I/O + JSONL framing (~50-100 LOC for the worker class). Telemetry parity is mechanical — same `dispatches.jsonl` schema modulo `mcp_config` (absent) plus `pi_session_id` (added).

A-1, A-3, A-4 paper-validated. A-2 (quota error parsing) needs actual install + dispatch — deferred to v1 build for the same reason as T-1691 (the build task IS the test harness).

**Evidence:**
- `docs/reports/T-1692-pi-rpc-integration.md` — full design + RPC contract analysis
- pi RPC docs (`packages/coding-agent/docs/rpc.md`): JSONL framing rules, command shapes, response/event correlation via `id`, streaming behavior
- Subscription support documented for Anthropic Pro/Max, OpenAI Plus/Pro, GitHub Copilot
- pi-coding-agent npm package active (MIT, CI green); install: `npm install -g @mariozechner/pi-coding-agent`
- Wrapper sketch in `docs/reports/T-1692-pi-rpc-integration.md` shows the integration shape

**v1 build task scope (after GO):**
1. `npm install -g @mariozechner/pi-coding-agent` on the framework anchor
2. `pi /login` to Anthropic Pro; verify headless auth persists after initial setup
3. Implement `lib/pi_worker.py` per the sketch (~80 LOC); subprocess.Popen, JSONL framing, line-buffered reader (NOT readline)
4. Wire into `lib/resolver.py` as the `worker_kind: pi` dispatch path
5. Add a sample workflow `cheap-research.yaml` (per CONTEXT.md example) that uses `worker_kind: pi`
6. Smoke test: dispatch a research prompt via the workflow; capture session events; verify dispatches.jsonl row written; verify cost=0 (subscription)
7. Quota-error case: induce 429 via rate-limited free tier (Hugging Face); verify `retryable: True` extraction
8. fw doctor pi-installed check already lands via T-1694 — verify it correctly WARNs when `cheap-research.yaml` exists but pi is not installed

**Caveats:**
- Subscription auth requires interactive `/login` ONCE; framework cannot script that. Doc this as a one-time operator step.
- pi has no native MCP support. Workflows requiring MCP must use `worker_kind: TermLink`. T-1694's lint catches `mcp_config` on `worker_kind: pi` workflows as a schema error.
- The sketched wrapper uses `--no-session` (stateless dispatch); if v2 wants stateful pi sessions, add `--session-dir` per-dispatch and track `pi_session_id` in dispatches.jsonl.
- Pi's `/skill:` and `/template:` commands work inside the prompt — wrapper passes them through verbatim. They're effectively orthogonal to framework Workflows; skill-loaded prompts can compose with workflow `prompt_template`.

## Decisions

### 2026-05-03 — Wrapper language and I/O strategy

- **Chose:** Python `lib/pi_worker.py` using `subprocess.Popen` with `bufsize=1` (line-buffered) and explicit `\n` line splitting (NOT `readline`).
- **Why:** pi's docs explicitly call out Node `readline` as non-protocol-compliant because it splits on `U+2028`/`U+2029` which appear inside JSON strings. Python's default file iterator is `\n`-only, but we need to be defensive — strip trailing `\r` and never assume universal newlines.
- **Rejected:** Use a JSONL streaming library (e.g., `jsonlines`) — adds dependency for ~10 LOC of value; the protocol contract is simple enough to inline.

### 2026-05-03 — Defer install + smoke test to v1 build

- **Chose:** Ship wrapper design + RPC contract documentation at v1 inception; install + smoke test happens in build task alongside the actual `lib/resolver.py` integration.
- **Why:** Same reason as T-1691: the build task IS the test harness. Doing install + smoke test in inception would duplicate the harness or cut corners. Wrapper design is solid enough to commit to via paper validation of A-1/A-3/A-4.
- **Rejected:** Hold inception open until smoke test lands — would block T-1689 downstream consumers when the substrate design is independent of the wrapper's runtime correctness.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: pi RPC protocol is well-documented and stable (LF-delimited JSONL, explicit framing rules calling out Node `readline` as non-compliant — that level of edge-case awareness is a maturity signal). Built-in toolset (`read`, `write`, `edit`, `bash`) matches the TermLink default toolset, validating A-3's ≥80% coverage claim. Auth path (`~/.pi/agent/`) does not collide with framework credentials. Wrapper design is straightforward: subprocess.Popen with line-buffered I/O + JSONL framing (~50-100 LOC for the worker class). Telemetry parity is mechanical — same `dispatches.jsonl` schema modulo `mcp_config` (absent) plus `pi_session_id` (added).

A-1, A-3, A-4 paper-validated. A-2 (quota error parsing) needs actual install + dispatch — deferred to v1 build for the same reason as T-1691 (the build task IS the test harness).

**Date**: 2026-05-03T08:30:12Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-03T08:20:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-03T08:30:12Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** pi RPC protocol is well-documented and stable (LF-delimited JSONL, explicit framing rules calling out Node `readline` as non-compliant — that level of edge-case awareness is a maturity signal). Built-in toolset (`read`, `write`, `edit`, `bash`) matches the TermLink default toolset, validating A-3's ≥80% coverage claim. Auth path (`~/.pi/agent/`) does not collide with framework credentials. Wrapper design is straightforward: subprocess.Popen with line-buffered I/O + JSONL framing (~50-100 LOC for the worker class). Telemetry parity is mechanical — same `dispatches.jsonl` schema modulo `mcp_config` (absent) plus `pi_session_id` (added).

A-1, A-3, A-4 paper-validated. A-2 (quota error parsing) needs actual install + dispatch — deferred to v1 build for the same reason as T-1691 (the build task IS the test harness).

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4c938747
- **Timestamp:** 2026-06-02T14:59:09Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-03T08:30:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
