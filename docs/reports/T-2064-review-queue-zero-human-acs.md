# T-2064 — Task surfaced for human review despite zero Human ACs

**Task:** [T-2064](/tasks/T-2064) (Inception)
**Date:** 2026-05-28
**Decision:** GO — push predicate to queue-build layer (shared helper)

## Summary

User reported a task appeared in `/approvals` (review queue) even though it had ZERO unchecked Human ACs — only Agent ACs were unchecked. The review queue's predicate for "needs human review" was applied inconsistently across surface points.

## Decision: GO

**Candidate (b) — push the predicate to the queue-build layer via a shared helper.**

Centralising the "needs review" predicate at queue-build time prevents per-surface drift. Both `/approvals` (web) and `fw review-queue` (CLI) call the same predicate; render-time surfaces only display whatever the queue produced.

See task body for full Recommendation and exploration of why a per-surface predicate was rejected.
