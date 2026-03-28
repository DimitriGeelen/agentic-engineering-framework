# OpenRouter API Research & LLM Abstraction Layer Design

## 1. OpenRouter API Analysis

### 1.1 OpenAI Compatibility

**YES — fully OpenAI-compatible.** OpenRouter is a drop-in replacement:

```python
from openai import OpenAI

client = OpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key=os.environ["OPENROUTER_API_KEY"],
    extra_headers={
        "HTTP-Referer": "https://watchtower.example.com",
        "X-Title": "Watchtower",
    }
)
```

- Base URL: `https://openrouter.ai/api/v1`
- Auth: `Authorization: Bearer <OPENROUTER_API_KEY>`
- Request format: identical to OpenAI `/v1/chat/completions`
- The `openai` Python SDK works directly — just change `base_url`

### 1.2 Streaming Format

**SSE (Server-Sent Events)** — same as OpenAI:

- Enable with `stream=True` in the request
- Each chunk has `choices[0].delta.content` for tokens
- OpenRouter occasionally sends `: OPENROUTER PROCESSING` SSE comments to prevent timeouts (safe to ignore per SSE spec)
- Final chunk includes `usage` statistics (prompt_tokens, completion_tokens, total_tokens)
- Mid-stream errors include an `error` field at the top level of the chunk

### 1.3 Model Listing

**Endpoint:** `GET https://openrouter.ai/api/v1/models`

**Query parameters:**
- `category`: Filter by use case (programming, roleplay, marketing, technology, science, etc.)
- `supported_parameters`: Filter by parameter support

**Response per model:**
- `id`, `name`, `canonical_slug`, `description`
- `context_length`, `architecture` (tokenizer, modalities)
- `pricing` object with: `prompt`, `completion`, `request`, `image`, `image_token`, `internal_reasoning`
- `supported_parameters`, `default_parameters`

**Pricing is per-token in USD.** We CAN show estimated cost per query.

### 1.4 Reasoning/Thinking Support

**YES — OpenRouter has a unified `reasoning` parameter:**

```python
response = client.chat.completions.create(
    model="anthropic/claude-sonnet-4.5",
    messages=[...],
    extra_body={
        "reasoning": {
            "effort": "high",        # xhigh, high, medium, low, minimal, none
            # OR
            "max_tokens": 2000,      # for Anthropic/Gemini/Qwen
            "exclude": False,        # hide reasoning from response
        }
    }
)
```

- **Effort-based** (OpenAI o1/o3, Grok): uses `effort` levels
- **Max-tokens-based** (Anthropic Claude, Gemini, Qwen): uses `max_tokens`
- OpenRouter auto-maps between them
- In streaming: reasoning appears in `choices[].delta.reasoning_details`
- `:thinking` model variants (e.g. `anthropic/claude-3.7-sonnet:thinking`) enable reasoning by default

### 1.5 Rate Limiting

- **Free models:** 20 req/min, 50 req/day (<10 credits purchased), 1000 req/day (≥10 credits)
- **Paid models:** Provider-dependent limits
- **Headers returned:** `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`
- **429 Too Many Requests** on rate limit exceeded

### 1.6 Error Format

```json
{
  "error": {
    "code": 429,
    "message": "Rate limit exceeded",
    "metadata": { "provider": "...", "raw": "..." }
  }
}
```

### 1.7 Cost Tracking

Response `usage` object includes:
- `prompt_tokens`, `completion_tokens`, `total_tokens`
- `cost` — actual credit cost
- `cost_details` — breakdown by upstream provider

---

## 2. Embeddings Analysis

### 2.1 OpenRouter Embeddings API

**YES — OpenRouter supports embeddings:**

- **Endpoint:** `POST https://openrouter.ai/api/v1/embeddings`
- **Format:** OpenAI-compatible (same request/response schema)
- **Models available:** `openai/text-embedding-3-small`, `openai/text-embedding-3-large`, `qwen/qwen3-embedding-0.6b`, `google/gemini-embedding-001`, etc.
- **Multimodal:** Some models support image+text embeddings

