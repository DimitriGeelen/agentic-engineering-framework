---
id: T-042
name: "Add keyed async queue to TermLink parallel dispatch"
description: >
  Inception: Evaluate using OpenClaw's keyed async queue to manage TermLink
  parallel dispatch — serialize per task, parallelize across tasks.

status: captured
workflow_type: inception
owner: human
horizon: next
tags: [framework-improvement, extracted-pattern, termlink]
components: []
related_tasks: [T-036, T-012]
created: 2026-03-27T18:55:29Z
last_update: 2026-03-27T18:55:29Z
date_finished: null
---

# T-042: Add keyed async queue to TermLink parallel dispatch

## Problem Statement

TermLink dispatch (`fw termlink dispatch`) is fire-and-forget with manual polling. When multiple
workers are dispatched, there's no coordination — two workers could edit the same file, or a
worker could start before its dependency completes. The evaluation proved TermLink effective for
parallel fabric registration (T-012) but identified "no result aggregation" as a gap.

OpenClaw's keyed async queue (50 LOC) serializes per key and parallelizes across keys. Applied
to TermLink: key = task ID, so workers on the same task serialize while workers on different tasks
run concurrently.

**For:** TermLink parallel dispatch reliability
**Why now:** Pattern extracted via T-036; gap identified in T-012 TermLink evaluation.

## Key Artifacts

| Artifact | Location | Description |
|----------|----------|-------------|
| Extracted pattern | `docs/extracted/keyed-async-queue.ts` | Zero-dep standalone, 50 LOC |
| OpenClaw original | `src/plugin-sdk/keyed-async-queue.ts` | Full source |
| OpenClaw tests | `src/plugin-sdk/keyed-async-queue.test.ts` | Serialization + error tests |
| TermLink evaluation | `.context/episodic/T-012.yaml` | Gaps: no result aggregation |
| TermLink dispatch | `fw termlink dispatch` | Current fire-and-forget |

## How It Would Work

```bash
# Current (no coordination):
fw termlink dispatch --name worker-1 --prompt "Register components in src/agents/"
fw termlink dispatch --name worker-2 --prompt "Register components in src/config/"

# With keyed queue (serialize per task, parallel across):
fw termlink dispatch --task T-031 --name worker-1 --prompt "..."  # serialized with worker-2
fw termlink dispatch --task T-031 --name worker-2 --prompt "..."  # waits for worker-1
fw termlink dispatch --task T-032 --name worker-3 --prompt "..."  # runs in parallel
```

## Assumptions

- A-001: Task-level serialization prevents the file-conflict problem
- A-002: The queue can be implemented in the fw CLI layer (bash/Rust)
- A-003: Result aggregation is the bigger gap (queue is a building block)

## Exploration Plan

1. **Spike 1 (30min):** Review TermLink dispatch implementation — where would the queue sit?
2. **Spike 2 (1h):** Prototype a bash queue using file locks per task ID
3. **Spike 3 (30min):** Evaluate whether this belongs in fw CLI or in TermLink itself

## Technical Constraints

- TermLink is Rust — queue could live in Rust or in the bash fw wrapper
- Cross-process coordination needed (workers are separate tmux sessions)
- File locks are the simplest cross-process primitive

## Scope Fence

**IN:** Keyed dispatch coordination, per-task serialization
**OUT:** Rewriting TermLink core, result aggregation (separate task), worker orchestration

## Acceptance Criteria

- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- File conflicts during parallel dispatch are a real problem (evidence from T-012)
- Queue adds <200ms overhead per dispatch
- Fits naturally into `fw termlink dispatch` interface

**NO-GO if:**
- The problem is better solved by scoping workers to non-overlapping directories
- TermLink's tmux model makes queuing impractical
- Result aggregation is the real need, not serialization

## Verification

## Decisions

## Decision

## Updates
