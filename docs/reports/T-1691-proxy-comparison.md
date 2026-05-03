# T-1691 Research Artifact — Ollama proxy comparison

**Status:** in-progress (2026-05-03) — paper comparison; empirical validation deferred to v1 build
**Workflow type:** inception
**Arc:** orchestrator-rethink

## A-3 validated empirically

Ollama at `192.168.10.107:11434` IS reachable from the framework anchor host:

```
$ curl -sf http://192.168.10.107:11434/api/tags | jq '.models[].name'
"gemma4:latest"
"qwen3.5:latest"
"qwen3:14b"
"gpt-oss:20b"
"krith/qwen2.5-coder-32b-instruct:IQ2_M"
"dolph3:latest"
... (12 total)
```

Tool-use-capable candidates: `qwen2.5-coder-32b`, `gpt-oss:20b`, `qwen3:14b`.

## A-1 / A-2 / A-4 — paper comparison

| Dimension | litellm | claude-code-router | claude-bridge |
|-----------|---------|-------------------|---------------|
| Maturity | mature (5K+ stars, 2023+) | newer (2024+, focused) | newer (2024+) |
| Anthropic-format inbound | yes (`--anthropic_api_format`) | yes (its raison d'être) | yes |
| Ollama backend | first-class | first-class | first-class |
| Tool-use translation | documented; well-tested | designed for Claude Code's tool schemas | unknown — sparse docs |
| Install footprint | `pip install litellm` (~50MB w/ deps) | npm package | npm package |
| Per-request model routing | yes (config.yaml) | yes (model rules) | yes |
| Self-hosted proxy server | `litellm --model X --port Y` | similar | similar |
| Prior art in our context | mentioned in CONTEXT.md as the "default" candidate | designed specifically for Claude Code use case | least-known |
| Failure mode if tool-use breaks | model gets prompt; no tool calls fire | likely the same | likely the same |

## Recommendation: litellm for v1 default, with a fallback escape-hatch

**Rationale:**
1. **Maturity:** litellm has the largest user base + longest production history. If it has a tool-use translation bug, it has a community to file against. claude-code-router's tighter focus is appealing but its smaller community = longer time-to-fix.
2. **Generality:** litellm fronts 100+ providers, not just ollama. v1's `env: ANTHROPIC_BASE_URL` redirect can later point at the same litellm instance to reach OpenAI/OpenRouter/Groq/etc. — single proxy, multiple backends. Picking litellm makes the substrate forward-compatible without further design.
3. **Install path is well-documented.** `pip install litellm[proxy]` then `litellm --model ollama/qwen2.5-coder-32b --host 192.168.10.107:11434 --port 4000 --anthropic_api_format`.
4. **Failure escape:** workflow `env:` is per-workflow. If litellm fails on a specific task_type, the operator points THAT workflow at claude-code-router or claude-bridge without changing the rest. The substrate doesn't lock in the proxy choice.

## Empirical validation deferred

The four GO criteria explicitly require runtime evidence (tool-use ≥90% success rate, latency <2× raw, env-redirect propagation, `fw doctor` integration). Doing this on the framework anchor in this session would require:
1. `pip install litellm[proxy]` + start daemon
2. `npm install -g @anthropic/claude-code-router` (or equivalent)
3. `npm install claude-bridge`
4. Run a representative tool-use dispatch through each (3× — and each requires a Claude Code-compatible test harness)
5. Measure latency over 10 dispatches each
6. Validate `env:` propagation via `claude -p` env-merge

That's a **half-session of empirical work**, not a paper inception. Doing it half-way would produce a recommendation no more valuable than the paper version.

**Proposed:** v1 build task validates litellm empirically. If litellm fails the GO criteria, the build task pivots to claude-code-router (next most-likely candidate). The substrate ships either way.

## A-2 (env-redirect propagation) — substrate validation

This is independent of which proxy we pick. The Resolver (T-1689) constructs the Delegation envelope's `env` map from the workflow file's `env:` block; `claude -p` is invoked via `subprocess.run(..., env={**os.environ, **envelope_env})`. The parent's `ANTHROPIC_BASE_URL` is unchanged because we don't mutate `os.environ`. This is standard subprocess hygiene. Spike during v1 build can verify with a 3-line test (set `ANTHROPIC_BASE_URL=foo` in workflow → spawn → echo `$ANTHROPIC_BASE_URL` → assert `foo`; assert parent's env unchanged).

## fw doctor integration

Two checks (defer to v1 build):
1. **Proxy reachable:** `curl -sf http://localhost:4000/health` → OK / WARN if any workflow uses `env: ANTHROPIC_BASE_URL=http://localhost:4000` and proxy is down
2. **Ollama reachable:** `curl -sf http://192.168.10.107:11434/api/tags` → INFO if no workflow needs ollama, WARN if at least one does and it's unreachable

Pattern matches T-1694's pi-installed conditional check.
