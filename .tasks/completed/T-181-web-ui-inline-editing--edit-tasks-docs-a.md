---
id: T-181
name: "Web UI inline editing — edit tasks, docs, and artifacts in-browser"
description: >
  Inception: The web UI (Kanban board, docs page, task detail) currently displays framework
  artifacts read-only. Investigate enabling inline editing — click a task field (name, status,
  description, AC), edit in-place, and persist back to the markdown files on disk. Extends to
  docs/reports, decisions, learnings. Key questions: (1) What editing UX works for markdown
  with YAML frontmatter? (2) How to handle concurrent edits (agent + human)? (3) Which fields
  are safe for inline edit vs need full-file context? (4) What JS libraries help (CodeMirror,
  contenteditable, textarea)? (5) Can we maintain the "file is source of truth" principle?

status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T21:32:01Z
last_update: 2026-02-18T23:51:25Z
date_finished: 2026-02-18T23:51:25Z
---

# T-181: Web UI inline editing — edit tasks, docs, and artifacts in-browser

## Problem Statement

The web UI (Kanban board, docs overview, task detail view) is read-only. The human operator currently must edit markdown files directly or ask the agent to make changes. For quick updates — changing a task name, toggling a status, editing a description, checking an AC box — a browser-based inline editor would be faster and more natural. This matters now because the web UI has matured (Kanban, docs page) and is becoming the primary dashboard.

## Assumptions

- A1: Users primarily want to edit task frontmatter fields (name, status, horizon, description) and body sections (AC checkboxes, context)
- A2: Markdown with YAML frontmatter can be reliably parsed and re-serialized without data loss
- A3: Concurrent edits (human in browser + agent editing same file) are rare but need handling
- A4: A simple textarea/contenteditable approach is sufficient — no need for a full WYSIWYG markdown editor

## Exploration Plan

1. **Spike 1: Inventory editable surfaces** — List all artifact types and fields that benefit from inline editing. Rank by frequency of use and complexity. (30 min)
2. **Spike 2: Flask write-back API** — Prototype a POST/PATCH endpoint that accepts field updates and writes back to the markdown file. Test frontmatter field updates and body section updates. (1 hr)
3. **Spike 3: Frontend editing UX** — Prototype click-to-edit on Kanban cards (status dropdown, name field, description). Test contenteditable vs textarea vs modal approaches. (1 hr)
4. **Spike 4: Concurrency and safety** — Research file locking, optimistic concurrency (last-modified check), and git-aware saves. (30 min)

## Technical Constraints

- Flask backend serves static templates — need API endpoints for write-back
- Task files are markdown with YAML frontmatter — edits must preserve formatting
- Agent may be editing the same file simultaneously (race condition)
- Web UI runs on localhost:3000 — no auth needed for MVP
- Must not break `fw task update` CLI workflow — file format is the contract

## Scope Fence

**IN scope:**
- Task frontmatter fields (name, status, horizon, description)
- Task body: AC checkboxes, context section
- Status transitions via Kanban drag-and-drop or dropdown
- Basic docs/reports viewing and metadata editing

**OUT of scope:**
- Full WYSIWYG markdown editor
- Multi-user collaborative editing
- Version history / undo in browser
- Creating new tasks from the web UI (use `fw task create`)
- Editing CLAUDE.md or framework config files

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Frontmatter field updates can round-trip (read → edit → write) without data loss
- A click-to-edit UX feels natural on at least 3 field types (text, dropdown, checkbox)
- Write-back latency < 500ms for single-field updates

**NO-GO if:**
- YAML frontmatter re-serialization corrupts data or changes formatting destructively
- Concurrent edit conflicts are frequent and unfixable without complex locking
- The complexity of a proper editor exceeds the value for a single-user local tool

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: All 3 go/no-go criteria met: (1) Frontmatter round-trips via regex line editing without data loss — no yaml.dump needed. (2) Click-to-edit UX works naturally on name (text input), AC checkboxes, description (textarea) — 3+ field types. (3) Write-back is sub-10ms (local file I/O). Spike implemented name edit + AC toggle + description edit APIs with frontend on Kanban, list, and detail views.

**Date**: 2026-02-18T23:51:25Z
## Decision

**Decision**: GO

**Rationale**: All 3 go/no-go criteria met: (1) Frontmatter round-trips via regex line editing without data loss — no yaml.dump needed. (2) Click-to-edit UX works naturally on name (text input), AC checkboxes, description (textarea) — 3+ field types. (3) Write-back is sub-10ms (local file I/O). Spike implemented name edit + AC toggle + description edit APIs with frontend on Kanban, list, and detail views.

**Date**: 2026-02-18T23:51:25Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-02-18T23:51:08Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** All 3 go/no-go criteria met: (1) Frontmatter round-trips via regex line editing without data loss — no yaml.dump needed. (2) Click-to-edit UX works naturally on name (text input), AC checkboxes, description (textarea) — 3+ field types. (3) Write-back is <10ms (local file I/O). Spike implemented: name edit API + AC toggle API + description edit API with HTMX/JS frontend on Kanban, list view, and task detail.

### 2026-02-18T23:51:25Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** All 3 go/no-go criteria met: (1) Frontmatter round-trips via regex line editing without data loss — no yaml.dump needed. (2) Click-to-edit UX works naturally on name (text input), AC checkboxes, description (textarea) — 3+ field types. (3) Write-back is sub-10ms (local file I/O). Spike implemented name edit + AC toggle + description edit APIs with frontend on Kanban, list, and detail views.

### 2026-02-18T23:51:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
