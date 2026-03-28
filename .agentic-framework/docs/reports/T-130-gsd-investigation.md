---
title: "GSD (Get Shit Done) Investigation — Patterns for AEF"
task: T-130
date: 2026-02-19
status: complete
decision: GO
tags: [gsd, meta-prompting, parallel-execution, verification, research]
---

# GSD Investigation — Patterns for Agentic Engineering Framework

> **Task:** T-130 | **Date:** 2026-02-19 | **Decision:** GO

## Summary

GSD (gsd-build/get-shit-done, 15.9K stars) is a Claude Code slash-command meta-prompting layer with 11 specialized agents and 31 orchestrator commands. It's execution-optimized (parallel plans, fresh contexts, upfront specification), complementary to AEF's governance-optimized approach (reliability, auditability, cross-session learning).

## Adopted Patterns (3 build tasks)

1. **3-Level Verification** — GSD's `gsd-verifier` checks artifacts at three levels: Exists (file present), Substantive (not a stub/placeholder), Wired (actually imported/called by other code). AEF's P-011 only runs shell commands. Enhancement: structured verification protocol with stub detection.

2. **Codebase-Mapper Convention** — GSD's `gsd-codebase-mapper` produces CONVENTIONS.md, STACK.md, ARCHITECTURE.md for future agents. AEF has no convention-mapping. Enhancement: add codebase convention capture to session-start or audit.

3. **Research Confidence Protocol** — GSD ranks research sources (Context7 > official docs > WebSearch) and flags confidence levels. AEF has no formal research hierarchy. Enhancement: add confidence flagging to sub-agent dispatch protocol.

## Rejected Patterns (with rationale)

- **Wave-based parallelization** — Requires PLAN.md format with dependency graphs over file modifications. AEF's task-per-deliverable model is structurally different.
- **gsd-plan-checker** — AEF audit + P-011 verification gate covers this. Pre-execution static validation adds complexity.
- **CONTEXT.md locked decisions** — AEF decisions are already recorded in task files. Formal binding adds enforcement overhead.
- **Integration-checker** — Valuable but requires codebase-mapper first. Defer to later.

## Key Architectural Insight

GSD and AEF solve different problems in the same space:
- GSD excels at **getting greenfield work done** in parallel with fresh contexts
- AEF excels at **learning from work done** across sessions with institutional memory

The patterns adopted strengthen AEF's execution quality without distorting its governance architecture.

## Sources

- [gsd-build/get-shit-done (GitHub)](https://github.com/gsd-build/get-shit-done)
