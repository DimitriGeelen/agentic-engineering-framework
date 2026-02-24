# Q&A Capability Enhancement Analysis for the Agentic Engineering Framework

## Executive Summary

The framework's Q&A system (T-254 through T-259) combines Tantivy BM25 full-text search, sqlite-vec semantic search (all-MiniLM-L6-v2, 384-dim), RRF hybrid fusion, and Ollama LLM streaming. It indexes ~500+ files across 260 episodic summaries, 259 completed tasks, 11 project memory YAML files, component fabric cards, handovers, and specs. This analysis identifies 9 enhancement opportunities with value/complexity/timeline assessments.

---

## 1. Agent-Assisted Onboarding

**Value: HIGH | Complexity: MEDIUM | Timeline: NEAR-TERM**

### Current State
- New agents (or humans) must read CLAUDE.md (762 lines, 38KB), FRAMEWORK.md, agent docs, task templates, and project memory files to understand "how things work here"
- The fw resume status command provides state synthesis but not conceptual Q&A
- The memory-recall.py script (agents/context/lib/memory-recall.py) already does keyword+hybrid search against project memory, but only returns learnings/patterns/decisions — not procedural knowledge

### Enhancement
Create an fw ask CLI command that wraps the existing rag_retrieve() + local LLM answer pipeline for terminal use. This would allow:
- fw ask "How do I create a task?" -> retrieves relevant CLAUDE.md sections + task template + create-task agent docs -> synthesizes answer
- fw ask "What is Tier 0 enforcement?" -> retrieves enforcement config + CLAUDE.md section + relevant patterns
- fw ask "What happened in T-073?" -> retrieves episodic summary, related patterns, task file

### Implementation Path
1. Create lib/ask.sh that calls a Python wrapper around web.embeddings.rag_retrieve() + web.ask.stream_answer() (or a simpler non-streaming variant)
2. Route via fw ask "question"
3. Reuse existing search infrastructure — no new indexing needed
4. For agents: expose as a Python function fw_ask(query) -> str that other agent scripts can call

### Why HIGH Value
- CLAUDE.md alone is 38KB — querying specific sections instead of loading the entire file saves ~15-20K tokens per session
- New AI agents starting sessions could ask "What's the current project state?" instead of reading multiple files
- Reduces the "50 file reading problem" to a single query

---

## 2. Decision Support (Precedent Mining)

**Value: HIGH | Complexity: LOW | Timeline: NEAR-TERM**

### Current State
- 296 lines of decisions in decisions.yaml, plus architectural decisions in 005-DesignDirectives.md
- 170 lines of failure patterns, 557 lines of learnings
- The healing agent (diagnose.sh) already does keyword matching against patterns.yaml — but only for failure patterns, and only with basic word overlap scoring
- memory-recall.py searches project memory but not episodic summaries

### Enhancement
Before making a decision, agents could programmatically query: "Have we tried X before? What happened?"

Concrete scenarios from project history:
- Before choosing a sub-agent dispatch strategy: fw ask "What problems have we had with sub-agent dispatch?" -> retrieves T-073 (context explosion), T-097 (dispatch analysis), T-098 (dispatch protocol)
- Before adding a new hook: fw ask "What issues have git hooks caused?" -> retrieves FP-008 (auto-handover loop), commit-msg hook issues, pre-push blocking patterns
- Before choosing between YAML and JSON: fw ask "Why did we choose YAML?" -> retrieves D-001, relevant decisions

### Implementation Path
1. Already works with existing /search/ask endpoint — just needs a CLI wrapper
2. Integrate into the inception workflow: when fw inception start creates a task, auto-run a relevance query against the task name/description and attach results to the task's Context section
3. Enhance memory-recall.py to also search episodic summaries (currently only searches project memory)

### Why HIGH Value
- The framework has 260 episodic summaries representing institutional memory that is currently underutilized
- Decision D-027 (compaction destroys working memory) means agents lose context frequently — Q&A provides retrieval without full context loading
- Prevents repeating mistakes documented in failure patterns (currently 10+ FP-XXX patterns)

---

## 3. Pattern Discovery and Synthesis

**Value: HIGH | Complexity: MEDIUM | Timeline: NEAR-TERM**

### Current State
- Failure patterns (FP-001 through FP-009+), success patterns, workflow patterns, antifragile patterns in patterns.yaml
- Each episodic summary has challenges, successes, and decisions sections
- The /patterns web page shows individual patterns but doesn't synthesize across them
- No automated way to ask "What are the top 3 recurring themes across all failures?"

