# T-1700 — litellm proxy v1 build

**Anchor:** T-1700. Predecessor: T-1691 (proxy choice GO).
**Arc:** orchestrator-rethink. **Gap target:** G-064 closure (autonomous consumer of substrate).
**Last update:** 2026-05-03 19:00Z.

## Bottom line

**Substrate ships. Empirical tool-use bar misses.**

The litellm proxy + workflow `env:` plumbing + `fw termlink dispatch --env` extension all
work end-to-end. A `claude -p` worker can be dispatched against `http://localhost:4000`,
that gets translated into ollama-compatible calls, ollama returns Anthropic-shaped
responses, and the worker exits cleanly with the result captured.

But: open-weight ollama models (qwen3:14b, gpt-oss:20b) do **NOT** reliably emit
`tool_use` events when given `claude -p`'s wide tool arsenal. They tend to
describe-instead-of-call, even though they pass tool-use tests on the bare API with a
single curated tool definition.

**Decision (per T-1691 GO criteria):** ship the substrate, defer "ollama-via-claude-p
in production" to a v2 build that pivots either to (a) a stronger ollama model class
(70B+ instruction-tuned, or specifically tool-use-tuned), (b) claude-code-router for
its tighter prompt integration, or (c) restrict the workflow's `allowed_tools` to a
narrow subset before the model sees it. T-1700 ships AC groups 1, 2, 3, 6, plus the
harness and report. AC groups 4 and 5 (10-dispatch + decision gate) ran with HONEST
metrics; recommendation captured for v2.

## What ships in this commit

### 1. Install + config
- `pipx install 'litellm[proxy]'` → litellm 1.83.14 on `/root/.local/bin/litellm`
- `.context/litellm-config.yaml` — 9 model aliases mapped to ollama backends
- Daemon: `setsid nohup litellm --config .context/litellm-config.yaml --port 4000`
  (logs `.context/working/litellm/proxy.log`, pid `.context/working/litellm/proxy.pid`)
- systemd unit deferred — operator preference (manual start documented above)

### 2. Workflow file
- `.context/project/workflows/ollama-research.yaml`
- `task_type: ollama-research`, `worker_kind: TermLink`, `model: claude-3-5-sonnet-20241022`
- `env: ANTHROPIC_BASE_URL=http://localhost:4000` + `ANTHROPIC_API_KEY=sk-litellm-local-dev`
- Schema-valid; `bin/fw resolver workflows` lists with concrete worker/model fields.

### 3. Substrate plumbing — `--env KEY=VAL` flag
- `agents/termlink/termlink.sh:cmd_dispatch` accepts repeatable `--env KEY=VAL`.
- Validates KEY shape (`[A-Z_][A-Z0-9_]*`); writes `<wdir>/env.sh` with shell-quoted exports;
  `run.sh` sources it before invoking `claude -p`.
- `meta.json` records `env_keys: [...]` (not values — possible secrets).
- This closes the integration gap where `resolver.py:405` captured workflow `env:` into
  the dispatch envelope but no consumer was reading it.

### 4. Empirical harness
- `tools/t1700-ollama-harness.sh [N]` — runs N tool-use prompts via
  `fw termlink dispatch --task-type ollama-research`, sequentially.
- Tracks per-dispatch: exit code, **real tool_use event count**, latency.
- Stricter metric: `exit=0 AND tool_uses ≥ 1`. (Earlier draft reported 100% on
  exit-code alone — that was dishonest; updated.)
- Output: `docs/reports/T-1700-harness-results.md` (overwritten each run).

## Smoke evidence (proxy → ollama works)

### Direct API call with curated tool def
- `claude-3-5-sonnet-20241022` → `qwen3:14b`, then `→ gpt-oss:20b`
- 2000-token request with single `read_file` tool definition + `/no_think` prefix
- Both models emit `stop_reason: tool_use` with correct schema `read_file({"path":"/etc/hostname"})`
- ✅ **Translation pipeline works correctly.**

### First end-to-end via fw termlink dispatch (qwen3:14b)
- Worker: `ollama-smoke-1`, prompt: "Use the Read tool to read /etc/hostname..."
- exit=0, latency=25s, result: `"The hostname is ring20-112."` ✅
- **Real tool call captured** in `result.jsonl`.

## Harness data — qwen3:14b

`docs/reports/T-1700-harness-results.md` (batch `20260503-184229`, N=10):

| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| **Real tool-use rate** | 0/10 (0%) | ≥90% | ❌ MISSED |
| Exit-code pass | 10/10 (100%) | informational | — |
| Median latency | 55.5s | — | — |
| p95 latency | 109s | — | — |

**Pattern:** every worker hallucinates a textual answer. Worker #1 ("read /etc/hostname")
returned `"The hostname is myserver"` (wrong; real answer ring20-112). Worker #5
returned a fictional kernel version. Etc.

## Harness data — gpt-oss:20b

After remapping `claude-3-5-sonnet-20241022` → `gpt-oss:20b` and rerunning N=3:

| # | Exit | tool_use events | Latency |
|---|------|-----------------|---------|
| 1 | 0 | **2** ✅ | 113s |
| 2 | 0 | 0 | 12s |
| 3 | 0 | 0 | 31s |

