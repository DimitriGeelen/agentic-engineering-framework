---
title: "Sub-Agent Persistence Patterns Analysis"
task: T-178
date: 2026-02-18
status: complete
tags: [sub-agents, persistence, research]
agents: 1 (explore)
experiment: "Agent instructed to write to this file — could not (Explore agents are read-only)"
---

# Sub-Agent Persistence Patterns Analysis

> **Task:** T-178 | **Date:** 2026-02-18
> **Note:** This file was written by the orchestrator after the sub-agent returned results.
> The sub-agent was instructed to write directly but couldn't (Explore type lacks Write tool).

---

## 1. The Dispatch Protocol Foundation (T-097 to T-099)

Evidence from 96 tasks: only 8 (8.3%) used sub-agents. Four distinct patterns emerged:

- **Parallel Investigation** (T-059, T-061): Multiple agents investigate independent aspects
- **Parallel Audit** (T-072): Multiple agents review different categories
- **Parallel Enrichment** (T-073): Content generation with file-write convention
- **Sequential TDD** (T-058): Sequential development with review between iterations

## 2. Result Management Rules (CLAUDE.md)

| Agent Type | Rule | Enforcement |
|-----------|------|-------------|
| Content generators | MUST write to disk, return path + summary | Protocol only (not enforced) |
| Investigators | Return structured summaries, NOT raw content | Protocol only |
| Size gating | Payloads < 2KB inline, >= 2KB to blobs | fw bus (never used in practice) |

## 3. The fw bus System (T-109, lib/bus.sh)

- Task-scoped result ledger with YAML envelopes
- Auto-incrementing result IDs (R-001, R-002, etc.)
- Size-gated payload handling (2048B threshold)
- Prevents T-073-class context explosions (~97% savings)
- **Status: Built but never used in production**

## 4. Key Learnings from Episodic Memory

- **L-202**: "Sub-agent result management is the real optimization, not agent specialization"
- **L-210**: "When practice repeats ad-hoc across 3+ tasks, mine episodic memory and codify"
- **L-258**: "Research agents alone consumed ~100K tokens — split sessions"
- **L-346**: "Check context budget before spawning agents"
- **L-426**: "Always include write-to-file instructions in sub-agent prompts"

## 5. Dispatch Guidelines

- **Max parallel agents:** 5 (T-073 used 9 → context explosion)
- **Token headroom:** Leave 40K tokens free before dispatching
- **Background agents:** Use `run_in_background: true` for >2K expected output

## 6. The Persistence Gap

**Protocol says agents should write to disk. In practice:**
- fw bus has never been used (empty results/blobs directories)
- Explore agents (most common research type) don't have Write tool access
- Only `general-purpose` agents can write files
- Orchestrator must manually save results every time
- No structural enforcement exists

**This is the core problem T-178 needs to solve.**
