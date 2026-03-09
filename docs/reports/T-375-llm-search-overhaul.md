# T-375: LLM Search UX Overhaul — Research Artifact

## Current State Analysis

### Architecture (5 files)
| File | Purpose | Lines |
|------|---------|-------|
| `web/search.py` | BM25 keyword search via Tantivy | 268 |
| `web/embeddings.py` | Semantic search via sqlite-vec + Ollama embeddings (nomic-embed-text-v2-moe, 768d) | 643 |
| `web/ask.py` | LLM Q&A — RAG retrieval → Ollama streaming SSE. Multi-turn. | 234 |
| `web/config.py` | Env-based config. Models: qwen3:14b, dolphin-llama3:8b, nomic-embed-text-v2-moe | 43 |
| `web/templates/search.html` | Monolithic template: HTML + CSS + 567 lines of inline JS | 567 |
| `web/blueprints/discovery.py` | Flask routes: /search, /search/ask, /search/save, /search/feedback | 297 |

### Search Modes
1. **Keyword (BM25)** — Tantivy, ephemeral /tmp index, 60s staleness
2. **Semantic** — sqlite-vec + ollama embed, 120s staleness
3. **Hybrid** — RRF fusion of BM25 + semantic, cross-encoder reranking (Qwen3-Reranker-0.6B)

### LLM Q&A Pipeline
```
User query → rag_retrieve(hybrid + rerank) → format_rag_context → ollama.chat(stream=True) → SSE → browser
```

---

## Problems Identified

### 1. Look & Feel
- **Buried Q&A**: The "Ask a Question" feature is inside a collapsed `<details>` — most users never find it
- **No visual hierarchy**: Search and Q&A have equal/zero visual weight
- **Raw scores visible**: Numbers like `0.432` mean nothing to users
- **No empty state**: Landing on /search with no query shows just a bare input
- **No search history**: Users repeat queries; no recent/saved queries
- **Cramped inline layout**: Input + dropdown + button in one fieldset — mobile hostile
- **Category-only grouping**: Results are flat lists under category accordions — no cards, no relevance indicators

### 2. Structure / Maintainability
- **567-line monolith template**: HTML + CSS + JS all in one file
- **150-line askQuestion()**: Deeply nested callback-style code
- **Duplicated logic**: `_categorize()`, `_extract_title()`, `_extract_task_id()` duplicated in search.py AND embeddings.py
- **Path-to-link logic duplicated**: Jinja2 template AND JavaScript both map paths to URLs independently
- **No JS extraction**: All client-side code is inline `<script>` tags, not importable/testable
- **Client-only conversation**: Multi-turn history lives only in browser memory, no persistence

### 3. Engine Lock-in (Critical)
- **Hard-coded Ollama**: `ask.py` imports `ollama` directly, no abstraction
- **No cloud LLM option**: Can't use OpenRouter, OpenAI, Anthropic APIs
- **Model selection requires restart**: Config loaded at import time
- **No API key management**: Only env vars, no UI, no safe storage
- **Embedding tied to Ollama**: `embeddings.py` embeds via `ollama.embed()` — no alternative

### 4. Missing: Safe Key Storage
- No mechanism to store API keys beyond environment variables
- No settings page in Watchtower
- No encrypted storage for secrets
- Production deployment uses systemd env — workable but not user-friendly

---

## Research Topics for Agents

### Agent 1: Search UX Patterns & Redesign
**Question:** What does a modern, high-quality search+Q&A interface look like for a developer tool?
**Research scope:**
- Command-palette style search (Vercel, Linear, Raycast)
- Split-pane search: results on left, preview on right
- Q&A as first-class citizen, not hidden in a details tag
- Progressive disclosure of results (relevance bars vs raw scores)
- Mobile-first search layout patterns
- Empty state / onboarding UX
- Search history / recent queries patterns
**Deliverable:** Concrete design recommendations for the search page layout, with ASCII mockups for 2-3 options.

### Agent 2: OpenRouter API & LLM Abstraction Layer
**Question:** How should we abstract LLM access to support both local Ollama and cloud providers (OpenRouter, OpenAI)?
**Research scope:**
- OpenRouter API format (OpenAI-compatible?), streaming support, model listing
- Abstraction pattern: strategy pattern / provider interface
- How to handle: model selection, streaming SSE, thinking mode across providers
- Embedding abstraction (local ollama vs OpenAI embeddings API)
- Cost awareness: show estimated cost per query for cloud providers
- Fallback chain: local → cloud or user preference
**Deliverable:** Interface design for LLM provider abstraction, with code sketch.

