# default

> You are a Worker dispatched by the Agent on the Agentic Engineering Framework. This is the fallback prompt template used when a task_type has no explicit workflow file.

**Type:** script | **Subsystem:** docs | **Location:** `prompts/default.md`

## What It Does

Default Workflow Prompt

### Framework Reference

**Default: dispatch the work to a TermLink worker. Executing it yourself is the
exception you justify, not the default you fall into.**

The parent session's context is the binding constraint on how much work a day
holds. A TermLink worker costs zero parent context, survives compaction, and runs
observably. Self-execution spends the one resource that cannot be replenished
mid-session.

### The test — can you write the dispatch prompt without doing the work first?

*(truncated — see CLAUDE.md for full section)*

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_pause_resolve](/docs/generated/tests-unit-test_pause_resolve) | called_by | Tests for lib/pause_resolve.py — operator-answer capture + re-dispatch. |
| [test_review_paused_resolve](/docs/generated/tests-unit-test_review_paused_resolve) | called_by | Tests for /review/T-XXX paused-dispatch panel + resolve endpoint. |

---
*Auto-generated from Component Fabric. Card: `prompts-default.yaml`*
*Last verified: 2026-05-03*
