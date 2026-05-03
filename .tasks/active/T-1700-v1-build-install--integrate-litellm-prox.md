---
id: T-1700
name: "v1 build: install + integrate litellm proxy for ollama-backed dispatch"
description: >
  Build follow-up to T-1691 GO. Install litellm[proxy], wire ollama-research.yaml workflow with env: ANTHROPIC_BASE_URL=http://localhost:4000, run 10 tool-use dispatches, decide >=90% pass = ship / else swap to claude-code-router. See T-1691 ## Recommendation for full 8-step scope.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc:orchestrator-rethink, proxy, litellm, ollama]
components: []
related_tasks: [T-1691, T-1696, T-1693]
created: 2026-05-03T15:46:59Z
last_update: 2026-05-03T18:26:15Z
date_finished: null
---

# T-1700: v1 build: install + integrate litellm proxy for ollama-backed dispatch

## Context

T-1691 GO decision: ship litellm as v1 default ollama proxy. This task executes the 8-step build
scope from T-1691's Recommendation block. Goal: validate that an autonomous dispatch through the
v1 substrate, hitting ollama via litellm proxy, can complete a tool-use task at ≥90% success.

Predecessors: T-1691 (proxy choice inception), T-1696 (Resolver shipped), T-1693 (workflow files
shipped). Sister build: T-1701 (pi RPC backend). G-064 (orchestrator zero-consumers) closes only
when at least one autonomous workload uses this substrate end-to-end.

ollama @ `192.168.10.107:11434` already reachable; 12 models present including
`qwen2.5-coder-32b`, `qwen3:14b`, `gpt-oss:20b` (tool-use-capable candidates).

## Acceptance Criteria

### Agent

**1. Install + config**
- [ ] `litellm[proxy]` installed (`pip3 show litellm` succeeds, version captured in Decisions).
- [ ] `.context/litellm-config.yaml` exists with at least one model mapping
      (`claude-3-5-sonnet-*` → `ollama/<chosen-model>`) targeting
      `http://192.168.10.107:11434`.
- [ ] systemd unit `deploy/litellm-proxy.service` (or fw companion) starts proxy on `:4000`
      with `--anthropic_api_format`. Either ship the unit + start manually, OR document the
      one-liner start command in `docs/reports/T-1700-litellm-build.md`.

**2. fw doctor extensions**
- [ ] `fw doctor` adds two checks (mirror T-1694 conditional pi check pattern):
      - `litellm-proxy reachable` — `curl -sf http://localhost:4000/health` (skip if proxy not configured/installed)
      - `ollama reachable` — `curl -sf http://192.168.10.107:11434/api/tags` (skip if no workflow needs it)
- [ ] Both checks SKIP cleanly (not WARN/FAIL) when the optional dep isn't installed.

**3. Workflow file**
- [ ] `lib/workflows/ollama-research.yaml` exists with:
      - `worker_kind: TermLink` (uses standard dispatch, not pi)
      - `model: claude-3-5-sonnet-20241022` (litellm config rewrites to ollama)
      - `env: ANTHROPIC_BASE_URL=http://localhost:4000`
      - schema-valid (passes `fw doctor` workflow lint Q14 from T-1694)
- [ ] `bin/fw resolver workflows` lists `ollama-research.yaml` with concrete worker/model fields
      (not `worker=?` like inline workflows).

**4. Empirical validation harness**
- [ ] `tests/integration/test_t1700_ollama_dispatch.sh` (or similar) runs 10 dispatches via
      `fw resolver dispatch <task_id> ollama-research`, each with a tool-use prompt
      (Read+Bash). Records pass/fail per run, median + p95 latency to first tool call.
- [ ] Results captured in `docs/reports/T-1700-litellm-build.md` with raw numbers.
- [ ] `dispatch-outcomes.jsonl` shows the 10 outcome rows back-propagated by the T-1697 evaluator.

**5. Decision gate**
- [ ] If ≥90% pass: workflow stays as-is, T-1700 ships GO.
- [ ] If <90% pass: pivot recorded in `## Decisions`, swap to claude-code-router (or file
      v2 inception), re-run, document. T-1691 explicitly accommodates this.

**6. Env-leak test**
- [ ] `tests/unit/test_workflow_env_isolation.bats` (or .py): workflow A sets
      `ANTHROPIC_BASE_URL=http://invalid:9999`; verify parent process env unchanged after
      dispatch returns; verify a second workflow B (no env override) hits real Anthropic API.

### Human
- [ ] [REVIEW] Latency / quality acceptable for "cheap research" use case
      **Steps:**
      1. Read `docs/reports/T-1700-litellm-build.md` results table
      2. Compare median + p95 latency vs Anthropic API baseline
      3. Spot-check 2 dispatch outputs for quality (correct tool use, sensible reasoning)
      **Expected:** Latency within 3x Anthropic baseline; outputs answer the prompt sensibly
      **If not:** Note specific failures; consider model swap (qwen3:14b → gpt-oss:20b etc.)

