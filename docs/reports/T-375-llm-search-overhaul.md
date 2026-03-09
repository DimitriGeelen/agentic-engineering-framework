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
