# T-1700 — litellm proxy v1 build (in progress)

**Anchor:** T-1700. Predecessor: T-1691 (proxy choice GO).
**Arc:** orchestrator-rethink. **Gap target:** G-064 closure (autonomous consumer of substrate).

## Summary

Built and validated litellm-proxy → ollama path for v1 dispatch substrate. Anthropic-format
requests sent at `http://localhost:4000` are translated by litellm into ollama-compatible calls
to `http://192.168.10.107:11434` and responses returned in Anthropic message format. Tool-use
shape preserved end-to-end.

## Configuration

- **Install:** `pipx install 'litellm[proxy]'` → litellm 1.83.14, Python 3.12.3
- **Proxy daemon:** `litellm --config .context/litellm-config.yaml --port 4000`
  - Logs: `.context/working/litellm/proxy.log`
  - PID: `.context/working/litellm/proxy.pid`
- **Config file:** `.context/litellm-config.yaml`
- **Workflow file:** `.context/project/workflows/ollama-research.yaml`

### Model mapping

| Anthropic model | Routed to ollama |
|---|---|
| `claude-3-5-sonnet-20241022` | `qwen3:14b` |
| `claude-3-5-sonnet` | `qwen3:14b` |
| `claude-3-5-haiku-20241022` | `gemma4:latest` |
| `claude-sonnet-coder` | `krith/qwen2.5-coder-32b-instruct:IQ2_M` |

Master key: `sk-litellm-local-dev` (local dev — must be passed in `x-api-key` or
`ANTHROPIC_API_KEY` env var).

## Smoke tests

### 1. Health
```
$ curl -sf http://localhost:4000/health/liveliness
"I'm alive!"

$ curl -sf http://localhost:4000/health/readiness
{"status":"healthy", "litellm_version":"1.83.14", ...}
```

### 2. Plain message (no tool)
- Model: `claude-3-5-sonnet-20241022` → routed to qwen3:14b
- 200-token request, response: `stop_reason: max_tokens`, hit thinking-mode token cap
- Translation works; qwen's reasoning blocks need higher token budget OR `/no_think` prefix

### 3. Tool-use (qwen3:14b through proxy)
- 2000-token request with `read_file` tool definition + `/no_think\n\n<prompt>`
- Result: `stop_reason: tool_use`
- Tool call: `read_file({"path": "/etc/hostname"})` — correct schema, correct argument
- Tokens: in=165, out=142
- **Tool-use shape preserved through Anthropic format ↔ ollama_chat translation**

### 4. Resolver envelope
```
$ bin/fw resolver dispatch T-1700 ollama-research --dry-run
dispatch_id:    eb401744-213c-41d1-adce-e40729285247
worker_kind:    TermLink
model:          claude-3-5-sonnet-20241022
prompt:         5787 chars
```

Envelope captures `env:` from workflow (resolver.py:405) but spawn-side does not yet
read it (see Integration Gap below).

## Integration Gap

The workflow's `env:` field is plumbed from YAML → resolver envelope, but
**not consumed by `fw termlink dispatch`**. `cmd_dispatch` in
`agents/termlink/termlink.sh:494` accepts `--task --name --prompt --project --timeout
--model --task-type` — no `--env` option. The spawned `claude -p` worker inherits
parent shell env only.

**Implication:** For end-to-end dispatch through ollama via litellm, the caller must set
`ANTHROPIC_BASE_URL` and `ANTHROPIC_API_KEY` in the parent shell before invoking
`fw termlink dispatch`. The workflow file documents the intent; substrate doesn't yet
enforce it.

**Resolution paths (pick one for v1):**
- (a) Add `--env KEY=VAL` (repeatable) to `fw termlink dispatch`
- (b) Add `fw dispatch run <task_id> <task_type>` that consumes resolver envelope + injects
      env + invokes termlink dispatch
- (c) Wrap with a per-workflow shell helper

T-1700 ships option (a) as the minimal change to close G-064 via this path.

## Acceptance criteria coverage

(See `.tasks/active/T-1700-*.md` ## Acceptance Criteria for full list.)

| AC group | Status |
|----------|--------|
| 1. Install + config | ✅ litellm 1.83.14 + config + proxy running |
| 2. fw doctor extensions | ⏳ pending (this commit) |
| 3. Workflow file | ✅ `ollama-research.yaml` registered, schema-valid |
| 4. Empirical harness | ⏳ pending (after env-injection patch) |
| 5. Decision gate | ⏳ pending (depends on #4) |
| 6. Env-leak test | ⏳ pending |

## Decisions

### 2026-05-03 — Install via pipx, not pip --user / system pip

- **Chose:** `pipx install 'litellm[proxy]'` → isolated venv, CLI on PATH
- **Why:** litellm is a daemon/tool, not a project library. pipx is the correct tool for this
  on Debian 12+ (PEP 668 forbids system pip). Single-binary install on `/root/.local/bin/litellm`.
- **Rejected:** project-local venv at `.venv/litellm` — adds project setup friction; the proxy
  serves all projects on this host, not just the framework repo.

### 2026-05-03 — Model mapping defaults

- **Chose:** `qwen3:14b` as primary tool-use target (mapped to all `claude-3-5-sonnet*` aliases)
- **Why:** balanced size (14.8B), tool-use validated in smoke test #3
- **Rejected at v1:** `qwen2.5-coder-32b:IQ2_M` (32B but heavily quantized) — kept as
  `claude-sonnet-coder` alias for opt-in coder workflows
- **Rejected at v1:** `gpt-oss:20b` — not yet validated; can be swapped if qwen3:14b's
  thinking-mode tokens prove problematic

## Open issues

1. qwen3:14b's `<think>` blocks consume tokens before reaching tool-use. Mitigations:
   - Increase `max_tokens` budget (cheap, works)
   - Prefix prompts with `/no_think` (qwen-specific)
   - Use `gpt-oss:20b` (no thinking mode)
   Decision deferred to harness results.

2. `fw doctor` proxy/ollama checks not yet added — captured as AC #2.
