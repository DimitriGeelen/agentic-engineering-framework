---
title: "T-254: LLM-Assisted Q&A for Watchtower Search — Research"
task: T-254
type: inception
created: 2026-02-23
---

# T-254: LLM-Assisted Q&A for Watchtower Search

## Problem Statement

Watchtower search returns ranked document snippets but users must mentally synthesize answers from multiple results. An LLM-assisted mode would take the user's natural language question, retrieve relevant context via semantic search (T-245), and synthesize a coherent answer with citations.

## Known Constraints

- **Local-only LLM** — ollama is installed with qwen2.5-coder-32b (IQ2_M, 11GB) and dolphin-llama3:8b (4.7GB)
- **Hardware** — RTX 5060 Ti (16GB VRAM, ~8GB free), 32GB RAM
- **Existing infrastructure** — semantic search (T-245) already indexes 885 docs / 11.7K chunks
- **Scope** — extend `/search` page, include both knowledge files AND source code

## Research Questions

### RQ-1: Ollama API integration patterns
- How to call ollama from Python (streaming vs blocking)?
- What's the context window of qwen2.5-coder-32b?
- Token throughput on this hardware?

### RQ-2: RAG architecture for our stack
- How many chunks to retrieve? What's the sweet spot for context vs quality?
- How to format retrieved chunks as LLM context?
- Should we use the existing sqlite-vec search or add a dedicated retriever?

### RQ-3: UX design for Q&A mode
- Streaming responses vs wait-for-complete?
- How to display citations/sources alongside the answer?
- How does this integrate with existing search modes (keyword/semantic/hybrid)?

### RQ-4: Performance and resource management
- Can we run ollama + Watchtower + embedding model concurrently?
- What's acceptable latency for a Q&A response?
- Should ollama model be pre-loaded or loaded on demand?

## Agent Research Findings

### RQ-1 Findings
*(to be filled by agent)*

### RQ-2 Findings
*(to be filled by agent)*

### RQ-3 Findings
*(to be filled by agent)*

### RQ-4 Findings
*(to be filled by agent)*

## Considerations

*(to be filled after agent research)*

## Decisions

*(to be filled after research synthesis)*

## Go/No-Go

*(pending)*
