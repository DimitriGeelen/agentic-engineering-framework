---
id: T-1703
name: "v2 probe: gemma4 + qwen3.5 against curated tool catalogue — cheapest path to 90% real tool-use"
description: >
  v2 probe: gemma4 + qwen3.5 against curated tool catalogue — cheapest path to 90% real tool-use

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [v2-prep]
components: []
related_tasks: []
created: 2026-05-03T19:33:36Z
last_update: 2026-05-03T19:34:04Z
date_finished: null
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
- [ ] `agents/termlink/termlink.sh` accepts `--tools <comma-list>` flag; written to
      `$wdir/tools.txt`; sourced by `run.sh` and passed as `claude -p --tools <list>`.
      Test: `bin/fw termlink dispatch --tools "Read" --prompt "..."` produces a worker
      whose `meta.json` records `tools_restricted: ["Read"]` and the spawned process
      has `--tools "Read"` in its argv (verifiable via `ps` snapshot or run.sh trace).
- [ ] `.context/litellm-config.yaml` adds two probe aliases:
      `claude-3-5-sonnet-gemma4` → `ollama_chat/gemma4:latest`
      `claude-3-5-sonnet-qwen35` → `ollama_chat/qwen3.5:latest`
      Test: `curl -sf http://localhost:4000/v1/models | jq -r '.data[].id' | grep -E "gemma4|qwen35"` returns both.
- [ ] `tools/t1700-ollama-harness.sh` accepts `T1700_HARNESS_MODEL` and `T1700_HARNESS_TOOLS`
      env vars (or equivalent CLI args), passes both through to dispatch.
      Test: `T1700_HARNESS_MODEL=claude-3-5-sonnet-gemma4 T1700_HARNESS_TOOLS="Read,Bash" tools/t1700-ollama-harness.sh 3` runs and reports the model/tools used in the report header.
- [ ] Probe matrix runs N=5 per cell on the simple-read task class:
      gemma4 × {wide, "Read,Bash,Grep", "Read"} (3 cells)
      qwen3.5 × {wide, "Read,Bash,Grep", "Read"} (3 cells)
      Total 30 dispatches. Results captured in `docs/reports/T-1703-curated-catalogue-probe.md`.
- [ ] Report includes per-cell `tool_use_pct` (real metric — exit=0 AND tool_uses≥1),
      identifies winner if any cell ≥90%, OR records honest miss with the pivot path
      (claude-code-router vs prompt engineering vs accept ollama-research as
      narrow-tool only).
- [ ] If a cell ≥90%: `.context/project/workflows/ollama-research.yaml` updated to use
      that model alias, and `bin/fw resolver workflows` confirms the change. T-1700
      Recommendation block updated with the v2 winner.
- [ ] If no cell ≥90%: pivot path captured in `## Decisions`; v3 follow-up task filed
      (claude-code-router, prompt-engineering, or model pull).

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

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-05-03T19:33:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1703-v2-probe-gemma4--qwen35-against-curated-.md
- **Context:** Initial task creation

### 2026-05-03T19:34:04Z — status-update [task-update-agent]
- **Change:** tags: +v2-prep