### 2.2 Embedding Strategy Recommendation

**Option A (Recommended): Dual-Provider Approach**
- Keep Ollama for embeddings (nomic-embed-text-v2-moe) — it's local, free, fast, no API key needed
- Use OpenRouter for chat completions — access to premium models
- Rationale: Embedding quality from nomic-embed-text-v2-moe is excellent for this use case, and local embeddings avoid network latency for index building (hundreds of calls)

**Option B: Full OpenRouter**
- Use OpenRouter for both chat and embeddings
- Pro: Single provider, simpler config
- Con: Cost for embeddings (index rebuild = hundreds of embedding calls), network dependency for local-only use

**Recommendation: Option A.** The abstraction layer should support embedding providers separately from chat providers, but the default config keeps Ollama for embeddings.

---

## 3. Proposed LLM Abstraction Layer

### 3.1 Provider Interface

```python
"""web/llm/provider.py — LLM Provider abstraction layer."""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Generator, Optional


@dataclass
class ModelInfo:
    """Metadata about an available model."""
    id: str
    name: str
    context_length: int
    supports_reasoning: bool = False
    cost_per_prompt_token: float = 0.0    # USD per token
    cost_per_completion_token: float = 0.0
    provider: str = ""


@dataclass
class StreamChunk:
    """Normalized streaming chunk from any provider."""
    type: str  # "token", "thinking", "thinking_done", "error", "done", "usage"
    content: str = ""
    usage: Optional[dict] = None  # {prompt_tokens, completion_tokens, total_tokens, cost}


class LLMProvider(ABC):
    """Abstract interface for LLM providers."""

    @abstractmethod
    def chat_stream(
        self,
        model: str,
        messages: list[dict],
        thinking: bool = False,
    ) -> Generator[StreamChunk, None, None]:
        """Stream a chat completion response.

        Args:
            model: Model identifier (provider-specific)
            messages: List of {role, content} message dicts
            thinking: Whether to enable reasoning/thinking mode

        Yields:
            StreamChunk objects with normalized type/content
        """
        ...

    @abstractmethod
    def list_models(self) -> list[ModelInfo]:
        """List available models from this provider."""
        ...

    @abstractmethod
    def is_available(self) -> bool:
        """Check if the provider is reachable and configured."""
        ...

    @property
    @abstractmethod
    def name(self) -> str:
        """Human-readable provider name."""
        ...
```

### 3.2 Ollama Provider

```python
"""web/llm/ollama_provider.py — Ollama implementation."""

import ollama
from web.llm.provider import LLMProvider, ModelInfo, StreamChunk


class OllamaProvider(LLMProvider):

    def __init__(self, host: str = "http://localhost:11434"):
        self._host = host
        # Configure ollama client if host differs from default
        if host != "http://localhost:11434":
            self._client = ollama.Client(host=host)
        else:
            self._client = ollama

    @property
    def name(self) -> str:
        return "Ollama"

    def is_available(self) -> bool:
        try:
            self._client.list()
            return True
        except Exception:
            return False

    def list_models(self) -> list[ModelInfo]:
        try:
            resp = self._client.list()
            return [
                ModelInfo(
                    id=m.model,
                    name=m.model,
                    context_length=0,  # Ollama doesn't expose this in list
                    supports_reasoning="qwen3" in m.model.lower()
                        or "thinking" in m.model.lower(),
                    provider="ollama",
                )
                for m in resp.models
            ]
        except Exception:
            return []

    def chat_stream(self, model, messages, thinking=False):
        try:
            response = self._client.chat(
                model=model,
                messages=messages,
                stream=True,
                think=thinking,
            )
            in_thinking = thinking
            for chunk in response:
                msg = chunk.get("message", {})

                # Thinking tokens (Qwen3/Ollama)
                thinking_token = msg.get("thinking", "")
                if thinking_token:
                    yield StreamChunk(type="thinking", content=thinking_token)
                    continue

                # Answer tokens
                token = msg.get("content", "")
                if token:
                    if in_thinking:
                        in_thinking = False
                        yield StreamChunk(type="thinking_done")
                    yield StreamChunk(type="token", content=token)

                if chunk.get("done"):
                    # Extract usage if available
                    usage = {}
                    if "eval_count" in chunk:
                        usage = {
                            "prompt_tokens": chunk.get("prompt_eval_count", 0),
                            "completion_tokens": chunk.get("eval_count", 0),
                            "total_tokens": chunk.get("prompt_eval_count", 0)
                                + chunk.get("eval_count", 0),
                            "cost": 0.0,  # Ollama is free
                        }
                    yield StreamChunk(type="done", usage=usage or None)
                    return

        except Exception as e:
            yield StreamChunk(type="error", content=str(e))
```