- [ ] [RUBBER-STAMP] Approve litellm proxy as a system service or document non-systemd start
      **Steps:**
      1. Decide: ship `deploy/litellm-proxy.service` and run `sudo systemctl enable --now litellm-proxy`,
         OR keep it as a manual one-liner in docs
      2. If systemd: verify `systemctl status litellm-proxy` shows active
      **Expected:** Reliable proxy availability matching team operational preference
      **If not:** Pick the path you prefer; substrate is agnostic

## Verification

# Install present
pip3 show litellm >/dev/null
# Config + workflow exist + valid YAML
test -f .context/litellm-config.yaml && python3 -c "import yaml; yaml.safe_load(open('.context/litellm-config.yaml'))"
test -f lib/workflows/ollama-research.yaml && python3 -c "import yaml; yaml.safe_load(open('lib/workflows/ollama-research.yaml'))"
# Workflow listed by resolver
bin/fw resolver workflows | grep -q "ollama-research"
# Ollama still reachable (sanity)
curl -sf http://192.168.10.107:11434/api/tags >/dev/null
# fw doctor still passes (no new failures)
bin/fw doctor 2>&1 | grep -E "FAIL" | grep -v "no failures" | wc -l | grep -q "^0$"
# Build report exists
test -f docs/reports/T-1700-litellm-build.md
# Outcome rows landed
test -f .context/dispatch-outcomes.jsonl && grep -q "T-1700" .context/dispatch-outcomes.jsonl

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

See full report: `docs/reports/T-1700-litellm-build.md` Decisions section.

Summary:

### 2026-05-03 — Install via pipx (not system pip)
litellm is a daemon, not a project library; PEP 668 + multi-project use → pipx.

### 2026-05-03 — `--env KEY=VAL` flag on `fw termlink dispatch` (T-1700 plumbing)
Smallest surface change to consume workflow `env:`. Validated KEY shape; injected via sourced env.sh; meta.json records env_keys (not values).

### 2026-05-03 — `exit=0` is not a tool-use signal (RCA)
Initial harness reported 100% pass on exit codes alone — that was dishonest. claude -p exits cleanly when model hallucinates text. Updated harness counts real `tool_use` events. True rates: qwen3:14b 0/10, gpt-oss:20b 1/3. Generalisation: any "did the model do X?" check against claude -p must inspect assistant content blocks, not exit codes.

### 2026-05-03 — Defer empirical pass to v2; ship substrate
Substrate (proxy, workflow, --env plumbing, harness, report) ships. The 90% real tool-use bar is missed — open-weight 8-32B models describe-instead-of-call on claude -p's wide tool prompt. Path forward: v2 task picks one of (a) ≥70B model, (b) claude-code-router, (c) restricted allowed_tools per workflow. Honoring §ACD by acknowledging the miss instead of declaring false success.

## Recommendation

**Recommendation:** SHIP-WITH-CAVEAT — substrate complete, pivot path documented for v2

**Rationale:**
The substrate work that T-1691 GO'd is complete and end-to-end verified:
- litellm proxy translates Anthropic ↔ ollama bidirectionally with tool_use shape preserved (curated 1-tool API call: 100% — 2 models tested)
- Workflow `env:` field is now plumbed through `fw termlink dispatch --env KEY=VAL` into the spawned worker (gap closed; was captured in resolver envelope but unread)
- Harness exists and is cron-runnable; produces an honest `tool_use_pct` metric

What this enables RIGHT NOW (before v2):
- Any consumer can dispatch through ollama-research workflow with full substrate plumbing.
- The first end-to-end real dispatch (qwen3:14b on simple prompt) returned the correct `"hostname is ring20-112"` — the path WORKS for narrow, well-scoped prompts.
- G-064 has its first non-synthetic substrate exercise. The substrate-vs-deliverable gap has narrowed: there's a real ollama-driven autonomous workload path, even if the model fitness for full claude -p use is a v2 question.

What FAILS (and is honestly captured):
- Wide-tool-prompt fitness: 0% (qwen3:14b) / 33% (gpt-oss:20b), well below T-1691's 90% threshold.
- Pretending we hit the bar would be exactly the §ACD substrate-vs-deliverable conflation that's defined this arc's pain. The README/handover would say "ollama-research ships v1" while real consumers would silently get hallucinated answers in production.

**Evidence:**
- `docs/reports/T-1700-litellm-build.md` — full report with model-by-model harness data, RCA on exit-code signal, four decisions captured
- `docs/reports/T-1700-harness-results.md` — latest batch (regenerated each run)
- Commit `8b7d73193` — initial config + workflow + smoke proof
- The `--env` flag commit (this commit) — substrate plumbing
- `.context/dispatches.jsonl` — all dispatch envelopes recorded
- `.context/dispatch-outcomes.jsonl` — outcome rows back-propagated by T-1697 evaluator

**v2 follow-up scope (file as separate inception → build):**
- Pick fitness path: ≥70B model | claude-code-router | restricted allowed_tools.
- AC group 2 (`fw doctor` checks) — small, can ship in same v2 task or alongside.
- AC group 6 (env-leak test) — small, can ship now or in v2.
- systemd hardening for litellm daemon.

## Updates

### 2026-05-03T15:46:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1700-v1-build-install--integrate-litellm-prox.md
- **Context:** Initial task creation

### 2026-05-03T18:26:15Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
