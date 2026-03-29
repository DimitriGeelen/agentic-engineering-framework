---
id: T-041
name: "Add config diff detection for CLAUDE.md hot-reload notifications"
description: >
  Inception: Evaluate adding a PostToolUse hook that detects CLAUDE.md/.framework.yaml
  changes and notifies the agent, using OpenClaw's config diff pattern.

status: captured
workflow_type: inception
owner: human
horizon: next
tags: [framework-improvement, extracted-pattern, config-reload]
components: []
related_tasks: [T-036, T-024]
created: 2026-03-27T18:55:29Z
last_update: 2026-03-27T18:55:29Z
date_finished: null
---

# T-041: Add config diff detection for CLAUDE.md hot-reload notifications

## Problem Statement

When `CLAUDE.md` or `.framework.yaml` changes during a session (e.g., another agent edits it,
or the user updates rules), the current agent doesn't notice. This leads to stale instruction
execution — the agent follows old rules until the next compaction or session restart.

OpenClaw's config diff pattern (deep path diffing + reload plan classification) can detect
which sections changed and whether the change is significant enough to warrant a notification.

**For:** Multi-agent environments where config changes mid-session
**Why now:** Pattern extracted via T-036; observed during evaluation when multiple agents touched CLAUDE.md.

## Key Artifacts

| Artifact | Location | Description |
|----------|----------|-------------|
| Extracted pattern | `docs/extracted/config-diff.ts` | Zero-dep standalone, 120 LOC |
| OpenClaw config-reload | `src/gateway/config-reload.ts` | Full hot-reload with watcher |
| OpenClaw reload-plan | `src/gateway/config-reload-plan.ts` | Rule-based classification |
| OpenClaw tests | `src/gateway/config-reload.test.ts` | Diff + plan tests |
| Framework config | `.framework.yaml` | Framework binding config |

## How It Would Work

1. PostToolUse hook checks `CLAUDE.md` mtime (fast, no I/O if unchanged)
2. If changed: read new content, diff against cached version
3. Classify changes: "rules changed" vs "docs only" vs "no semantic change"
4. Inject notification: "CLAUDE.md was updated — re-read section X"

## Assumptions

- A-001: CLAUDE.md changes during sessions are common enough to warrant detection
- A-002: Mtime check is sufficient (no need for content hashing on every tool call)
- A-003: The agent can meaningfully act on "re-read CLAUDE.md" notifications

## Exploration Plan

1. **Spike 1 (30min):** Measure how often CLAUDE.md changes during multi-agent sessions
2. **Spike 2 (1h):** Prototype mtime-based change detection hook
3. **Spike 3 (30min):** Test notification injection — does the agent actually re-read?

## Technical Constraints

- PostToolUse hooks must be fast (<50ms for hot path)
- Mtime stat is O(1), content diff only on change
- Must not break single-agent sessions (no-op when no changes)

## Scope Fence

**IN:** CLAUDE.md change detection + notification hook
**OUT:** Auto-reloading config, changing framework behavior dynamically, .framework.yaml hot-reload

## Acceptance Criteria

- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- CLAUDE.md changes happen in >10% of multi-agent sessions
- Detection adds <5ms to the PostToolUse hot path
- Agent demonstrably acts on the notification

**NO-GO if:**
- CLAUDE.md rarely changes mid-session
- The overhead isn't worth the benefit
- Claude Code already handles CLAUDE.md reloading natively

## Verification

## Decisions

## Decision

## Updates