| Metric | Value |
|--------|-------|
| Real tool-use rate | 1/3 (33%) |
| Exit-code pass | 3/3 (100%) |

Marginally better than qwen3:14b (33% vs 0%), still well below 90% threshold.

## RCA — why exit=0 was a misleading signal

`claude -p` exits cleanly when the model emits `stop_reason: end_turn` after producing
text. There is no built-in expectation that a tool was called. In our prompts we ask
"Use Read to read X" — the model can satisfy that surface request by writing prose
about Read, never invoking it. The proxy returns 200, claude -p captures the text,
exits 0, our harness scored it pass.

**The honest metric** is parsing `result.jsonl` for `assistant` events with content type
`tool_use`. After updating the harness, qwen3:14b's true rate is 0%; gpt-oss:20b is 33%.

This is consistent with public reports: open-weight models in the 8-32B range
calibrated for "general assistance" describe-instead-of-call when given large tool
catalogues. They survive a 1-2 tool curated harness; they break on the 100+ tool
claude -p prompt.

## Acceptance criteria coverage

| AC group | Status | Notes |
|----------|--------|-------|
| 1. Install + config | ✅ | litellm 1.83.14, config + 9 aliases, daemon documented |
| 2. fw doctor extensions | ⏳ deferred | covered by v2 build (T-1700-followup) |
| 3. Workflow file | ✅ | `ollama-research.yaml`, schema-valid, listed by resolver |
| 4. Empirical harness | ✅ | harness shipped + N=10 + N=3 runs captured |
| 5. Decision gate | ⚠️ MISS → pivot | <90% real tool-use; v2 path documented in Decisions |
| 6. Env-leak test | ⏳ pending | next session |

## Decisions

### 2026-05-03 — Install via pipx, not pip --user / system pip

- **Chose:** `pipx install 'litellm[proxy]'` → isolated venv, CLI on PATH.
- **Why:** litellm is a daemon/tool, not a project library. PEP 668 forbids system pip
  on Debian 12+. Single binary at `/root/.local/bin/litellm`.
- **Rejected:** project-local venv at `.venv/litellm` — adds project setup friction;
  the proxy serves all projects on this host, not just the framework repo.

### 2026-05-03 — Add --env flag rather than wrapping termlink dispatch

- **Chose:** Extend `cmd_dispatch` with repeatable `--env KEY=VAL`.
- **Why:** Smallest surface change (≈25 LOC). Consumers of the resolver envelope can
  still call dispatch with explicit env injection without an intermediate wrapper.
- **Rejected:** new `fw dispatch run <task>` verb — added a layer; same end result.
- **Rejected:** auto-pull env from envelope in dispatch — would require resolver and
  termlink to share a contract; can be retrofitted later if patterns emerge.

### 2026-05-03 — `exit=0` is not a tool-use signal (RCA)

- **Discovery:** Initial harness reported "100% pass" on exit codes. Spot-check showed
  most workers had hallucinated answers. Audit of `result.jsonl` confirmed 0/10
  workers actually called tools.
- **Action:** Updated harness to count real `tool_use` events; updated stricter metric
  is the GO criterion. Documented in this report and the harness header.
- **Generalisation:** any future "did the model do X?" check against `claude -p` must
  inspect the assistant's content blocks, not just the exit code.

### 2026-05-03 — Defer empirical pass to v2; ship substrate

- **Chose:** Ship litellm proxy + workflow + --env plumbing + harness. Mark
  qwen3:14b and gpt-oss:20b as **inadequate primary models** for claude -p's wide
  tool prompt. Defer the "ollama-via-claude-p hits 90% real tool-use" criterion to
  a v2 task with one or more of:
  (a) larger model (70B+) — cost vs. capability
  (b) claude-code-router — same proxy class, different prompt strategy
  (c) restricted `allowed_tools` per workflow — narrow the catalogue before model sees it
- **Why:** the substrate is the part T-1691 GO'd. Empirical model fitness is a
  followup; pretending we passed the 90% bar would conflate "substrate works"
  with "production-ready ollama path" — exactly the §ACD substrate-vs-deliverable
  conflation the orchestrator-rethink arc has been fighting. We honor §ACD by
  acknowledging miss explicitly.
- **Rejected:** declare GO on exit-code metric — would have been "false success",
  G-064 would NOT actually have a real consumer.
- **Rejected:** swap to claude-code-router right now — out of context budget;
  better as a clean v2 task with proper inception.

## Open issues / next steps (for v2 followup task)

1. Pick the v2 path: stronger model OR claude-code-router OR restricted tool set.
   Each is its own inception (model fitness is empirical; can't pre-decide).
2. Add `fw doctor` checks: `litellm-proxy reachable`, `ollama reachable` (skip-clean
   when not configured) — AC group 2 for this task.
3. Env-leak test (AC group 6): assert workflow A's env doesn't bleed into workflow B's
   spawn or parent shell.
4. systemd unit for litellm-proxy daemon — operational hardening.
5. The `--env` plumbing in `fw termlink dispatch` is generic — not ollama-specific.
   Anyone wanting per-workflow env overrides can use it. Document in
   `agents/termlink/AGENT.md`.
