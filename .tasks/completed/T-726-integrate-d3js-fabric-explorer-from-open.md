---
id: T-726
name: "Integrate D3.js Fabric Explorer from OpenClaw evaluation into upstream Watchtower"
description: >
  Inception: Integrate D3.js Fabric Explorer from OpenClaw evaluation into upstream Watchtower

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-29T19:55:54Z
last_update: 2026-04-13T06:23:27Z
date_finished: 2026-03-29T20:13:36Z
---

# T-726: Integrate D3.js Fabric Explorer from OpenClaw evaluation into upstream Watchtower

## Problem Statement

The current Watchtower `/fabric/graph` uses Cytoscape.js with static subsystem-only visualization. During the OpenClaw evaluation (T-141 through T-157), a production-ready D3.js interactive Fabric Explorer was built with 1,584 LOC template + 379 LOC backend + 26 tests. This needs to be integrated into upstream Watchtower, replacing the static graph with an interactive explorer that supports component expansion, source viewing, report viewing, and pathfinding.

**Source pickup:** `/opt/openclaw-evaluation/.context/working/T-158-fabric-explorer-pickup.md`
**Research artifact:** `docs/reports/T-726-fabric-explorer-integration.md`

## Assumptions

- A-1: The OpenClaw evaluation's fabric.py routes are compatible with the framework's existing fabric blueprint
- A-2: D3 v7 doesn't conflict with existing Watchtower JS (Pico CSS, htmx)
- A-3: The CSS isolation (`all: initial` scoped class) prevents style bleeding
- A-4: The source/report API routes have adequate security (path traversal protection)

## Exploration Plan

1. **Diff analysis** (15 min) — Compare openclaw fabric.py vs framework fabric.py to identify merge conflicts and route overlaps
2. **Template compatibility** (10 min) — Check that fabric_explorer.html works with the framework's Jinja2 base template
3. **Security review** (10 min) — Verify source/report API path traversal protection
4. **Integration test** (15 min) — Copy files, start server, verify routes work
5. **Recommendation** — GO/NO-GO with rationale

## Technical Constraints

- Flask + Jinja2 + Pico CSS + htmx (existing Watchtower stack)
- D3 v7 vendored (no CDN dependency)
- Must not break existing `/fabric` and `/fabric/component/<name>` routes
- Source API needs path traversal protection (realpath + PROJECT_ROOT containment)

## Scope Fence

**IN scope:** Integration assessment, conflict analysis, security review, GO/NO-GO recommendation
**OUT of scope:** Actual integration (that's a build task after GO), Playwright E2E tests

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Diff analysis of fabric.py (openclaw vs framework)
- [x] Template compatibility assessment
- [x] Security review of source/report API routes
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read `docs/reports/T-726-fabric-explorer-integration.md`
  2. Evaluate go/no-go criteria against findings
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-726 go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Source files exist and are production-quality (tested, documented)
- No breaking conflicts with existing fabric routes
- Security is adequate (path traversal protection verified)
- Integration is bounded (copy + adapt, not rewrite)

**NO-GO if:**
- Major architectural incompatibility requiring rewrite
- Security vulnerabilities in source/report API
- D3 conflicts with existing Watchtower JS

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: - Recommendation: GO
- Rationale: Production-quality code (26 tests, 1,963 LOC) with no breaking changes, security review passed, bounded integration effort (copy + adapt paths). Major UX improvement over static Cytoscape graph.
- Evidence:
  - Diff analysis shows 4 shared functions (identical), 1 enhanced function, 1 replaced route, 2 new routes
  - CSS isolation (`all: initial`) prevents Pico CSS conflicts
  - Path traversal protection via `os.path.realpath()` + containment check
  - D3 v7 ...

**Date**: 2026-03-29T20:13:36Z

## Recommendation

- **Recommendation:** GO
- **Rationale:** Production-quality code (26 tests, 1,963 LOC) with no breaking changes, security review passed, bounded integration effort (copy + adapt paths). Major UX improvement over static Cytoscape graph.
- **Evidence:**
  - Diff analysis shows 4 shared functions (identical), 1 enhanced function, 1 replaced route, 2 new routes
  - CSS isolation (`all: initial`) prevents Pico CSS conflicts
  - Path traversal protection via `os.path.realpath()` + containment check
  - D3 v7 vendored, no external dependency conflicts
  - All source artifacts on disk at `/opt/openclaw-evaluation/`

## Decision

**Decision**: GO

**Rationale**: - Recommendation: GO
- Rationale: Production-quality code (26 tests, 1,963 LOC) with no breaking changes, security review passed, bounded integration effort (copy + adapt paths). Major UX improvement over static Cytoscape graph.
- Evidence:
  - Diff analysis shows 4 shared functions (identical), 1 enhanced function, 1 replaced route, 2 new routes
  - CSS isolation (`all: initial`) prevents Pico CSS conflicts
  - Path traversal protection via `os.path.realpath()` + containment check
  - D3 v7 ...

**Date**: 2026-03-29T20:13:36Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-29T19:56:27Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-29T20:13:36Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** - Recommendation: GO
- Rationale: Production-quality code (26 tests, 1,963 LOC) with no breaking changes, security review passed, bounded integration effort (copy + adapt paths). Major UX improvement over static Cytoscape graph.
- Evidence:
  - Diff analysis shows 4 shared functions (identical), 1 enhanced function, 1 replaced route, 2 new routes
  - CSS isolation (`all: initial`) prevents Pico CSS conflicts
  - Path traversal protection via `os.path.realpath()` + containment check
  - D3 v7 ...

### 2026-03-29T20:13:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-06T22:29:22Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-93ac4280
- **Timestamp:** 2026-06-02T15:04:34Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