### 3.3 OpenRouter Provider

```python
"""web/llm/openrouter_provider.py — OpenRouter implementation."""

import json
import logging
from openai import OpenAI
from web.llm.provider import LLMProvider, ModelInfo, StreamChunk

log = logging.getLogger(__name__)


class OpenRouterProvider(LLMProvider):

    def __init__(self, api_key: str, site_url: str = "", site_name: str = "Watchtower"):
        self._api_key = api_key
        self._client = OpenAI(
            base_url="https://openrouter.ai/api/v1",
            api_key=api_key,
            default_headers={
                "HTTP-Referer": site_url,
                "X-Title": site_name,
            },
        )
        self._models_cache: list[ModelInfo] | None = None

    @property
    def name(self) -> str:
        return "OpenRouter"

    def is_available(self) -> bool:
        if not self._api_key:
            return False
        try:
            # Lightweight check — list models
            self._client.models.list()
            return True
        except Exception:
            return False

    def list_models(self) -> list[ModelInfo]:
        if self._models_cache is not None:
            return self._models_cache

        try:
            response = self._client.models.list()
            models = []
            for m in response.data:
                pricing = getattr(m, "pricing", {}) or {}
                # pricing values are strings of USD per token
                prompt_cost = float(pricing.get("prompt", "0") or "0")
                completion_cost = float(pricing.get("completion", "0") or "0")

                models.append(ModelInfo(
                    id=m.id,
                    name=getattr(m, "name", m.id),
                    context_length=getattr(m, "context_length", 0) or 0,
                    supports_reasoning=":thinking" in m.id
                        or "reasoning" in (getattr(m, "supported_parameters", []) or []),
                    cost_per_prompt_token=prompt_cost,
                    cost_per_completion_token=completion_cost,
                    provider="openrouter",
                ))
            self._models_cache = models
            return models
        except Exception as e:
            log.warning("Failed to list OpenRouter models: %s", e)
            return []

    def chat_stream(self, model, messages, thinking=False):
        try:
            kwargs = {
                "model": model,
                "messages": messages,
                "stream": True,
            }
            if thinking:
                kwargs["extra_body"] = {
                    "reasoning": {"effort": "high"}
                }

            response = self._client.chat.completions.create(**kwargs)
            in_thinking = thinking

            for chunk in response:
                choice = chunk.choices[0] if chunk.choices else None
                if not choice:
                    continue

                delta = choice.delta

                # Check for reasoning content
                reasoning = getattr(delta, "reasoning_details", None) or \
                            getattr(delta, "reasoning", None) or \
                            getattr(delta, "reasoning_content", None)
                if reasoning:
                    # reasoning_details is a list of dicts with 'content'
                    if isinstance(reasoning, list):
                        for r in reasoning:
                            if isinstance(r, dict) and r.get("content"):
                                yield StreamChunk(
                                    type="thinking",
                                    content=r["content"]
                                )
                    elif isinstance(reasoning, str):
                        yield StreamChunk(type="thinking", content=reasoning)
                    continue

                # Regular content tokens
                content = delta.content if delta.content else ""
                if content:
                    if in_thinking:
                        in_thinking = False
                        yield StreamChunk(type="thinking_done")
                    yield StreamChunk(type="token", content=content)

                # Check for finish
                if choice.finish_reason:
                    usage = None
                    if hasattr(chunk, "usage") and chunk.usage:
                        u = chunk.usage
                        usage = {
                            "prompt_tokens": u.prompt_tokens or 0,
                            "completion_tokens": u.completion_tokens or 0,
                            "total_tokens": u.total_tokens or 0,
                            "cost": getattr(u, "cost", None),
                        }
                    yield StreamChunk(type="done", usage=usage)
                    return

        except Exception as e:
            yield StreamChunk(type="error", content=str(e))
```