### Enhancement
Enable synthesis queries that aggregate across the entire knowledge base:
- "What are the most common failure modes?" -> LLM reads all failure patterns + relevant episodic challenges -> produces ranked synthesis
- "What practices have been most effective?" -> mines success patterns + learnings + practices.yaml
- "Which types of tasks take longest?" -> could combine with metrics-history.yaml data

### Implementation Path
1. For simple pattern queries, the current RAG pipeline handles this — hybrid search retrieves relevant chunks, LLM synthesizes
2. For aggregate queries ("most common", "top N", "trends"), consider a pre-computed summary endpoint:
   - Periodically generate pattern summaries (e.g., during fw audit)
   - Store as a .context/project/synthesis.yaml
   - Index it so RAG can retrieve pre-synthesized answers
3. Add category-scoped search: fw ask --scope patterns "What recurring themes..." to bias retrieval toward specific document categories

### Why HIGH Value
- Level D of the Error Escalation Ladder ("Change ways of working") requires seeing patterns across many tasks — exactly what Q&A synthesis enables
- The "Proactive Level D" section in CLAUDE.md explicitly calls for mining episodic memory for evidence of patterns repeating across 3+ tasks
- Currently this is a manual process; Q&A could automate the pattern mining step

---

## 4. Automated Q&A in Agent Workflows (Programmatic Access)

**Value: HIGH | Complexity: MEDIUM | Timeline: NEAR-TERM**

### Current State
- The healing agent (diagnose.sh) does its own keyword matching against patterns.yaml — basic word overlap scoring in bash
- The context agent's memory-recall.py does hybrid search but only against project memory files (not episodic, not tasks, not specs)
- The audit agent checks structural compliance but doesn't query knowledge for context
- No agent currently calls the Q&A/RAG infrastructure programmatically

### Enhancement
Give framework agents access to Q&A for intelligent lookups:

Healing agent enhancement: Instead of basic keyword matching in diagnose.sh (126 lines of bash pattern scoring), use a single RAG call. The LLM can understand semantic similarity (e.g., "context explosion" matches "memory overflow" even though no keywords overlap).

Context agent enhancement: During fw context focus T-XXX, generate a briefing with: fw ask --concise "What should I know before working on $task_name? Include related failures, decisions, and learnings."

Audit agent enhancement: After detecting a gap, query "Have we seen this gap pattern before?" After finding compliance issues, query "What's the historical resolution rate for this type of issue?"

Session capture agent: Before generating handover, query "What decisions were made in this session that aren't captured?" (compare git commits with decisions.yaml)

### Implementation Path
1. Create lib/ask-api.py — a Python wrapper that imports web.embeddings.rag_retrieve() and web.ask directly (no HTTP needed since both run in same Python environment)
2. Expose as: fw ask --json "query" for structured output, fw ask "query" for human-readable
3. For non-streaming use (agents), add a get_answer(query, chunks) function to web/ask.py that returns the complete answer instead of streaming
4. Replace healing.sh's find_similar_patterns with a call to fw ask --json --scope patterns "..."

### Why HIGH Value
- The healing agent's current pattern matching is brittle (word overlap in bash) — semantic search would dramatically improve recovery suggestions
- Agent-to-Q&A integration creates a "self-aware" framework: agents can query their own project's history
- Aligns with the framework's "antifragility" directive — agents learning from past failures at query time

---

## 5. Knowledge Gap Detection

**Value: MEDIUM | Complexity: LOW | Timeline: NEAR-TERM**

### Current State
- The gap register (gaps.yaml) tracks known spec-reality gaps manually
- The audit agent checks structural compliance but doesn't measure knowledge completeness
- No tracking of what users/agents ask that gets poor answers

### Enhancement
Track Q&A interactions to detect knowledge gaps:
1. Query logging: Log every question + retrieval quality (number of results, max relevance score, whether answer was "I don't have enough information")
2. Low-confidence detection: When RAG retrieves <3 chunks with score >0.5, flag as potential gap
3. Gap auto-registration: Queries that consistently get poor answers -> auto-suggest adding to gaps.yaml
4. Coverage dashboard: New Watchtower page showing knowledge coverage by category and common unanswered questions

### Implementation Path
1. Add query logging to /search/ask endpoint — store in /tmp/fw-qa-log.jsonl (or .context/working/qa-log.yaml)
2. Each log entry: {timestamp, query, num_chunks, max_score, model_used, had_uncertainty_phrases}
3. Add fw ask --stats to show Q&A quality metrics
4. Periodic analysis: fw audit could include a "knowledge health" section

