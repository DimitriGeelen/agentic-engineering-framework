# default

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `prompts/default.md`

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
| [test_pause_resolve](/docs/generated/tests-unit-test_pause_resolve) | called_by | TODO: describe what this component does |
| [test_review_paused_resolve](/docs/generated/tests-unit-test_review_paused_resolve) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `prompts-default.yaml`*
*Last verified: 2026-05-03*
