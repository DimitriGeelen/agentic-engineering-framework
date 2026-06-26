# T-2416 — LLM Integration Diagnosis: Ollama + OpenRouter

**Date:** 2026-06-26  
**Worker:** Diagnostic agent (read-only)  
**Scope:** Why ollama is down and why openrouter is not configured

---

## Symptom

All three LLM consumers in the framework are non-functional:
- `fw ask` CLI → "Couldn't connect" to ollama:11434
- litellm proxy (:4000) → routes all models to ollama:11434 (no openrouter fallback)
- Watchtower AI assistant → defaults to ollama, no openrouter registered

The operator reports "ollama and openrouter integration is not working."

---

## Root Cause 1 — Ollama: Restart Loop → StartLimitBurst Exhausted

### What happened (reconstructed from journal)

| Time (CEST) | Event |
|---|---|
| 23:40:59 | ollama (pid 4028663) serving requests normally; last log: `POST /api/generate` → 200 |
| 23:41:00 | `Stopping ollama.service` — operator or script ran `systemctl restart` |
| 23:41:00 | `Started ollama.service` — new instance (let's call pid C), served for ~10 s |
| 23:41:10 | pid C stopped (reason unclear; may have been a second restart call) |
| 23:41:10 | `Started ollama.service` — pid 4030842; GPU discovery fails in 170 ms; systemd SIGTERM |
| 23:41:12 | `Started ollama.service` — pid 4031359; GPU discovery fails in 229 ms; systemd SIGTERM |
| 23:41:12 | No further restart attempts — systemd entered `inactive (dead)` state |

The service has been dead for **36+ hours** (since 2026-06-24 23:41:12).

### GPU discovery failure — evidence

Logged by every restart since 23:41:10:
```
source=runner.go:464 msg="failure during GPU discovery"
  OLLAMA_LIBRARY_PATH="[/usr/local/lib/ollama /usr/local/lib/ollama/cuda_v13]"
  error="failed to finish discovery before timeout"

source=runner.go:464 msg="failure during GPU discovery"
  OLLAMA_LIBRARY_PATH="[/usr/local/lib/ollama /usr/local/lib/ollama/cuda_v12]"
  extra_envs="map[CUDA_VISIBLE_DEVICES:GPU-a025c510-9079-05b6-2833-4ade7dfa3bd4 GGML_CUDA_INIT:1]"
  error="failed to finish discovery before timeout"
```

Then CPU fallback fires:
```
source=types.go:60 msg="inference compute"
  id=cpu library=cpu compute="" total="62.7 GiB" available="41.3 GiB"
```

### GPU hardware status

- **GPU present:** NVIDIA GeForce RTX 5060 Ti (PCI `0a:00.0`, device ID `2d04 rev a1`)
- **Driver:** 570.211.01 (CUDA 12.8) — loaded, `nvidia-smi` works
- **Kernel devices:** `/dev/nvidia0`, `/dev/nvidiactl`, `/dev/nvidia-uvm` all present
- **Persistence mode:** ON
- **Current GPU consumers:** Xorg (1266 MiB), xfwm4, Signal, Chrome, Docker Desktop (2339 MiB total)

### Why GPU discovery times out

The RTX 5060 Ti uses the **Blackwell architecture (GB206, sm_120)**. This GPU was released in 2025.
Ollama 0.21.2's bundled CUDA libraries:
- `cuda_v12/`: libcudart.so.12.8.90, libcublas.so.12.8.5.5, libcublasLt.so.12.8.5.5
- `cuda_v13/`: libcudart.so.13.0.96 (forward-looking pre-release bundle)

The sm_120 compute target is new enough that CUDA library initialization inside the `ollama runner`
subprocess takes **longer than ollama's built-in discovery timeout**. The CUDA driver itself
(570.211.01 / CUDA 12.8) is recent enough to support sm_120, but the ollama runner subprocess
times out before libcublas completes its device probe.

**Note:** When pid 4028663 WAS running successfully, it was also presumably using CPU-only
(or had GPU working under a different CUDA state). The critical change at 23:41:00 was the
restart that triggered the GPU probe in the new process environment (with Xorg and other
processes already holding 2.3 GiB of VRAM).

### Why CPU fallback doesn't save the service

After GPU discovery fails, ollama logs `inference compute id=cpu` and `vram-based default context`
— it DID establish a CPU fallback. However:

1. During discovery (170–229 ms), systemd issued **SIGTERM** to the new instance.
2. This SIGTERM was triggered because the startup cycle from the prior instance (pid C, 10s)
   had counted as another rapid failure in systemd's restart-rate window.
3. Ollama caught SIGTERM, ran cleanup (CPU fallback code executed during shutdown), then
   exited cleanly with `code=exited, status=0/SUCCESS`.
4. After 3–4 rapid exits within ~12 seconds, systemd exhausted `StartLimitBurst=5`
   (or an internal threshold) and stopped retrying.

**The service did NOT crash** — it was killed by systemd's restart-rate protection.

### Current systemd state

```
Active: inactive (dead)
Duration: 229ms  (last instance)
Main PID: 4031359 (code=exited, status=0/SUCCESS)
NRestarts: 0   (no current retry in progress)
StartLimitBurst: 5
```

`systemctl start ollama` will attempt a fresh start, but it will fail again in the same 229 ms
loop **unless the underlying GPU discovery issue is fixed first**.

---

## Root Cause 2 — OpenRouter: API Key Missing on All Paths

### Watchtower web/llm lane (`web/llm/manager.py`)

The manager initializes at `web/llm/manager.py:78` and registers providers:

```python
# web/llm/manager.py:109
api_key = os.environ.get("OPENROUTER_API_KEY", "")

# web/llm/manager.py:112–117 (T-378 Fernet encrypted store)
if not api_key:
    try:
        from web.secrets_store import get_api_key
        api_key = get_api_key("openrouter") or ""
    except ImportError:
        pass

if api_key:
    _manager.register(OpenRouterProvider(api_key=api_key))  # ← never reached
```

Evidence that neither path has a key:
- `OPENROUTER_API_KEY` is **not set** in the process environment (confirmed: `env | grep OPENROUTER` = empty)
- `.context/secrets/` directory **does not exist** — no encrypted key store initialized
- `FW_LLM_PROVIDER` env var also unset — default active provider remains `"ollama"`

Result: `OpenRouterProvider` is never registered. The Watchtower AI assistant errors on every
chat request when `OllamaProvider.is_available()` returns False.

### litellm proxy lane (`.context/litellm-config.yaml`)

The config has **zero openrouter routes**. ALL 10 model aliases route to `ollama_chat/...`:

```yaml
- model_name: claude-3-5-sonnet-20241022
  litellm_params:
    model: ollama_chat/gpt-oss:20b
    api_base: http://192.168.10.107:11434   # ← dead

- model_name: claude-haiku-4-5-20251001
  litellm_params:
    model: ollama_chat/gemma4:latest
    api_base: http://192.168.10.107:11434   # ← dead
# ... all 10 aliases same pattern
```

When ollama is down, litellm returns 502 on every model call. No fallback, no openrouter alias.

### `fw ask` / `lib/ask.py` lane

```python
# lib/ask.py:27,61
import ollama
response = ollama.chat(model=model, messages=[...])
```

This is a **direct Python ollama library call** — not through litellm, not through the web/llm
abstraction. There is no openrouter path here at all. When ollama:11434 is down, `fw ask` raises
`ollama.ResponseError` immediately.

---

## Which Consumer the Operator Means

Three distinct surfaces, all broken:

| Surface | How it calls LLM | Openrouter path? |
|---|---|---|
| `fw ask` (CLI) | Direct `ollama.chat()` via Python lib | None |
| `fw resolver dispatch` workers | litellm proxy `:4000` → `ollama_chat/` | None in current config |
| Watchtower AI assistant | `web/llm/manager.py` → OllamaProvider | Exists in code, but no key registered |

**Assessment:** The operator most likely means the Watchtower AI assistant (visible UI) **and/or**
the dispatcher lane (which they may have observed failing in `fw resolver run` output). Both
`fw ask` failures and litellm failures are also consistent with the symptom. All share the same
root cause: ollama is down and openrouter is unconfigured.

---

## Remediation Plan

### Step 1 — Reset systemd restart-failure state (OPERATOR-OWNED)

The service is marked failed. Before starting, reset the counter:
```bash
cd /opt/999-Agentic-Engineering-Framework && sudo systemctl reset-failed ollama
```

### Step 2 — Fix ollama GPU discovery (choose one; OPERATOR-OWNED)

**Option A — Quick: Force CPU-only mode via drop-in env** (no upgrade needed)

Add `CUDA_VISIBLE_DEVICES=` to the existing drop-in at
`/etc/systemd/system/ollama.service.d/lan.conf`:

```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="CUDA_VISIBLE_DEVICES="
```

Then reload and start:
```bash
sudo systemctl daemon-reload && sudo systemctl start ollama
```

The machine has 41.3 GiB free RAM. All loaded models (gpt-oss:20b, gemma4, qwen3, hermes3)
will run on CPU. Inference will be slower than GPU, but the service will be stable.

**Option B — Preferred: Upgrade ollama for Blackwell support**

Newer ollama versions have improved RTX 5060 Ti / sm_120 support and a longer GPU discovery
timeout. The install script replaces in-place:
```bash
curl -fsSL https://ollama.com/install.sh | sudo sh
sudo systemctl start ollama
```

After upgrade, check the journal immediately:
```bash
journalctl -u ollama -f
```
If GPU discovery still times out, fall back to Option A.

### Step 3 — Configure OpenRouter API key (OPERATOR-OWNED for the key itself)

The operator must provide the key. Two storage paths are supported:

**Path A — Environment variable** (simplest; set in the Watchtower / litellm startup environment):
```bash
export OPENROUTER_API_KEY="sk-or-v1-..."
```
For persistence, add to the systemd unit that starts Watchtower (or the `claude-fw` environment).

**Path B — Fernet encrypted store** (for the Watchtower lane; survives env resets):
Once Watchtower is running, navigate to the Secrets page or use the CLI:
```python
# One-time setup (run from PROJECT_ROOT):
from web.secrets_store import set_api_key
set_api_key("openrouter", "sk-or-v1-...")
```
This creates `.context/secrets/api-keys.enc` (machine-bound encryption).

After the key is set, `web/llm/manager.py` will auto-register `OpenRouterProvider` on next
Watchtower startup. No code changes needed.

### Step 4 — Add openrouter routes to litellm config (AGENT-FIXABLE)

The litellm proxy needs openrouter model aliases added to `.context/litellm-config.yaml`.
This edit can be done by an agent once the API key is confirmed present in the litellm
process environment. Example addition:

```yaml
  # OpenRouter fallback aliases (requires OPENROUTER_API_KEY in litellm env)
  - model_name: claude-3-5-sonnet-20241022-openrouter
    litellm_params:
      model: openrouter/anthropic/claude-3.5-sonnet
      api_key: "os.environ/OPENROUTER_API_KEY"

  - model_name: claude-haiku-4-5-20251001-openrouter
    litellm_params:
      model: openrouter/anthropic/claude-haiku-4-5
      api_key: "os.environ/OPENROUTER_API_KEY"
```

The litellm proxy must then be restarted to pick up the new config:
```bash
pkill -f "litellm --config" && litellm --config .context/litellm-config.yaml --port 4000 &
```

**Note:** If the intent is to use openrouter as a fallback when ollama is down (rather than a
parallel route), consider litellm's `fallback_models` feature or a router config. That would be
a separate agent-fixable task.

### Step 5 — Verify (OPERATOR-OWNED)

After Steps 1–4:
```bash
# Ollama health
curl -sf http://192.168.10.107:11434/api/tags | python3 -c "import sys,json; print(json.load(sys.stdin)['models'][0]['name'])"

# litellm health
curl -sf http://localhost:4000/health | python3 -c "import sys,json; print(json.load(sys.stdin))"

# fw ask
cd /opt/999-Agentic-Engineering-Framework && bin/fw ask "hello"
```

---

## Open Questions

1. **What triggered the initial `systemctl restart` at 23:41:00?** Was it manual, a cron, or a
   watchdog? If a watchdog, it may restart ollama again and hit the same GPU discovery loop.
   Check: `journalctl --since "2026-06-24 23:40:55" --until "2026-06-24 23:41:02"` for the
   initiating event (outside the ollama unit's own log).

2. **Did ollama EVER use the GPU on this machine?** If pid 4028663 was CPU-only too, the GPU
   discovery was always failing quietly but the service started. The change at 23:41:00 may have
   introduced the rapid-timeout that now trips the restart loop. This would suggest Option A
   (CPU-only drop-in) is the correct long-term config, not a workaround.

3. **Is openrouter intended to be a replacement for ollama or a fallback?** The litellm config
   could route some model aliases to openrouter (for capability reasons) and keep others
   on ollama. Clarifying this determines whether to add parallel routes or failover routes.

4. **Should `fw ask` get an openrouter path?** Currently `lib/ask.py` is hard-wired to the
   `ollama` Python library (no litellm, no openrouter). If ollama availability is expected to be
   unreliable, `fw ask` needs a refactor to route through the litellm proxy or the `web/llm`
   abstraction instead. This would be a separate build task.