### Why MEDIUM Value
- Provides feedback loop for knowledge base quality
- However, the framework already has a robust gap register — this adds automated detection
- Value increases significantly as Q&A usage grows

---

## 6. Session Context Enrichment (Pre-Work Briefing)

**Value: HIGH | Complexity: LOW | Timeline: NEAR-TERM**

### Current State
- Session Start Protocol requires: fw context init -> read LATEST.md -> review suggested action -> set focus -> fw metrics
- fw context focus T-XXX already calls memory-recall.py to show related knowledge
- But the briefing is limited to project memory (learnings, patterns, decisions) — doesn't include episodic context, related task histories, or spec sections

### Enhancement
Enrich the session start with a comprehensive Q&A briefing:
- Enhanced fw context focus would show a 200-word briefing synthesized from the task's episodic predecessor, related completed tasks (semantic similarity), relevant failure patterns and their mitigations, and applicable sections of CLAUDE.md/FRAMEWORK.md

Concrete example: When focusing on a new "build" task for search improvements, the briefing would surface:
- T-237 (BM25 search), T-245 (embeddings), T-255 (RAG retrieval) as related prior work
- FP-003 (dependency conflicts) as a relevant risk for Python package work
- The "Constraint Discovery" behavioral rule from CLAUDE.md

### Implementation Path
1. Enhance memory-recall.py's recall() function to include episodic summaries in results
2. Add --briefing mode that generates a structured 200-word summary using the local LLM
3. Integrate into context.sh focus — run briefing query using task name + description + tags as query
4. Cache briefing in .context/working/briefing-T-XXX.md so it's not regenerated on every focus

### Why HIGH Value
- Directly addresses the "context is a finite resource" problem — a 200-word briefing costs ~200 tokens vs. reading 5 files at ~2000 tokens each
- Particularly valuable after compaction, when the agent has zero context and needs to rebuild
- The existing memory-recall.py already does 80% of this — just needs episodic scope expansion and LLM synthesis

---

## 7. Retrospective Analysis

**Value: MEDIUM | Complexity: MEDIUM | Timeline: FUTURE**

### Current State
- fw metrics shows task counts, completion rates, velocity
- metrics-history.yaml tracks historical metrics
- The /graduation page shows learning promotion pipeline
- No automated retrospective capability ("What were our most impactful decisions?")

### Enhancement
Periodic automated retrospectives powered by Q&A:
- Weekly: "What were the most impactful decisions this week?" -> mines decisions.yaml + episodic summaries with date filtering
- Monthly: "What failure patterns are trending?" -> compares current patterns against historical
- Per-milestone: "What did we learn in the last 50 tasks?" -> synthesizes episodic summaries T-200 through T-250

### Implementation Path
1. Add date-filtered retrieval to the search infrastructure (currently no date filtering)
2. Create fw retrospective [--period weekly|monthly] [--since DATE]
3. Generate a Markdown report using the LLM, save to docs/reports/retrospective-YYYY-MM-DD.md
4. Add to Watchtower as a page with visualizations

### Why MEDIUM Value
- Valuable for long-running projects, less critical for day-to-day operation
- The "Proactive Level D" pattern already encourages this manually
- Date-filtered retrieval is a non-trivial addition to the current search infrastructure

---

## 8. CLAUDE.md Targeted Query (Context Budget Optimization)

**Value: HIGH | Complexity: LOW | Timeline: NEAR-TERM**

### Current State
- CLAUDE.md is 762 lines / 38KB — loaded entirely into every Claude Code session
- The agent must "know" all of CLAUDE.md at all times, consuming ~10K+ tokens of context
- Specific sections (Enforcement Tiers, Task Sizing Rules, Agent Behavioral Rules) are only relevant when certain situations arise

### Enhancement
Instead of the agent internalizing all of CLAUDE.md, it could query specific sections on demand:
- When creating a task: fw ask "What are the task sizing rules?" -> returns only the relevant ~500 bytes
- When hitting a gate: fw ask "What is Tier 0 enforcement and how do I bypass it?" -> returns enforcement section
- When in inception mode: fw ask "What are the inception discipline rules?" -> returns that specific section

### Implementation Path
1. CLAUDE.md is already indexed by the search infrastructure (search.py lines 85-86 index top-level *.md)
2. The chunking in embeddings.py (lines 133-162) splits on ## and ### headings — CLAUDE.md's sections are well-delimited
3. No new code needed — this is a usage pattern change

