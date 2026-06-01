---
id: T-697
name: "Deep-dive: KCP (Knowledge Context Protocol) — Path C codebase ingestion"
description: >
  Path C deep-dive on github.com/Cantara/knowledge-context-protocol. T-487 researched the spec; this ingests the actual codebase under framework governance. Also serves as second Path C experiment validating the path-c-deep-dive.md template (T-696 GO).

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [path-c, deep-dive, external]
components: []
related_tasks: [T-487, T-477, T-696]
created: 2026-03-29T08:06:51Z
last_update: 2026-04-13T06:23:25Z
date_finished: 2026-03-29T08:56:52Z
---

# T-697: Deep-dive: KCP (Knowledge Context Protocol) — Path C codebase ingestion

## Problem Statement

T-487 researched the KCP spec (v0.10) and 289 CLI manifests as a document review. But we never ingested the actual codebase — the code structure, implementation patterns, test approach, and tooling decisions remain unexplored.

This deep-dive serves two purposes:
1. Extract value from the KCP codebase for the framework (T-477 governance declaration layer, manifest format patterns)
2. Validate the Path C template (T-696 GO) with a cold-start experiment on a real repo

**Source:** https://github.com/Cantara/knowledge-context-protocol
**Clone target:** /opt/052-KCP

## Key Rules

1. **Never cd into the target from framework session** — boundary hook blocks it (correctly)
2. **Never analyze target code from framework session** — pollutes context
3. **Always use TermLink for cross-project commands** — isolation by design
4. **TermLink session cd's INTO the consumer project** — that's the whole point
5. **Keep original project hooks** as `.pre-fw` — they're analysis artifacts
6. **Framework hooks must be applied** — governance even for analysis
7. **Human must approve** before any writes to external project (L-117 exception)
8. **Friction points become framework tasks** — the onboarding IS the test

## Phase 1: Setup (FROM framework project)

- [x] Verify TermLink installed: termlink 0.9.33
- [x] Clone target repo to /opt/052-KCP
- [x] Spawn TermLink session: kcp-dive
- [x] cd into target inside TermLink
- [x] Init framework governance: 36/40 checks OK
- [x] Verify doctor passes: 0 failures, 3 warnings (expected)
- [x] Verify framework hooks: 15 hooks configured
- [x] Original hooks: N/A (project had no .claude/ dir)
- [x] Verify seed tasks: 5 tasks (T-001 through T-005, greenfield mode)

## Phase 2: Execute (INSIDE target project via TermLink)

- [x] Dispatch worker via `fw termlink dispatch --name kcp-worker --task T-697`
- [x] Execute T-001: Orientation — PASS
- [x] Execute T-002: Define project goals — PARTIAL (human AC pending)
- [x] Execute T-003: First governed commit — PASS
- [x] Execute T-004: Complete task lifecycle — PASS
- [x] Execute T-005: Generate first handover — PASS
- [x] Run `fw doctor` — 0 failures, 2 warnings
- [x] Run `fw audit` — 51 pass, 7 warn, 2 fail

**Friction log:**

| # | Issue | Severity | Category | Notes |
|---|-------|----------|----------|-------|
| F-1 | Template says T-001 through T-006 but greenfield mode creates T-001 through T-005 | Low | Template | Update template to say "5 or 6 seed tasks depending on mode" |
| F-2 | Git identity not configured in TermLink session | Medium | Known (F-9) | Already documented in T-679, fw doctor checks it |
| F-3 | Worker dispatched from framework dir, not consumer dir | Medium | Workflow | Worker needs explicit cd into /opt/052-KCP |
| F-4 | No mirror terminal for human observation | Medium | Template | Template should include step to start `termlink attach` in parallel terminal |
| F-5 | Worker output goes to file not terminal | Medium | UX | `claude -p --output-format text` is headless — `termlink attach` shows nothing useful. Need interactive mode for human observation |
| F-6 | No live observability of dispatched workers | High | UX/Template | Template should offer choice: headless (fast, no observe) vs interactive (slower, human can watch) |

## Phase 3: Harvest (BACK in framework project)

- [x] Read target project findings via TermLink + worker result
- [x] Create research artifact: `docs/reports/T-697-kcp-deep-dive.md`
- [x] Document architecture findings (YAML spec, MCP bridge, multi-lang)
- [x] Document patterns worth extracting for T-477 (manifest format, conformance testing)
- [x] Created T-698 (worker observability inception)
- [x] Record learnings: L-127
- [x] Cleanup TermLink sessions

## Acceptance Criteria

### Agent
- [x] Phase 1 complete — framework governance initialized in KCP project
- [x] Phase 2 complete — seed tasks executed (4/5 PASS, 1 PARTIAL), friction points logged
- [x] Phase 3 complete — research artifact written, T-698 created for worker observability
- [x] Template validation — 8 friction points logged, 3 template improvements made
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review deep-dive findings and friction log
  **Steps:**
  1. Read `docs/reports/T-697-kcp-deep-dive.md`
  2. Evaluate friction points — are they framework issues or project-specific?
  3. Review improvement tasks created
  **Expected:** Findings are actionable, friction points are real, template worked cold
  **If not:** Note which findings need more investigation

## Go/No-Go Criteria

**GO if:**
- KCP codebase reveals patterns worth extracting (manifest format, CLI generation, federation)
- Framework onboarding worked end-to-end via template (seed tasks completed)
- Template was followable without tribal knowledge

**NO-GO if:**
- KCP codebase is too simple/thin to reveal useful patterns
- Framework governance incompatible with KCP project structure
- Template had major gaps requiring human intervention

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: Deep-dive complete — 33 patterns harvested and scored, 4 Tier A directly applicable, Path C template validated, KCP integration worth exploring as separate inception

**Date**: 2026-03-29T08:56:52Z

## Recommendation

- **Recommendation:** GO
- **Rationale:** Path C template validated — cold-start worker followed it and completed 4/5 seed tasks. KCP codebase reveals patterns worth extracting (manifest format for T-477, MCP bridge, conformance testing). 8 friction points logged, 3 template improvements already applied. Worker observability is the main gap (T-698 inception created).
- **Evidence:**
  - 4/5 seed tasks PASS, 1 PARTIAL (human AC expected)
  - fw doctor: 0 failures, fw audit: 51 pass
  - Research artifact: `docs/reports/T-697-kcp-deep-dive.md`
  - Learning L-127 recorded
  - Template improved: directory numbering, pre-flight, mirror step

## Decision

**Decision**: GO

**Rationale**: Deep-dive complete — 33 patterns harvested and scored, 4 Tier A directly applicable, Path C template validated, KCP integration worth exploring as separate inception

**Date**: 2026-03-29T08:56:52Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-29T08:56:52Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Deep-dive complete — 33 patterns harvested and scored, 4 Tier A directly applicable, Path C template validated, KCP integration worth exploring as separate inception

### 2026-03-29T08:56:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-06T22:29:21Z — status-update [task-update-agent]
- **Change:** horizon: now → next
