---
title: "T-388: Search Page UX Overhaul — Inception Research"
task: T-388
date: 2026-03-09
status: active
---

# T-388: Search Page UX Overhaul — Research Artifact

## Current Architecture Summary

### Components
| Layer | Component | Purpose |
|-------|-----------|---------|
| Template | `search.html` | Main page + CSS |
| Partial | `_partials/search_input.html` | Search form, mode selector, recent searches |
| Partial | `_partials/ask_answer_card.html` | Q&A card with streaming, sources, feedback |
| Partial | `_partials/search_results.html` | Results + category pills + empty state |
| JS | `search-qa.js` | Q&A streaming, conversation, save/feedback |
| JS | `utils.js` | Question detection, path routing, CSRF |
| JS | `markdown-render.js` | Marked.js rendering, code copy buttons |
| Backend | `discovery.py` | `/search` route, loads saved Q&A |
| Backend | `ask.py` | `/search/ask` SSE streaming, RAG pipeline |
| Backend | `settings.py` | `/settings/` model config page |
| Engine | `search.py` | Tantivy BM25 keyword search |
| Engine | `embeddings.py` | sqlite-vec semantic search + RRF hybrid |
| Provider | `llm/provider.py` | Abstract LLM interface |
| Provider | `llm/ollama_provider.py` | Ollama implementation |
| Provider | `llm/openrouter_provider.py` | OpenRouter implementation |
| Provider | `llm/manager.py` | Provider switching, registration |
| Config | `config.py` | All env vars and defaults |

### Search Modes
- **Keyword**: Tantivy BM25, English stemming, snippet highlighting
- **Semantic**: sqlite-vec 768-dim embeddings (nomic-embed-text-v2-moe via Ollama)
- **Hybrid**: Reciprocal Rank Fusion (k=60) merging both + optional cross-encoder reranking

### 10 Search Categories (path-based, hardcoded)
Active Tasks, Completed Tasks, Episodic Memory, Project Memory, Saved Answers, Handovers, Component Fabric, Research Reports, Agent Docs, Specifications

### Config System
- Settings persisted in `.context/settings.yaml`
- API keys encrypted in `.context/secrets/api-keys.enc`
- Supports: Ollama + OpenRouter providers
- UI exposes: provider selection, primary/fallback model, API keys, connection test
- **Missing from UI**: Ollama host/port, embedding model, reranker model, timeouts

## Identified Problems

### P1: Saved Q&A stores raw typo-laden questions
**Evidence**: Filenames in `.context/qa/`:
- `2026-03-03-can-you-write-a-summury-eplaning-this-framwoprk-the-fucnntio.md`
- `2026-03-03-enhance-the-answer-with-morre-detailed-implemnattion-example.md`

The `# title` inside the file is also the raw typed text. When voice-transcribing, this produces nonsensical titles. The system should ask the LLM to infer/rephrase the question as part of the answer, then use the clean version for storage.

### P2: Search mode selector is confusing
Current: dropdown with "Hybrid", "Keyword", "Semantic" — technical jargon. Users don't know the difference. "Natural language" as a concept is missing — it's actually the Q&A/ask feature but isn't labeled clearly as a search mode.

### P3: No tag cloud or topic filtering
Categories are hardcoded by file path (Tasks, Episodic, etc.). No user-defined tags exist. No way to browse by topic. A tag cloud derived from indexed document metadata would add discoverability.

### P4: Settings page missing Ollama connection config
Can't set Ollama host IP or port from the UI — hardcoded to `OLLAMA_HOST` env var (default `localhost:11434`). For users running Ollama on a different machine (e.g., `192.168.10.107:11434`), there's no UI to configure this.

### P5: Model selection limited
Settings page has text inputs for primary/fallback model but no dropdown populated from available models. The "Test Connection" fetches models but doesn't populate a selector.

### P6: Empty state and layout feel messy
Two-column grid with suggestions + saved answers was a good start (T-385) but the overall composition lacks cohesion. Mode selector, gear icon, hint text, recent searches — too many elements competing.

## Proposed Solution Areas

### S1: Question inference on save
When saving a Q&A answer, extract the LLM's interpretation of the question (or ask the LLM to rephrase in a clean sentence). Store both `raw_question` and `inferred_question` — use inferred for title/filename.

**Implementation**: Add a post-processing step in `/search/save` that either:
- (a) Asks the LLM to rephrase the question (extra API call, ~2s)
- (b) Extracts the first sentence of the answer as the topic (no API call)
- (c) Adds a "title" field to the SSE `done` event where the LLM suggests a clean title

Option (c) is preferred — the LLM already has context, adding "suggest a clean title" to the system prompt is nearly free.

### S2: Simplified search mode UX
Replace the technical dropdown with clear, visually distinct options:
- **Search** (keyword/hybrid — finds documents)
- **Ask** (natural language Q&A — gets an AI-generated answer)

The hybrid vs keyword vs semantic distinction can be an "Advanced" toggle or auto-detected.

### S3: Tag cloud from indexed categories + extracted topics
- Use existing search categories as primary tags
- Extract frequent terms/topics from indexed documents via TF-IDF or simple frequency analysis
- Display as a selectable tag cloud on the empty state
- Tags filter search results when clicked

### S4: Settings page — Ollama host/port
Add fields to the settings page:
- Ollama Host (text input, default from env)
- Ollama Port (number input, default 11434)
- Save updates `OLLAMA_HOST` in `.context/settings.yaml`
- Provider re-initializes on save

### S5: Model dropdown selector
Replace text inputs with populated dropdowns:
- "Test Connection" already fetches model list
- Use that list to populate `<select>` for primary/fallback model
- Keep text input as fallback for manual entry

### S6: Cohesive search page layout
Design a clean, unified search experience:
- Prominent search bar (full width)
- Clear mode toggle (Search vs Ask)
- Tag cloud for browsing
- Recent searches as subtle chips
- Saved answers in a sidebar or below
- Settings accessible via gear icon (already done)

## Exploration Plan

| # | Spike | Time-box | Deliverable |
|---|-------|----------|-------------|
| 1 | Question inference on save | 30min | Modified save endpoint + system prompt addition |
| 2 | Settings page: Ollama host/port + model dropdown | 45min | Updated settings.py + template |
| 3 | Search page layout redesign | 60min | Redesigned templates + CSS |
| 4 | Tag cloud from categories | 30min | New partial + JS for tag filtering |
| 5 | Simplified mode UX | 20min | Mode toggle redesign |

## Go/No-Go Criteria

**GO if:** At least 3 of 6 solutions are feasible within the existing architecture without breaking the API contract or existing search functionality.

**NO-GO if:** Solutions require fundamental changes to the search engine, LLM provider abstraction, or database schema that would destabilize the platform.

## Dialogue Log

### User voice request (2026-03-09)
- **Raw**: "the shirts are still not very natural and it's becoming messy... suggest a deep analysis spawn off agents to investigate and redesign the search page... suggest also to use our framework component fabric..."
- **Interpreted**: Search page UX is messy and unnatural. Wants a deep analysis using component fabric, then a redesign addressing: (1) search mode options, (2) saved answers, (3) tag cloud, (4) settings/config button with model config, (5) Ollama host/port configuration
- **On saved answers**: "when you save the answers can you save what you have inferred so the question that you heard not what I have typed" — save the LLM's interpretation of the question, not the raw voice-transcribed text with typos
