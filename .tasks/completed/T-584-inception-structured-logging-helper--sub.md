---
id: T-584
name: "Inception: Structured logging helper — subsystem-tagged log function for framework scripts"
description: >
  Every framework shell script currently does echo message to stderr. No subsystem tags, severity levels, timestamps, or filtering. Debugging requires reading undifferentiated wall of text. OpenClaw has per-module loggers with color coding and dual-sink (console + file). Investigate: log.sh sourced by all agents providing log_info/log_warn/log_error with subsystem tag and timestamp. Writes to .context/working/framework.log. Enables grep subsystem framework.log for targeted debugging. Low effort, high debugging value. Research source: /opt/openclaw-evaluation/.context/working/round2-T-019.md (structured logging section). OpenClaw source: src/util/logger.ts (subsystem logger with color + dual sink). Related framework: lib/compat.sh (existing shared utilities), agents/context/*.sh (all hook scripts — consumers of logging).

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-23T21:21:55Z
last_update: 2026-04-13T06:23:22Z
date_finished: 2026-03-28T17:08:13Z
---

# T-584: Inception: Structured logging helper — subsystem-tagged log function for framework scripts

## Problem Statement

339 `echo ... >&2` calls across framework scripts produce undifferentiated text. No subsystem tags, severity levels, timestamps, or filtering. Debugging hooks and agents requires reading a wall of text. OpenClaw's per-module loggers demonstrated the value of structured logging.

## Assumptions

- A1: Structured logging improves debugging (VALIDATED — 339 undifferentiated echo calls make triage difficult)
- A2: Migration is feasible incrementally (VALIDATED — source lib/log.sh is compatible with existing patterns)
- A3: Log file is valuable (PARTIALLY VALIDATED — stderr not persisted, but debugging mostly done in-session)
- A4: Performance impact is acceptable (VALIDATED — date + file append is negligible vs current <50ms hook execution)

## Exploration Plan

1. Audit current logging patterns (done — 339 echo >&2 calls, no structure)
2. Evaluate 3 design options (done — lib/log.sh vs per-script vs syslog)
3. Assess migration effort (done — top 10 scripts first, incremental)
4. Design log rotation (done — truncate on session init)
5. Make recommendation (done — GO)

## Technical Constraints

- Must be bash-compatible (no external dependencies)
- Must work on both GNU/Linux and macOS (BSD)
- Must respect NO_COLOR and TTY detection (lib/colors.sh pattern)
- Must not break existing echo patterns during incremental migration

## Scope Fence

**IN:** Whether to build a structured logging library, which design, what migration strategy.
**OUT:** Building the library (separate build task). Migrating all 339 echo calls. Syslog integration.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested (4 assumptions — 3 validated, 1 partial)
- [x] Go/No-Go recommendation made (GO)

### Human
- [x] [REVIEW] Review exploration findings and approve go decision
  **Steps:**
  1. Read `docs/reports/T-584-structured-logging-helper.md`
  2. Evaluate whether Option A (lib/log.sh) is the right approach
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-584 go --rationale "your rationale"`
  **Expected:** Decision recorded, build task created
  **If not:** Discuss specific concerns

## Go/No-Go Criteria

**GO if:**
- Clear debugging benefit from structured output (true — 339 unstructured calls)
- Implementation is simple and incremental (true — one new file, compatible migration)
- Builds on existing infrastructure (true — colors.sh, paths.sh)

**NO-GO if:**
- Current echo patterns are adequate for debugging needs
- Performance overhead is unacceptable for PreToolUse hooks
- Migration effort outweighs benefit

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Recommendation

**Recommendation:** GO
**Rationale:** Clear debugging benefit from structured output (true — 339 unstructured calls); Implementation is simple and incremental (true — one new file, compatible migration); Builds on existing infrastructu...

## Decisions

**Decision**: GO

**Rationale**: Clear debugging benefit from structured output (true — 339 unstructured calls); Implementation is simple and incremental (true — one new file, compatible migration); Builds on existing infrastructu...

**Date**: 2026-03-28T17:08:13Z
## Decision

**Decision**: GO

**Rationale**: Clear debugging benefit from structured output (true — 339 unstructured calls); Implementation is simple and incremental (true — one new file, compatible migration); Builds on existing infrastructu...

**Date**: 2026-03-28T17:08:13Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-28 — artifact-reference [inception-research]
- **Research artifact:** docs/reports/T-584-structured-logging-helper.md

### 2026-03-28T10:31:28Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T17:08:13Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Clear debugging benefit from structured output (true — 339 unstructured calls); Implementation is simple and incremental (true — one new file, compatible migration); Builds on existing infrastructu...

### 2026-03-28T17:08:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b6123180
- **Timestamp:** 2026-06-02T15:03:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
