---
id: T-1703
name: "v2 probe: gemma4 + qwen3.5 against curated tool catalogue — cheapest path to
  90% real tool-use"
description: >
  v2 probe: gemma4 + qwen3.5 against curated tool catalogue — cheapest path to 90%
  real tool-use

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [agents/termlink/termlink.sh, tools/t1700-ollama-harness.sh, 
      tools/t1703-probe-matrix.sh]
related_tasks: []
created: 2026-05-03T19:33:36Z
last_update: '2026-06-11T22:23:56Z'
date_finished: 2026-05-03T20:00:15Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:56Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 1
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=1 (body:hand-wired-dispatch); 
      F3=1 (body/components:prompt-incidental); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1703: v2 probe: gemma4 + qwen3.5 against curated tool catalogue — cheapest path to 90% real tool-use

## Context

T-1700 shipped litellm proxy substrate but the empirical bar (90% real tool-use) missed
on qwen3:14b (0/10) and gpt-oss:20b (1/3). T-1700's recommendation listed three v2 paths:
(a) ≥70B model, (b) claude-code-router, (c) restricted `allowed_tools`.

Hardware constraint: 16GB GPU. Path (a) is dead — 70B Q4 needs ~40GB, IQ1/IQ2 quants
collapse quality. Realistic ceiling: 14B Q4 or 32B IQ2.

Two cheaper-than-router paths to probe FIRST:
1. **Restricted catalogue** — workflow already declares `allowed_tools: [Read, Bash, Grep]`
   but `lib/resolver.py:402` captures it into envelope and nothing reads it. `claude -p`
   sees the wide ~100-tool default. The narrow case has NEVER been tested.
2. **Untested loaded models** — `gemma4:latest` (8B Q4) and `qwen3.5:latest` (9.7B Q4)
   are already on `192.168.10.107:11434`. Free to test.

If gemma4 OR qwen3.5 hits 90% real tool_use on simple-read with a curated catalogue,
that's a v2 winner without pulling new models, swapping to claude-code-router, or
prompt engineering. Cheapest possible answer.

Predecessors: T-1700 (substrate + harness), T-559 (boundary-hook origin, unrelated).
Sister: T-1701 (pi RPC, blocked).

## Acceptance Criteria

### Agent
- [x] `agents/termlink/termlink.sh` accepts `--tools <comma-list>` flag; written to
      `$wdir/tools.txt`; sourced by `run.sh` and passed as `claude -p --tools <list>`.
      Smoke-verified: `t1703-smoke-1` worker produced `meta.json {"tools_restricted": ["Read","Bash"]}`
      and `ps` showed `--tools Read,Bash` in the live claude argv.
- [x] `.context/litellm-config.yaml` adds two probe aliases:
      `claude-3-5-sonnet-gemma4` → `ollama_chat/gemma4:latest`
      `claude-3-5-sonnet-qwen35` → `ollama_chat/qwen3.5:latest`
      Verified via `curl -H "Authorization: Bearer sk-litellm-local-dev" /v1/models`.
- [x] `tools/t1700-ollama-harness.sh` accepts `T1700_HARNESS_MODEL`, `T1700_HARNESS_TOOLS`,
      `T1700_HARNESS_TASK` env vars, passes through to dispatch. Report header records both.
- [x] Probe matrix runs on simple-read task class: gemma4 × {wide, "Read,Bash,Grep", "Read"}
      (3 cells) + qwen3.5 × same (3 cells). Ran at **N=3 not N=5** — result was unanimous
      0/3 in every cell, so N=5 expansion offered no incremental signal and would have
      doubled spend on a confirmed null. Plus 1 bonus N=3 cell for `qwen2.5-coder-32b:IQ2_M`
      (3/3 timeouts at 180s — disqualified by latency). Total: 21 real dispatches.
      Results in `docs/reports/T-1703-curated-catalogue-probe.md`.
- [x] Report includes per-cell `tool_use_pct` (real metric — exit=0 AND tool_uses≥1),
      records honest miss + failure-mode RCA + pivot path.
- [N/A] If a cell ≥90%: workflow updated. (No cell ≥90%; this branch is N/A.)
- [x] If no cell ≥90%: pivot path captured in `## Decisions`; v3 follow-up task filed.
      T-1704 created and tagged `arc:orchestrator-rethink`.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Hook still parses
bash -n agents/termlink/termlink.sh
# Litellm config valid YAML + has new aliases
python3 -c "import yaml; c=yaml.safe_load(open('.context/litellm-config.yaml')); names=[m['model_name'] for m in c['model_list']]; assert 'claude-3-5-sonnet-gemma4' in names and 'claude-3-5-sonnet-qwen35' in names"
# Probe report exists
test -f docs/reports/T-1703-curated-catalogue-probe.md
# Report records tool_use_pct per cell (not just exit codes)
grep -qE "tool_use_pct|Real tool-use rate" docs/reports/T-1703-curated-catalogue-probe.md
# At least one v2 winner identified OR pivot path captured
grep -qE "Winner:|Pivot:" docs/reports/T-1703-curated-catalogue-probe.md

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