### Caveat
- CLAUDE.md is auto-loaded by Claude Code — this is a provider-specific behavior that can't be changed
- The value is primarily for other AI agents (non-Claude) or for reducing re-reading after compaction
- For Claude Code specifically, the main benefit is post-compaction recovery

### Why HIGH Value (with caveats)
- For non-Claude agents: saves ~10K tokens per session
- For post-compaction recovery: targeted queries are far cheaper than re-reading the full file
- For multi-project setups: agents working across projects don't need to load every project's full CLAUDE.md

---

## 9. Cross-Project Knowledge (Future Vision)

**Value: MEDIUM | Complexity: HIGH | Timeline: FUTURE**

### Current State
- The framework supports shared tooling mode via .framework.yaml in project root
- PROJECT_ROOT pattern allows agents to work across projects
- Search infrastructure indexes from PROJECT_ROOT — single project only
- No federation mechanism

### Enhancement
If multiple projects share the framework, enable cross-project Q&A:
- "Has any project solved the CSRF token problem?" -> searches across all projects using the framework
- "What deployment patterns work best?" -> aggregates deployment-related patterns from all projects

### Implementation Path
1. Add EXTRA_INDEX_DIRS configuration to web/search.py and web/embeddings.py
2. Allow fw ask --cross-project "query" to search federated indexes
3. Add project provenance to search results
4. Privacy: only index .context/project/ and .context/episodic/ from other projects (not active tasks or working memory)

### Why MEDIUM Value / HIGH Complexity
- Requires multi-project coordination, index federation, privacy boundaries
- Very high value for organizations running the framework across many projects
- Current single-project indexing is a simpler, more reliable starting point

---

## Priority Matrix

| # | Enhancement | Value | Complexity | Timeline | Dependencies |
|---|-------------|-------|------------|----------|--------------|
| 1 | Agent onboarding Q&A (fw ask CLI) | HIGH | MEDIUM | Near-term | None (core enabler) |
| 4 | Programmatic agent access | HIGH | MEDIUM | Near-term | #1 |
| 6 | Session context enrichment | HIGH | LOW | Near-term | #1 |
| 2 | Decision support / precedent mining | HIGH | LOW | Near-term | #1 |
| 8 | CLAUDE.md targeted query | HIGH | LOW | Near-term | #1 |
| 3 | Pattern discovery / synthesis | HIGH | MEDIUM | Near-term | #1 |
| 5 | Knowledge gap detection | MEDIUM | LOW | Near-term | #1 |
| 7 | Retrospective analysis | MEDIUM | MEDIUM | Future | #1, date filtering |
| 9 | Cross-project knowledge | MEDIUM | HIGH | Future | #1, federation |

Recommended build order: #1 -> #4 -> #6 -> #2 -> #8 -> #3 -> #5 -> #7 -> #9

The critical insight is that #1 (fw ask CLI) is the keystone — every other enhancement depends on having a programmatic, non-HTTP interface to the Q&A pipeline. The existing /search/ask endpoint is designed for browser SSE streaming; a synchronous Python API + CLI wrapper unlocks all downstream integrations.

---

## Architectural Notes

### Existing Infrastructure to Reuse
- web/embeddings.py: rag_retrieve(query, limit=10) — hybrid BM25+semantic retrieval, returns full chunks
- web/ask.py: stream_answer(query, chunks) — SSE streaming via Ollama
- web/search.py: search(query_str, limit=30) — BM25 keyword search with snippets
- agents/context/lib/memory-recall.py: recall(query, limit=5) — already does hybrid search against project memory

### What Needs Building
1. lib/ask-api.py: Synchronous wrapper around rag_retrieve() + non-streaming Ollama call. Returns {answer: str, sources: list[dict], confidence: float}
2. lib/ask.sh: Shell wrapper that calls ask-api.py and formats output for terminal
3. fw ask route: New subcommand in bin/fw routing to lib/ask.sh
4. Scope parameter: --scope {all,patterns,episodic,specs,tasks} to bias retrieval
5. JSON output mode: --json for programmatic consumption by other agents

### Estimated Size
- lib/ask-api.py: ~80 lines (wrapper + non-streaming Ollama call + JSON output)
- lib/ask.sh: ~30 lines (argument parsing + Python invocation)
- fw route addition: ~5 lines
- Healing agent integration: ~20 lines (replace 126 lines of bash pattern matching)
- Context agent enhancement: ~15 lines (add briefing mode to memory-recall.py)

Total: ~150 lines of new code + ~126 lines removed from healing agent = net ~25 lines added to the framework.