### Agent 3: Safe API Key Storage
**Question:** What's the right pattern for storing API keys safely in a Python/Flask web app that also has CLI usage?
**Research scope:**
- Python keyring (OS-level secure storage) — works on Linux/macOS/Windows
- Encrypted config file (Fernet symmetric encryption, AES)
- Environment variables + .env files (current approach — limitations?)
- Flask session-based settings (ephemeral, per-browser)
- File-based encrypted store (e.g., `.context/secrets/` with master password)
- UI pattern for settings page with masked key input
- Threat model: who are we protecting against? (casual access vs sophisticated attack)
**Deliverable:** Recommendation for storage mechanism with tradeoffs table.

### Agent 4: Template & JS Architecture
**Question:** How should the search template be restructured for maintainability without a build step?
**Research scope:**
- Extracting JS from inline `<script>` to static files
- Eliminating code duplication (path-to-link, categorize) between Python and JS
- Component-izing the template (Jinja2 macros, includes, or htmx partials)
- Progressive enhancement with htmx (replace raw fetch+SSE?)
- Eliminating duplicated utility functions (search.py ↔ embeddings.py)
**Deliverable:** Proposed file structure and migration strategy.

### Agent 5: Settings Page Design
**Question:** What should a Watchtower settings page look like that lets users configure LLM engine, API keys, and search preferences?
**Research scope:**
- Settings page layout (tabs: General, LLM, Search, Advanced)
- Engine selector: Local (Ollama) vs Cloud (OpenRouter) with dynamic form fields
- API key input with show/hide toggle and validation ("test connection")
- Model browser: list available models from selected engine
- Search preferences: default mode, result limit, thinking mode toggle
- Persistence: where do settings live? (YAML file? SQLite?)
- Per-user vs global settings (Watchtower is typically single-user)
**Deliverable:** Settings page wireframe and config persistence recommendation.

---

## Research Results Synthesis

### Assumption Validation

| # | Assumption | Result | Agent |
|---|-----------|--------|-------|
| 1 | OpenRouter uses OpenAI-compatible API | **VALIDATED** — `openai` SDK works with base_url swap. SSE streaming identical. | Agent 2 |
| 2 | Settings can persist without server restart | **VALIDATED** — ProviderManager hot-switches per-request. YAML config with runtime reload. | Agents 2, 5 |
| 3 | Template can be restructured without build step | **VALIDATED** — Classic `<script>` tags in base.html, Jinja2 includes. search.html 567→15 lines. | Agent 4 |
| 4 | Fernet provides adequate key storage | **VALIDATED** — Tested: PBKDF2 from /etc/machine-id + Fernet roundtrip works. Zero new deps. keyring NOT viable (headless LXC). | Agent 3 |
| 5 | Elevating Q&A improves discoverability | **VALIDATED** — Research confirms (Perplexity, NN/g): AI answers should be first-class, not hidden. | Agent 1 |

### Key Decisions from Research

1. **UX Layout: "Unified Smart Input" (Option C)** — Single input auto-detects search vs Q&A. Questions get AI answer above results. Keywords get search results with category pills. Mode selector hidden behind "Advanced".

2. **LLM Abstraction: Strategy Pattern** — `LLMProvider` ABC with `OllamaProvider` + `OpenRouterProvider`. New `web/llm/` package (4 files). Only 1 new dep: `openai`.

3. **Key Storage: Hybrid (Option E)** — Fernet encrypted file + env-var fallback. Machine-bound via /etc/machine-id. Zero new deps (cryptography already installed).

4. **Template: 4-Phase Migration** — Python dedup → JS extraction (3 files) → path-to-link server-side → Jinja2 partials. All independent of UX redesign.

5. **Settings Page: Single scrollable page with article cards** — YAML persistence at `.context/settings.yaml`. htmx-powered engine selector. Gear icon in nav.

### Estimated Build Tasks

| # | Task | Scope | Dependencies |
|---|------|-------|-------------|
| 1 | Python dedup + search_utils.py | Extract 4 shared functions + path_to_link | None |
| 2 | LLM Provider abstraction layer | web/llm/ package, refactor ask.py | None |
| 3 | Fernet key storage | web/secrets_store.py | None |
| 4 | Settings page + config persistence | Blueprint, template, YAML, hot reload | Tasks 2, 3 |
| 5 | Search UX redesign | Unified input, relevance bars, category pills, empty state | Task 1 |
| 6 | JS extraction + template partials | Extract inline JS, Jinja2 includes | Task 5 |

**Total: 6 build tasks.** Fits within the 6-task cap from Go/No-Go criteria.

### Detailed Agent Reports

- Agent 1 (UX): `/tmp/fw-agent-search-ux-patterns.md`
- Agent 2 (OpenRouter): `/tmp/fw-agent-openrouter-abstraction.md`
- Agent 3 (Key Storage): `/tmp/fw-agent-key-storage.md`
- Agent 4 (Template): `/tmp/fw-agent-template-architecture.md`
- Agent 5 (Settings): `/tmp/fw-agent-settings-page.md`