### 3.4 Provider Manager

```python
"""web/llm/manager.py — Provider registry and hot-switching."""

import logging
from web.llm.provider import LLMProvider, ModelInfo

log = logging.getLogger(__name__)


class ProviderManager:
    """Manages LLM providers with hot-switching support."""

    def __init__(self):
        self._providers: dict[str, LLMProvider] = {}
        self._active_chat_provider: str = ""
        self._active_model: str = ""

    def register(self, name: str, provider: LLMProvider) -> None:
        """Register a provider by name."""
        self._providers[name.lower()] = provider

    def set_active(self, provider_name: str, model: str) -> None:
        """Switch active provider and model. Takes effect immediately (hot-switch)."""
        key = provider_name.lower()
        if key not in self._providers:
            raise ValueError(f"Unknown provider: {provider_name}")
        self._active_chat_provider = key
        self._active_model = model
        log.info("Switched to %s / %s", provider_name, model)

    @property
    def active_provider(self) -> LLMProvider:
        return self._providers[self._active_chat_provider]

    @property
    def active_model(self) -> str:
        return self._active_model

    def list_providers(self) -> list[dict]:
        """List registered providers with availability status."""
        return [
            {
                "name": p.name,
                "key": key,
                "available": p.is_available(),
                "active": key == self._active_chat_provider,
            }
            for key, p in self._providers.items()
        ]

    def list_models(self, provider_name: str = "") -> list[ModelInfo]:
        """List models for a specific provider or the active one."""
        key = provider_name.lower() if provider_name else self._active_chat_provider
        if key not in self._providers:
            return []
        return self._providers[key].list_models()
```

---

## 4. Migration Plan

### 4.1 File Changes

#### New Files
```
web/llm/__init__.py          # Package init, exports get_provider_manager()
web/llm/provider.py          # Abstract LLMProvider interface + dataclasses
web/llm/ollama_provider.py   # OllamaProvider implementation
web/llm/openrouter_provider.py  # OpenRouterProvider implementation
web/llm/manager.py           # ProviderManager (registry, hot-switching)
```

#### Modified Files

**`web/config.py`** — Add OpenRouter config:
```python
class Config:
    # -- Ollama (existing) -----------------------------------------------
    OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
    PRIMARY_MODEL = os.environ.get("FW_PRIMARY_MODEL", "qwen3:14b")
    FALLBACK_MODEL = os.environ.get("FW_FALLBACK_MODEL", "dolphin-llama3:8b")
    EMBEDDING_MODEL = os.environ.get("FW_EMBEDDING_MODEL", "nomic-embed-text-v2-moe")
    RERANKER_MODEL = os.environ.get("FW_RERANKER_MODEL", "dengcao/Qwen3-Reranker-0.6B")

    # -- LLM Provider (NEW) ---------------------------------------------
    LLM_PROVIDER = os.environ.get("FW_LLM_PROVIDER", "ollama")  # "ollama" or "openrouter"
    LLM_MODEL = os.environ.get("FW_LLM_MODEL", "")  # Override model; empty = use PRIMARY_MODEL

    # -- OpenRouter (NEW) ------------------------------------------------
    OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
    OPENROUTER_DEFAULT_MODEL = os.environ.get(
        "FW_OPENROUTER_MODEL", "anthropic/claude-sonnet-4"
    )
    OPENROUTER_SITE_URL = os.environ.get("FW_OPENROUTER_SITE_URL", "")
    OPENROUTER_SITE_NAME = os.environ.get("FW_OPENROUTER_SITE_NAME", "Watchtower")

    # -- Embedding Provider (NEW, separate from chat) --------------------
    EMBEDDING_PROVIDER = os.environ.get("FW_EMBEDDING_PROVIDER", "ollama")
```

