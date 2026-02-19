---
title: "Google Context Engineering Whitepaper Review"
task: T-120
date: 2026-02-19
status: complete
decision: GO
tags: [context-engineering, memory, google, whitepaper, research]
---

# Google Context Engineering Whitepaper — Review Against AEF

> **Task:** T-120 | **Date:** 2026-02-19 | **Decision:** GO
> **Sources:** Milam & Gulli (Nov 2025), Google ADK blog, Manus framework insights

## Summary

AEF's architecture strongly aligns with Google's recommended patterns for context engineering in multi-agent systems. The 3-tier memory model (working/project/episodic) matches Google's taxonomy (session/memory/context). AEF exceeds Google's recommendations in metered budget enforcement, failure learning, and authority model. Two gaps identified: memory consolidation and provenance tracking.

## Strong Alignment (13 of 17 concepts)

AEF already implements: session/context distinction, 3-tier memory, push memory (SessionStart hooks), pull memory (fw commands), context rot mitigation (budget-gate.sh), failure preservation (healing loop), artifact externalization (fw bus), restorable compression (handover keeps references), recitation pattern (focus.yaml), and session containers (YAML files).

## AEF Exceeds Google's Recommendations

1. **Metered budget enforcement** — Google suggests "configurable thresholds." AEF reads actual tokens and structurally blocks tool calls at critical level.
2. **Failure as institutional learning** — Google says "preserve failures." AEF classifies, patterns-matches, records resolutions, and promotes to practices.
3. **Per-task episodic summaries** — More granular than typical memory managers.
4. **Enforcement tiers** — No equivalent in Google's framework.

## Gaps to Address (2 build tasks)

1. **Memory consolidation protocol** — Google's 4-stage process (ingestion → extraction → consolidation → storage) highlights that AEF lacks automated deduplication, conflict resolution, and staleness pruning of learnings/patterns. With 58 learnings and growing, some are likely redundant or stale. `fw promote` is manual and one-directional.

2. **Memory provenance enrichment** — Google tracks source type (bootstrapped/user/tool), confidence weight, and reliance level per memory. AEF learnings have task reference and source string but no confidence/weight. This enables better consolidation quality.

## Intentional Divergences (by design, not gaps)

- **File-based storage** (D4 Portability) — no vector DB or knowledge graph
- **Explicit memory commands** (D2 Reliability) — no autonomous memory-as-a-tool
- **Synchronous budget gating** (D1 Antifragility) — not asynchronous compaction

## Sources

- [Context Engineering: Sessions & Memory (GitHub mirror)](https://github.com/momo-personal-assistant/momo-research/blob/main/Context%20Engineering:%20Sessions,%20Memory.md)
- [Google ADK Context-Aware Multi-Agent Framework](https://developers.googleblog.com/en/architecting-efficient-context-aware-multi-agent-framework-for-production/)
