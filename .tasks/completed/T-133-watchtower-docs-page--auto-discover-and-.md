---
id: T-133
name: "Watchtower: Docs page — auto-discover and surface project design docs"
description: >
  Watchtower Docs nav link exists but page is empty. Investigate: (1) Auto-discover docs from docs/ and docs/plans/ directories (design docs, inception plans, ADRs). (2) Surface CLAUDE.md and FRAMEWORK.md as top-level project docs. (3) Index docs with metadata (title, date, related task, type). (4) For projects like sprechloop: the inception plan (1820 lines) and design doc (339 lines) should automatically appear here. Consider: should this be a file-system scan on page load, or a build-time index?

status: work-completed
workflow_type: inception
owner: human
horizon: later
tags: []
related_tasks: []
created: 2026-02-17T23:30:32Z
last_update: 2026-02-18T18:06:19Z
date_finished: 2026-02-18T18:06:19Z
---

# T-133: Watchtower: Docs page — auto-discover and surface project design docs

## Problem Statement

The Docs page (`/project`) exists but only discovers root-level `0*.md` files and `FRAMEWORK.md`. It misses:
- `docs/` subdirectory (7 files in framework, 4+ in Sprechloop including 1820-line inception plan)
- `CLAUDE.md` (the most important project doc)
- `docs/plans/` subdirectory (Sprechloop design docs)
- Agent docs (`agents/*/AGENT.md`)

For projects like Sprechloop, the Docs page shows nothing useful because their docs are in `docs/plans/`, not root `0*.md` files. The page needs to auto-discover docs from standard locations.

## Current State

- **Backend** (`core.py:254-262`): `PROJECT_ROOT.glob("0*.md")` + `FRAMEWORK.md` only
- **Template** (`project.html`): Simple table with name + filename columns
- **Rendering** (`core.py:265-281`): Already renders any `.md` file via markdown2 — the viewer works, only discovery is broken
- **Framework docs**: 10 root .md files + 7 in `docs/` + 8 `AGENT.md` files
- **Sprechloop docs**: 0 root `0*.md` files, 2 in `docs/plans/`, 1 `CLAUDE.md`, 1 `README.md`

## Assumptions

- A1: Most projects keep docs in predictable locations (`docs/`, root `.md`, `agents/*/AGENT.md`)
- A2: File-system scan on page load is fast enough (< 50 files per project)
- A3: Users want docs grouped by category (governance, design, agent, project)

## Exploration Plan

Single spike: expand the `project()` function to scan standard locations, categorize results, and update the template to show grouped docs. ~30min.

## Scope Fence

**IN:** Auto-discover from `*.md` root, `docs/**/*.md`, `agents/*/AGENT.md`, `CLAUDE.md`, `FRAMEWORK.md`
**OUT:** Full-text search within docs. Edit/write docs from UI. Metadata extraction (date, related task). Those are future tasks.

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- File scan takes < 200ms for framework project (25+ docs)
- Grouped display makes docs findable for both framework and Sprechloop

**NO-GO if:**
- Discovery is too slow or unreliable across project structures
- Categories don't make sense for consumer projects

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: Scan takes 5ms for 52 files. Discovery pattern is clear: 4 categories (governance, design, agent, project). Current page misses 80% of docs. Simple backend change + template update.

**Date**: 2026-02-18T18:06:19Z
## Decision

**Decision**: GO

**Rationale**: Scan takes 5ms for 52 files. Discovery pattern is clear: 4 categories (governance, design, agent, project). Current page misses 80% of docs. Simple backend change + template update.

**Date**: 2026-02-18T18:06:19Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-02-18T18:04:08Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-18T18:06:10Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Scan takes 5ms for 52 files. Discovery pattern is clear: 4 categories (governance, design, agent, project). Current page misses 80% of docs. Simple backend change + template update.

### 2026-02-18T18:06:19Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Scan takes 5ms for 52 files. Discovery pattern is clear: 4 categories (governance, design, agent, project). Current page misses 80% of docs. Simple backend change + template update.

### 2026-02-18T18:06:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
