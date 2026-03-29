---
id: T-039
name: "Add dedupe cache to framework hooks — fix re-entry and sprechloop bugs"
description: >
  Inception: Evaluate adding OpenClaw's dedupe cache pattern to framework hooks.
  Fixes known re-entry bugs (checkpoint.sh sprechloop, pre-compact.sh dedup hack)
  with a proper TTL+LRU dedup primitive.

status: captured
workflow_type: inception
owner: human
horizon: now
tags: [framework-improvement, extracted-pattern, idempotency]
components: []
related_tasks: [T-036, T-024]
created: 2026-03-27T18:55:29Z
last_update: 2026-03-27T18:55:29Z
date_finished: null
---

# T-039: Add dedupe cache to framework hooks — fix re-entry and sprechloop bugs

## Problem Statement

Framework hooks use ad-hoc re-entry guards that have known failure modes:
- `checkpoint.sh:113-116`: Lock file re-entry guard — caused "23 handover commits in sprechloop"
  because tokens stay above critical and the guard didn't prevent rapid re-triggering
- `pre-compact.sh:17`: Grepping git log for recent handover commits as dedup — fragile, depends
  on commit message format and 5-minute window

OpenClaw solved this with a proper `DedupeCache` (TTL + LRU, 90 LOC) plus a persistent variant
(file-lock-protected JSON, 190 LOC). The in-memory cache alone would replace both ad-hoc guards.

**For:** Framework reliability (D-002: Reliability directive)
**Why now:** Pattern extracted via T-036; the sprechloop incident is documented in code comments.

## Key Artifacts

| Artifact | Location | Description |
|----------|----------|-------------|
| Extracted pattern | `docs/extracted/dedupe-cache.ts` | Zero-dep standalone, 100 LOC |
| OpenClaw in-memory | `src/infra/dedupe.ts` | Original 90 LOC |
| OpenClaw persistent | `src/plugin-sdk/persistent-dedupe.ts` | File-lock + JSON, 190 LOC |
| OpenClaw tests | `src/plugin-sdk/persistent-dedupe.test.ts` | Full test suite |
| checkpoint.sh bug | `.agentic-framework/agents/context/checkpoint.sh:113-116` | Re-entry lock comment |
| pre-compact.sh hack | `.agentic-framework/agents/context/pre-compact.sh:17` | Git log grep dedup |

## Current Ad-Hoc Guards vs Proper Dedup

| Guard | Current Implementation | Problem |
|-------|----------------------|---------|
| checkpoint.sh re-entry | Lock file + cooldown file | Doesn't prevent rapid re-triggering at critical level |
| pre-compact.sh dedup | `grep` git log for handover commit in last 5min | Fragile, format-dependent |
| budget-gate.sh caching | JSON status file with 90s TTL | Works but not reusable |

**With dedupe cache:** `dedup.check("handover-trigger")` returns true on second call within TTL. One line replaces each ad-hoc guard.

## Assumptions

- A-001: Bash hooks can invoke a shared dedup check (via Python one-liner or compiled TS)
- A-002: TTL-based dedup is sufficient (no need for persistent/cross-session dedup in hooks)
- A-003: The sprechloop bug is reproducible or at least the code path is identifiable

## Exploration Plan

1. **Spike 1 (30min):** Trace the sprechloop code path — what sequence triggers 23 handovers?
2. **Spike 2 (1h):** Prototype a bash-callable dedup check (Python snippet or compiled node)
3. **Spike 3 (30min):** Identify all ad-hoc dedup guards in the framework and list replacement targets

## Technical Constraints

- Hooks are bash scripts — dedup must be callable from bash
- Must not add Node.js as a hard dependency for Python-based hooks
- TTL precision: 1-second granularity is sufficient
- State: file-based (hooks are separate processes, no shared memory)

## Scope Fence

**IN:** In-memory/file-based dedup cache, replace checkpoint.sh and pre-compact.sh guards
**OUT:** Cross-session dedup, persistent dedup store, new hook architecture

## Acceptance Criteria

- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- The sprechloop bug code path is confirmed and dedup would prevent it
- A bash-callable dedup check can be implemented in <50 LOC
- At least 2 ad-hoc guards can be replaced

**NO-GO if:**
- The re-entry bugs have already been fixed by other means
- File-based dedup adds too much I/O overhead for hot-path hooks
- The dedup pattern doesn't fit the bash hook execution model

## Verification

## Decisions

## Decision

## Updates
