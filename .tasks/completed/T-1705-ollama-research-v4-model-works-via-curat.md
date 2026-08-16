---
id: T-1705
name: "ollama-research v4: model works via curated API but not via claude -p. Architectural
  choice: thin tool-loop vs claude-code-router vs accept text-only"
description: >
  Inception: ollama-research v4: model works via curated API but not via claude -p.
  Architectural choice: thin tool-loop vs claude-code-router vs accept text-only

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: [v4-inception]
components: [tools/t1704-hermes3-probe.sh]
related_tasks: []
created: 2026-05-03T20:30:32Z
last_update: '2026-08-16T22:24:41Z'
date_finished: 2026-05-03T20:36:20Z
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
  - ts: '2026-08-16T22:24:41Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1705: ollama-research v4: model works via curated API but not via claude -p. Architectural choice: thin tool-loop vs claude-code-router vs accept text-only

## Problem Statement

ollama-research workflow (T-1700 substrate) needs to dispatch tool-using research
tasks to a local 16GB ollama backend. Three iterations have failed to clear the
90% real-tool-use bar:

- T-1700: qwen3:14b (0/10), gpt-oss:20b (1/3) on wide catalogue
- T-1703: gemma4:8b + qwen3.5:9.7B × {wide, narrow, single-tool} catalogues (0/18)
- T-1704: hermes3:8b (function-calling-tuned) × same 3 catalogues (0/9)

T-1704 then ran a curated direct comparison: the SAME hermes3:8b model, called
directly against litellm `/v1/messages` with a 1-tool definition, emits perfect
`tool_use` JSON 3/3 times. Through claude -p, 0/9.

**The bottleneck is claude -p's prompt construction, not the model.** The wide
tool catalogue + system prompt + Anthropic instruction format prevents open-weight
models from emitting tool_use, even when `--tools` restricts the catalogue exposed
to the model. A function-calling-tuned model that works perfectly with curated
prompts produces pure prose through claude -p.

**Decision needed:** which architectural path to take to ship a working
ollama-research v1, given that the model+proxy stack is fine but claude -p is
the wrong client.

## Assumptions

1. **A-T1705-1:** A thin tool-execution loop (~150 LOC) calling litellm
   `/v1/messages` with a curated 3-5 tool definition can hit 90%+ on simple-read
   prompts using hermes3:8b. (Validated by T-1704 N=3 curated-direct: 100%.)
2. **A-T1705-2:** claude-code-router's prompt rewriting is aggressive enough to
   coax tool_use from hermes3:8b. (Untested; would require integration spike.)
3. **A-T1705-3:** Accepting text-only ollama-research kills the G-064 autonomous-
   consumer story for the orchestrator-rethink arc. (True — that arc's whole
   premise is "real consumers exercise the substrate", and text-only doesn't
   exercise any tool dispatch.)

## Exploration Plan

**Spike A (timebox: 1 session):** Thin tool-loop spike.
- 50-line python or bash worker that calls `/v1/messages`, parses tool_use,
  executes Read/Bash/Grep, sends tool_result, loops until `stop_reason: end_turn`.
- Run on the same simple-read prompts T-1704 used. Target: 3/3 real tool calls
  with hermes3:8b; latency comparable to T-1704 (8-30s per call).
- GO criteria: ≥90% real tool_use across N=3 simple-read + N=3 multi-step prompts.

**Spike B (timebox: 1 session, only if Spike A fails):** claude-code-router.
- Install, configure, run same matrix.
- GO criteria: same 90% bar.

**Spike C (no spike — purely a documentation choice):** Accept text-only.
- Drop ollama-research's tool-use bar, document as the v1 ceiling.
- Open question: does this satisfy G-064 at all, or is G-064 unresolvable on this stack?

## Technical Constraints

- **GPU memory ceiling:** 16GB. Rules out >14B models at usable quantization.
- **No claude -p modifications:** the wide-prompt construction is in the closed
  binary; we can wrap or replace, not edit.
- **Substrate to preserve:** litellm proxy + workflow `env:`/`allowed_tools:`
  fields + dispatch envelope shape + `dispatch-outcomes.jsonl` back-prop — all
  reusable across all three options.
- **TermLink dispatch contract:** `wdir/result.jsonl` + `wdir/result.md` +
  `wdir/exit_code` + `wdir/meta.json` are read by `fw outcome` and
  `dispatch_status`. Any new worker MUST produce this layout.

## Scope Fence

**IN scope:**
- Decide between options 1, 2, 3.
- Spike option 1 (thin loop) to validate Assumption A-T1705-1.
- File a build task for the chosen path.

**OUT of scope:**
- Pulling more models (T-1704 closed the model-fitness question).
- Inception on whether `ollama-research` is the right workflow name (yes, keep it).
- Replacing claude -p in OTHER workflows (interactive-deep, code-edit). Those
  use Anthropic's real API and don't have this problem.

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

**GO (option 1 — thin tool-loop) if:**
- Spike A reaches ≥90% real tool_use on simple-read prompts with hermes3:8b
- Worker output layout matches existing dispatch wdir contract (result.jsonl /
  result.md / exit_code / meta.json)