### 2026-05-03 — Catalogue restriction is disproven on these models

- **Chose:** declare path (c) from T-1700 recommendation (restrict `allowed_tools`) DEAD
  for gemma4:8b and qwen3.5:9.7b. 0/9 real tool calls across all 3 catalogue sizes per model.
- **Why:** failure mode is structural — gemma4 hallucinates/refuses, qwen3.5 emits bash in
  markdown fences. Both models lack function-calling fine-tuning. Catalogue size doesn't
  matter when the model never produces the tool_use JSON format at all.
- **Rejected:** N=5 expansion, prompt engineering, system-prompt forcing — catalogue
  hypothesis was the question; N=3 unanimous null is sufficient signal to move on.

### 2026-05-03 — qwen2.5-coder-32b:IQ2_M killed by latency on 16GB

- **Chose:** drop the loaded 32B coder model from the v2 candidate list.
- **Why:** bonus N=3 with narrow catalogue produced 3/3 timeouts at 180s. IQ2 quant +
  32B params are unusably slow on this ollama backend for a "cheap research" workflow.
- **Rejected:** wait longer per dispatch — fundamentally violates the workflow's
  performance contract. A read-and-summarize task taking >3min defeats the cost case.

### 2026-05-03 — v3 path is "pull tool-use-tuned model", not router or larger model

- **Chose:** file follow-up to pull `hermes-3:8b` (or `xlam:7b` as alternate) and re-probe.
- **Why:** function-calling-tuned 7-8B models have demonstrably emitted correct tool_use
  format in public benchmarks. claude-code-router is a heavier swap (different proxy +
  config + integration) without targeting the actual root cause (model can't emit format).
- **Rejected:** claude-code-router as next step — same wide-prompt strategy that failed on
  qwen3:14b/gpt-oss:20b in T-1700; not addressing root cause.
- **Rejected:** larger model — 70B doesn't fit 16GB, 32B IQ2 is too slow, leaving 14B as
  the ceiling. qwen2.5-coder:14b-instruct is a candidate but pull cost > hermes-3:8b.

## Recommendation

**Recommendation:** SHIP — substrate complete, catalogue-restriction path empirically closed,
v3 path documented for follow-up.

**Rationale:**
- Substrate gap closed: workflow `allowed_tools:` now plumbs through to `claude -p --tools`
  via the `--tools` flag on `fw termlink dispatch`. Mirror of T-1700's `--env` plumbing.
- Decisive empirical answer on the cheapest hypothesis: 18 dispatches, 0/18 real tool
  calls. Catalogue restriction does NOT rescue gemma4:8b or qwen3.5:9.7b. The §ACD
  honest-failure principle demands recording this so the next session doesn't re-test it.
- Failure-mode RCA points at the next experiment with a clear hypothesis ("a model
  trained for function-calling will emit the format these don't") rather than another
  catalogue tweak.

**Evidence:**
- `docs/reports/T-1703-curated-catalogue-probe.md` — full matrix + RCA + per-cell numbers
- `agents/termlink/termlink.sh` `--tools` plumbing (commit `6ca40265c`)
- `tools/t1703-probe-matrix.sh` — reusable for future model probes by editing CELLS array
- `.context/dispatches.jsonl` + `.context/dispatch-outcomes.jsonl` — outcome rows per
  dispatch (T-1697 hook captured them)

**v3 follow-up scope (separate task):**
- Pull `hermes-3:8b` (~5GB) and `xlam:7b` (~4GB).
- Re-run `tools/t1703-probe-matrix.sh` with new aliases substituted in CELLS.
- If a cell hits 90%: update `.context/project/workflows/ollama-research.yaml` model
  field and Recommendation in T-1700.
- If still no: file v4 inception (claude-code-router OR accept text-only ollama-research).

## Updates

### 2026-05-03T19:33:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1703-v2-probe-gemma4--qwen35-against-curated-.md
- **Context:** Initial task creation

### 2026-05-03T19:34:04Z — status-update [task-update-agent]
- **Change:** tags: +v2-prep

## Reviewer Verdict (v1.5)

- **Scan ID:** R-29f36d4a
- **Timestamp:** 2026-06-02T14:59:13Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — `tools/t1700-ollama-harness.sh` accepts `T1700_HARNESS_MODEL`, `T1700_HARNESS_TOOLS`,
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tools/t1700-ollama-harness.sh in: `tools/t1700-ollama-harness.sh` accepts `T1700_HARNESS_MODEL`, `T1700_HARNESS_TOOLS`,`
### 2026-05-03T20:00:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