**`web/ask.py`** — Replace direct `ollama` calls with provider abstraction:

```python
"""LLM-assisted Q&A for Watchtower search — provider-agnostic."""

import json
import logging
import re

from web.config import Config
from web.llm import get_provider_manager

log = logging.getLogger(__name__)

# (keep SYSTEM_PROMPT, format_rag_context, should_think unchanged)

def get_model() -> str:
    """Get current active model from provider manager."""
    mgr = get_provider_manager()
    return mgr.active_model

def stream_answer(query, chunks, history=None):
    """Generator yielding SSE events — now provider-agnostic."""
    mgr = get_provider_manager()
    provider = mgr.active_provider
    model = mgr.active_model

    use_thinking = should_think(query)  # complexity classifier stays the same
    context = format_rag_context(chunks)
    user_message = f"{context}\n\n## Question\n\n{query}"

    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    MAX_HISTORY_TURNS = 6
    if history:
        for msg in history[-MAX_HISTORY_TURNS:]:
            role = msg.get("role", "")
            content = msg.get("content", "")
            if role in ("user", "assistant") and content:
                messages.append({"role": role, "content": content})
    messages.append({"role": "user", "content": user_message})

    yield f"data: {json.dumps({'type': 'model', 'model': model, 'thinking': use_thinking, 'provider': provider.name})}\n\n"

    try:
        for chunk in provider.chat_stream(model, messages, thinking=use_thinking):
            if chunk.type == "thinking":
                yield f"data: {json.dumps({'type': 'thinking', 'content': chunk.content})}\n\n"
            elif chunk.type == "thinking_done":
                yield f"data: {json.dumps({'type': 'thinking_done'})}\n\n"
            elif chunk.type == "token":
                yield f"data: {json.dumps({'type': 'token', 'content': chunk.content})}\n\n"
            elif chunk.type == "error":
                yield f"data: {json.dumps({'type': 'error', 'message': chunk.content})}\n\n"
                return
            elif chunk.type == "done":
                if chunk.usage:
                    yield f"data: {json.dumps({'type': 'usage', 'usage': chunk.usage})}\n\n"
                break
    except Exception as e:
        log.error("LLM streaming error: %s", e)
        yield f"data: {json.dumps({'type': 'error', 'message': f'LLM error: {e}'})}\n\n"
        return

    # Sources (unchanged)
    sources = [...]  # same as current
    yield f"data: {json.dumps({'type': 'sources', 'sources': sources})}\n\n"
    yield f"data: {json.dumps({'type': 'done'})}\n\n"
```

**`web/embeddings.py`** — Minimal change (keep Ollama for embeddings):
```python
# UNCHANGED — embeddings stay on Ollama
# The _embed() function continues to use ollama.embed() directly
# Rationale: embeddings are local, free, fast, and the index rebuild
# involves hundreds of calls that would be expensive via cloud API
```

### 4.2 New API Endpoints (Flask)

```python
# In a new or existing blueprint:

@bp.route("/api/llm/providers", methods=["GET"])
def list_providers():
    """List available LLM providers."""
    mgr = get_provider_manager()
    return jsonify(mgr.list_providers())

@bp.route("/api/llm/models", methods=["GET"])
def list_models():
    """List models for a provider."""
    provider = request.args.get("provider", "")
    mgr = get_provider_manager()
    models = mgr.list_models(provider)
    return jsonify([{
        "id": m.id,
        "name": m.name,
        "context_length": m.context_length,
        "supports_reasoning": m.supports_reasoning,
        "cost_prompt": m.cost_per_prompt_token,
        "cost_completion": m.cost_per_completion_token,
    } for m in models])

@bp.route("/api/llm/switch", methods=["POST"])
def switch_provider():
    """Hot-switch provider and model."""
    data = request.json
    mgr = get_provider_manager()
    mgr.set_active(data["provider"], data["model"])
    return jsonify({"status": "ok", "provider": data["provider"], "model": data["model"]})
```