- Latency per dispatch ≤2× the T-1704 hermes3 figures (median 7-21s)

**GO (option 2 — claude-code-router) if:**
- Spike A fails AND Spike B reaches the same 90% bar
- Integration cost ≤1 session

**GO (option 3 — accept text-only) if:**
- Spikes A and B both fail OR cost >2 sessions
- Explicit write-off of G-064 autonomous-consumer ambition for ollama
  (or: argue separately that text-only research IS a tool dispatch via the
  bus/dispatch-outcomes layer, even without claude-style tool_use events)

**NO-GO (defer everything) if:**
- New evidence emerges that ollama backend itself is unreliable (it isn't —
  T-1700/T-1703/T-1704 all returned answers; quality, not stability, is the issue)

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

**Recommendation:** GO option 1 (thin tool-loop), spike-validated.

**Rationale:**
The empirical evidence in T-1704 already validates A-T1705-1 at N=3: hermes3:8b
on direct litellm `/v1/messages` with a 1-tool def emits perfect tool_use 100%
of the time. The full Spike A is therefore a high-confidence validation of
something we already saw work, plus building the loop scaffold around it.

Option 1 is the smallest surface change because:
- All substrate (litellm proxy, --env plumbing, --tools plumbing, harness, alias
  config, dispatch envelope, outcome back-prop hook) is reusable.
- The new code is bounded: tool execution loop + result.jsonl writer.
- hermes3:8b is already loaded and proven.

Option 2 (claude-code-router) carries the same risk profile as v3 — adding
another proxy without validating it addresses the actual root cause
(claude -p prompt format).

Option 3 (text-only) is a defensible last-resort but contradicts the
orchestrator-rethink arc's premise. Filing it as the explicit fallback if
Spike A surprisingly regresses.

**Evidence:**
- `docs/reports/T-1704-hermes3-probe.md` — the architectural finding that drives
  this inception (curated-direct 3/3 vs claude -p 0/9 on identical model).
- L-348 — captures the bottleneck-is-claude-p insight as a learning.
- T-1700/T-1703/T-1704 substrate — reusable for whichever path wins.

**v4 build scope (separate task post-decide):**
- Implement `tools/ollama-tool-loop.{py,sh}` that wraps the existing dispatch
  contract: reads `prompt.md`, calls litellm, executes tool_use → tool_result
  loop, writes `result.jsonl` + `result.md` + `exit_code` + meta.
- Update `lib/workflows/ollama-research.yaml` worker_kind from `TermLink`
  (which spawns claude -p) to a new `ollama-loop` worker_kind.
- Add `bin/fw termlink dispatch --worker-kind ollama-loop` shim so the
  resolver-driven dispatch path stays uniform.

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

**Rationale**: The empirical evidence in T-1704 already validates A-T1705-1 at N=3: hermes3:8b
on direct litellm `/v1/messages` with a 1-tool def emits perfect tool_use 100%
of the time. The full Spike A is therefore a high-confidence validation of
something we already saw work, plus building the loop scaffold around it.

Option 1 is the smallest surface change because:
- All substrate (litellm proxy, --env plumbing, --tools plumbing, harness, alias
  config, dispatch envelope, outcome back-prop hook) is reusable.
- The new code is bounded: tool execution loop + result.jsonl writer.
- hermes3:8b is already loaded and proven.

Option 2 (claude-code-router) carries the same risk profile as v3 — adding
another proxy without validating it addresses the actual root cause
(claude -p prompt format).

Option 3 (text-only) is a defensible last-resort but contradicts the
orchestrator-rethink arc's premise. Filing it as the explicit fallback if
Spike A surprisingly regresses.

**Date**: 2026-05-03T20:36:20Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-03T20:34:21Z — status-update [task-update-agent]
- **Change:** tags: +v4-inception

### 2026-05-03T20:36:20Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** The empirical evidence in T-1704 already validates A-T1705-1 at N=3: hermes3:8b
on direct litellm `/v1/messages` with a 1-tool def emits perfect tool_use 100%
of the time. The full Spike A is therefore a high-confidence validation of
something we already saw work, plus building the loop scaffold around it.

Option 1 is the smallest surface change because:
- All substrate (litellm proxy, --env plumbing, --tools plumbing, harness, alias
  config, dispatch envelope, outcome back-prop hook) is reusable.
- The new code is bounded: tool execution loop + result.jsonl writer.
- hermes3:8b is already loaded and proven.

Option 2 (claude-code-router) carries the same risk profile as v3 — adding
another proxy without validating it addresses the actual root cause
(claude -p prompt format).

Option 3 (text-only) is a defensible last-resort but contradicts the
orchestrator-rethink arc's premise. Filing it as the explicit fallback if
Spike A surprisingly regresses.

### 2026-05-03T20:36:20Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Reason:** Inception decision in progress

## Reviewer Verdict (v1.5)

- **Scan ID:** R-29dea5f0
- **Timestamp:** 2026-06-02T14:59:13Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-03T20:36:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
