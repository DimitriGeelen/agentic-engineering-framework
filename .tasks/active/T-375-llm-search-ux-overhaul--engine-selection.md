---
id: T-375
name: "LLM search UX overhaul — engine selection, OpenRouter integration, safe key storage"
description: >
  Inception: LLM search UX overhaul — engine selection, OpenRouter integration, safe key storage

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-09T09:10:43Z
last_update: 2026-03-09T09:10:43Z
date_finished: null
---

# T-375: LLM search UX overhaul — engine selection, OpenRouter integration, safe key storage

## Problem Statement

The Watchtower search page (/search) has three interrelated problems:

1. **Poor UX**: The Q&A feature (most powerful) is buried in a collapsed `<details>` tag. Search results show raw relevance scores (meaningless). No empty state, no search history, cramped mobile layout. The 567-line monolithic template mixes HTML/CSS/JS with duplicated logic between Python and JavaScript.

2. **Engine lock-in**: LLM access is hard-coded to Ollama (`import ollama` in ask.py and embeddings.py). Users cannot choose between local (Ollama) and cloud providers (OpenRouter, OpenAI). Model selection requires a server restart. No way to configure from the UI.

3. **No API key management**: Cloud LLM providers require API keys. Currently the only mechanism is environment variables — no UI, no safe storage, no validation. This blocks the engine selection feature entirely.

**For whom:** Framework users running Watchtower — both local development and production (LXC 170).
**Why now:** The search/Q&A system works but is underused because of discovery problems and the Ollama-only constraint.

## Assumptions

1. OpenRouter uses an OpenAI-compatible API — can reuse the `openai` Python SDK with a different base URL — **TO TEST** (Agent 2)
2. A settings page can persist config in a YAML/JSON file without requiring server restart for model changes — **TO TEST** (Agent 5)
3. The search template can be restructured (extract JS, add htmx partials) without a build step — **TO TEST** (Agent 4)
4. Python `cryptography.Fernet` or OS keyring provides adequate key storage for single-user deployment — **TO TEST** (Agent 3)
5. Elevating Q&A to a first-class section (not hidden in `<details>`) improves discoverability — **TO TEST** (Agent 1)

## Exploration Plan

5 parallel research agents, each investigating one facet:

1. **Agent 1: Search UX Patterns** — Survey modern search interfaces (Vercel, Linear, Perplexity), propose 2-3 layout options with ASCII mockups
2. **Agent 2: OpenRouter API & LLM Abstraction** — Research API format, streaming, design provider interface pattern
3. **Agent 3: Safe API Key Storage** — Compare keyring vs encrypted file vs env vars, recommend for our threat model
4. **Agent 4: Template Architecture** — Plan JS extraction, deduplication, component structure without build tools
5. **Agent 5: Settings Page Design** — Wireframe settings page, config persistence, engine selector UX

Each agent writes results to `docs/reports/T-375-*.md`, returns ≤5 lines.

## Technical Constraints

- No frontend build step (no webpack/vite) — Pico CSS + htmx + vanilla JS only
- Flask backend with Jinja2 templates
- Must work on both local dev (localhost:3000) and production (LXC 170, port 5050/5051)
- Ollama support must remain as primary (local-first philosophy)
- Cloud providers are opt-in additions, not replacements
- API keys must be encrypted at rest — env vars alone are insufficient for a settings page

## Scope Fence

**IN:**
- Research and design for all 5 facets
- Go/no-go decision on whether to proceed with full overhaul
- Spawn build tasks for approved facets

**OUT:**
- Actually implementing the overhaul (build tasks)
- Embedding provider abstraction (separate from LLM chat abstraction — can be Phase 2)
- User authentication for Watchtower (settings page is global, not per-user)

## Acceptance Criteria

- [ ] Problem statement validated
- [ ] Assumptions tested (5 research agents)
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- OpenRouter API is OpenAI-compatible (streaming works)
- A clean LLM abstraction layer is feasible without rewriting all of ask.py
- At least one safe key storage option works without complex dependencies
- The UX redesign can be done incrementally (not all-or-nothing)

**NO-GO if:**
- OpenRouter requires a fundamentally different streaming mechanism
- Key storage options all require external services (Vault, KMS) for single-user
- The template restructuring requires a build step
- Total estimated effort exceeds 6 build tasks

## Verification

test -f docs/reports/T-375-llm-search-overhaul.md

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
