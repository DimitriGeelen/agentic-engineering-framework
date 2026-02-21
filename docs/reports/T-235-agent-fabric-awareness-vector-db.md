# T-235: Agent Fabric Awareness + Vector Database Research

## Problem Statement

Two related questions about scaling the framework's intelligence layer:

1. **Agent Fabric Awareness**: Do our agents (task-create, audit, healing, handover, context, git, resume, fabric) know about and utilize the Context Fabric and Component Fabric? If not, how do we enforce awareness?

2. **Vector Database for Semantic Search**: As the framework scales (230+ completed tasks, 105 components, 300+ edges, 7 practices, patterns, decisions, learnings), should we add a vector database for associative/semantic search instead of relying on text file crawling?

## Research Findings

### Topic 1: Agent Fabric Awareness

**Overall Score: 5/10** — Well-designed systems, poorly integrated.

| Agent | Context-Aware | Fabric-Aware | Evidence |
|-------|-------------|------------|----------|
| context | FULL | NO | Owns context fabric; no component fabric references |
| audit | YES | YES | Suggests context fixes + fabric drift check |
| healing | YES | NO | Reads/writes patterns.yaml; no fabric use |
| handover | YES | NO | Generates context; references episodic but not fabric |
| task-create | MODERATE | NO | Calls context.generate-episodic on completion; no fabric |
| git | NO | NO | Pure enforcement layer; no context/fabric integration |
| resume | YES | NO | Reads handover + context; no fabric |
| session-capture | NO | NO | Checklist mentions learnings but no fabric |
| fabric | NO | YES | Standalone topology system; no context integration |
| dispatch | NO | NO | Templates don't mention fabric/context guidance |

**5 Critical Gaps:**
1. **Fabric invisible to working agents** — no agent checks deps before modifying files
2. **Pattern/learning capture is manual** — not wired into task completion
3. **No cross-agent coordination** — agents are completely siloed
4. **New files don't auto-register in fabric** — drift accumulates silently
5. **Dispatch protocol ignores learning capture** — multi-agent sessions lose knowledge

**Top 2 Quick Wins:**
1. Wire `fw fabric blast-radius` into git pre-commit hook (makes fabric active, not passive)
2. Auto-capture decisions/patterns from task file on `work-completed` (closes knowledge loss)

Full details: `/tmp/fw-agent-fabric-awareness.md`

### Topic 2: Vector Database Evaluation

**Current State:** No vector DB exists. Search is grep-only (web UI `/search` + `fw fabric search`). No relevance ranking.

**Data Volume:** ~5.5 MB across ~710 YAML/Markdown files (modest).

**Root Cause Finding:** Terminology fragmentation is the primary search problem — "audit"/"gate"/"enforcement"/"verification" all mean similar things, causing agents to miss 30-40% of related work via keyword search.

**Technology Comparison (7 options evaluated):**

| Option | Weighted Score | Install Size | Embeddings? | Key Strength |
|--------|---------------|-------------|-------------|--------------|
| **Tantivy + sqlite-vec** | **4.15** | ~17MB+22MB model | Hybrid | Two search paths, smallest footprint |
| ChromaDB | 3.85 | ~150MB | Built-in | Simplest single-package API |
| LanceDB | 3.90 | ~80MB | BYO | Hybrid search built-in |
| Qdrant Local | 3.60 | ~200MB | FastEmbed | Official MCP server exists |
| Tantivy alone | 3.75 | ~15MB | No | BM25 covers 60-70% of queries |
| Whoosh | 3.70 | ~3MB | No | Dead project (antifragility risk) |
| FAISS | 3.05 | ~30MB | BYO | Too low-level, no metadata |

**Key Insight:** BM25 keyword search handles 60-70% of practical queries on structured YAML/Markdown. Embeddings add 30-40% value specifically for "find similar" and "what's related" queries.

**Tiered Recommendation:**
- **Tier 1 (Recommended):** Tantivy (BM25) + sqlite-vec (vectors) hybrid — aligns with all four directives
- **Tier 2 (Simpler):** ChromaDB standalone — everything in one pip install
- **Tier 3 (MCP-aligned):** Qdrant local + MCP server — if agents should query knowledge via MCP

Full details: `/tmp/fw-agent-vector-db-research.md` and `/tmp/fw-agent-vector-db-options.md`

## Dialogue Log

### 2026-02-21 — Initial research dispatch
- **Human question:** Do our agents know about the fabrics? Should we add a vector DB?
- **Agent approach:** Dispatched 3 parallel research agents: (1) audit all agent AGENT.md/scripts for fabric references, (2) assess current search capabilities and data volume, (3) evaluate 7 vector DB technologies with web research
- **Key finding 1:** Agent fabric awareness is 5/10 — well-designed but poorly integrated. Context Fabric 60%, Component Fabric 20%, cross-agent 0%
- **Key finding 2:** Terminology fragmentation is the root cause for search problems, not raw search technology
- **Key finding 3:** BM25 covers 60-70% of queries; embeddings add value for the "find similar" use case
- **Pending:** Human review and go/no-go decision on both topics