---

## 5. Hot-Switching Feasibility

### Can we change provider without server restart?

**YES.** The design supports hot-switching because:

1. **No module-level state:** The provider manager holds the active provider reference, not a module-level import
2. **Per-request resolution:** `stream_answer()` calls `get_provider_manager().active_provider` on each request
3. **Thread safety:** Flask's request model (one thread per request) means switching between requests is safe. The `set_active()` call is atomic (two variable assignments)
4. **No connection pools to drain:** OpenAI SDK creates connections per-request; Ollama has no persistent connection

**Hot-switch flow:**
1. User selects new provider/model in Watchtower UI
2. Frontend calls `POST /api/llm/switch`
3. ProviderManager updates active provider + model
4. Next `/search/ask` request uses the new provider
5. No restart, no downtime

**Edge case:** If a streaming response is in-flight when the switch happens, it continues on the old provider (correct behavior — the generator already holds a reference to the provider object).

---

## 6. Implementation Phases

### Phase 1: Abstraction Layer (no behavior change)
- Create `web/llm/` package with interface + OllamaProvider
- Refactor `ask.py` to use provider interface
- All tests pass, Ollama remains default
- **Risk: zero** — pure refactor

### Phase 2: OpenRouter Provider
- Implement OpenRouterProvider
- Add config vars to config.py
- Add `openai` to requirements.txt (`pip install openai`)
- Test with OpenRouter API key
- **Dependency: `openai` Python package**

### Phase 3: UI Integration
- Add provider/model selector to Watchtower search UI
- Add `/api/llm/*` endpoints
- Show cost estimates from model pricing data
- Show reasoning token usage

### Phase 4: Advanced Features
- Model favorites / recently used
- Cost tracking dashboard
- Fallback chains (OpenRouter → Ollama)
- Per-query cost display in search results

---

## 7. Dependencies

### Python Packages (new)
- `openai>=1.0` — OpenAI SDK (used as OpenRouter client)
  - Already handles streaming, SSE parsing, retry logic
  - Well-maintained, widely used

### No New Dependencies For
- Ollama (already installed: `ollama` package)
- Embeddings (stays on Ollama)
- SSE streaming format (same format, our SSE event types unchanged)

---

## 8. Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| SDK for OpenRouter | `openai` Python SDK | Official recommendation, handles auth/streaming/retry |
| Embedding provider | Keep Ollama | Local, free, fast; hundreds of calls per index build |
| Thinking/reasoning | Unified via `thinking: bool` parameter | Provider implementation maps to Ollama `think=` or OpenRouter `reasoning.effort` |
| Config storage | Environment variables | Consistent with existing Config pattern; no DB needed |
| Hot-switching | ProviderManager singleton | Per-request resolution, atomic switch, no restart |
| Cost display | From `/v1/models` pricing | Real-time from OpenRouter; $0 for Ollama |
| Fallback | Not in Phase 1 | Add later; keep it simple first |

---

## 9. SSE Event Changes (Frontend Impact)

### Existing events (unchanged)
- `{type: "model", model: "...", thinking: bool}` — add `provider` field
- `{type: "thinking", content: "..."}`
- `{type: "thinking_done"}`
- `{type: "token", content: "..."}`
- `{type: "sources", sources: [...]}`
- `{type: "done"}`
- `{type: "error", message: "..."}`

### New events
- `{type: "usage", usage: {prompt_tokens, completion_tokens, total_tokens, cost}}` — sent before "done" when provider returns usage stats

### Frontend changes needed
- Handle `usage` event to display token count / cost
- Provider selector UI (dropdown or modal)
- Model selector (populated from `/api/llm/models`)
- Optional: cost estimate badge next to "Ask" button
