# T-2062 — Watchtower /review/T-XXX 404 on completed tasks

**Task:** [T-2062](/tasks/T-2062) (Inception)
**Date:** 2026-05-28
**Decision:** NO-GO

## Summary

User reported `/review/T-XXX` returns 404 for tasks that have moved to `.tasks/completed/`. Initial recommendation was GO option (a) — make the route fall through to completed/ — but during exploration sibling T-2067 shipped an upstream root-cause fix (the components-regex frontmatter mangle was preventing render lookups). With T-2067 in place, the symptom resolves at source.

## Decision: NO-GO

Reversal rationale: implementing a fallback in the route would mask the underlying frontmatter-parse failure class. T-2067's regex fix eliminates the silent corpus mangle that was the proximate cause. No structural change needed on the route side.

See task body for full Recommendation block and the cause-chain Decisions trace (2026-05-28).

## Cross-references

- Sibling fix: T-2067 (regex repair + audit guard)
- Companion: T-2069 (frontmatter folded-scalar repair)
- Class: silent-corpus-migration pattern (memory: feedback_silent_corpus_migration_pattern.md)
