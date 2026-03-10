---
id: T-388
name: "Search page UX overhaul: unified search modes, tag cloud, settings integration"
description: >
  Inception: Search page UX overhaul: unified search modes, tag cloud, settings integration

status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-09T11:30:18Z
last_update: 2026-03-09T19:07:34Z
date_finished: 2026-03-09T19:07:34Z
---

# T-388: Search page UX overhaul: unified search modes, tag cloud, settings integration

## Problem Statement

The Watchtower search page has accumulated features across T-376 through T-385 but lacks cohesion. Six specific problems identified:

1. **Saved Q&A stores raw typo-laden questions** — voice-transcribed input produces filenames like `summury-eplaning-this-framwoprk`. Should store the LLM's inferred/rephrased question.
2. **Search mode selector uses technical jargon** — "Hybrid/Keyword/Semantic" means nothing to users. Need clear "Search" vs "Ask" distinction.
3. **No tag cloud or topic browsing** — categories are path-based and technical. No topic-based discovery.
4. **Settings page missing Ollama host/port** — can't configure where Ollama runs from the UI.
5. **Model selection is manual text input** — should be a dropdown populated from available models.
6. **Layout feels messy** — too many competing elements without visual hierarchy.

Research artifact: `docs/reports/T-388-search-ux-overhaul-research.md`

## Assumptions

- A1: LLM can reliably rephrase questions as clean titles with minimal prompt cost
- A2: Existing search categories provide sufficient tag material for a useful tag cloud
- A3: Settings page changes won't break existing provider abstraction

## Exploration Plan

| # | Spike | Time-box | Deliverable |
|---|-------|----------|-------------|
| 1 | Question inference on save | 30min | Modified save endpoint + system prompt |
| 2 | Settings: Ollama host/port + model dropdown | 45min | Updated settings.py + template |
| 3 | Search page layout redesign | 60min | Redesigned templates + CSS |
| 4 | Tag cloud from categories | 30min | New partial + JS for tag filtering |
| 5 | Simplified mode UX | 20min | Mode toggle redesign |

## Technical Constraints

- Flask + Jinja2 + Pico CSS + htmx — no React/Vue
- Must preserve existing SSE streaming Q&A, category pills, relevance bars
- Must preserve REST API contract (`/api/v1/search`, `/api/v1/ask`)
- Ollama host/port change requires provider re-initialization
- Currently Ollama-only for most users; OpenRouter available but secondary

## Scope Fence

**IN scope:** Question inference, search mode UX, tag cloud, settings host/port, model dropdown, layout redesign
**OUT of scope:** New search engine backends, Qdrant migration, embedding model changes, RAG pipeline tuning, new LLM providers

## Acceptance Criteria

### Agent
- [x] Problem statement validated with component fabric analysis
- [x] All 6 problems confirmed with evidence
- [x] Exploration plan reviewed
- [x] Go/No-Go decision made — GO (2026-03-09)

### Human
- [ ] [REVIEW] Agree with proposed solution areas (S1-S6)
  **Steps:**
  1. Read `docs/reports/T-388-search-ux-overhaul-research.md`
  2. Review the 6 identified problems and proposed solutions
  **Expected:** Alignment on which solutions to pursue
  **If not:** Provide feedback on priorities or alternatives

## Go/No-Go Criteria

**GO if:**
- At least 3 of 6 solutions are feasible within existing architecture
- No breaking changes to API contract or search engine required
- Each build task fits in one session (~2-4 hours)

**NO-GO if:**
- Solutions require fundamental search engine or database schema changes
- Proposed changes would break existing REST API contract
- Effort exceeds 5 build tasks (scope creep signal)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: All 6 solutions feasible within existing Flask+Pico+htmx architecture. No breaking API changes needed. Question inference requires only a system prompt addition. Settings host/port is a simple config field. Tag cloud uses existing search categories. Each spike fits a 30-60min time-box. Decompose into 4-5 build tasks.

**Date**: 2026-03-09T11:34:35Z
## Decision

**Decision**: GO

**Rationale**: All 6 solutions feasible within existing Flask+Pico+htmx architecture. No breaking API changes needed. Question inference requires only a system prompt addition. Settings host/port is a simple config field. Tag cloud uses existing search categories. Each spike fits a 30-60min time-box. Decompose into 4-5 build tasks.

**Date**: 2026-03-09T11:34:35Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-09T11:34:35Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** All 6 solutions feasible within existing Flask+Pico+htmx architecture. No breaking API changes needed. Question inference requires only a system prompt addition. Settings host/port is a simple config field. Tag cloud uses existing search categories. Each spike fits a 30-60min time-box. Decompose into 4-5 build tasks.

### 2026-03-09T19:07:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
