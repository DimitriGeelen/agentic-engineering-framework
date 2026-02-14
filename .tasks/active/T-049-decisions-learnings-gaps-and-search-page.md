---
id: T-049
name: Decisions, learnings, gaps, and search pages
description: >
  Build four YAML-backed web pages using same render pattern. (1) /decisions: unified view of architectural decisions (from 005-DesignDirectives.md, IDs AD-001+) and operational decisions (from decisions.yaml, IDs D-001+). Each shows rationale, directives served, originating task. Type label distinguishes architectural vs operational. (2) /learnings: tabbed or sectioned view of learnings (learnings.yaml), failure/success/workflow patterns (patterns.yaml), and practices (practices.yaml). Each links to originating task. (3) /gaps: gap register from gaps.yaml. Shows severity, trigger status, evidence collected. Editable fields: severity, evidence_collected, last_reviewed. Read-only: trigger_check.check (contains shell). (4) /search?q=keyword: cross-artifact keyword search across all YAML + MD files. Results grouped by artifact type with file path and matching context. All pages read-only except gaps light edits. Design authority: 025-ArtifactDiscovery.md. Relevant sections: Web UI Pages table, Q3 Decision stores, Write-Back Safety Model. Depends on: T-043 (directive IDs for decision linking), T-045 (web foundation).
status: captured
workflow_type: build
owner: claude-code
priority: medium
tags: []
agents:
  primary:
  supporting: []
created: 2026-02-14T11:34:46Z
last_update: 2026-02-14T11:34:46Z
date_finished: null
---

# T-049: Decisions, learnings, gaps, and search pages

## Design Record

**Design authority:** [025-ArtifactDiscovery.md](../../025-ArtifactDiscovery.md)
**Relevant sections:** Web UI Pages table, Q3 Decision stores, Write-Back Safety Model

**Key decisions:**
- /decisions: unified view of architectural (AD-001+) and operational (D-001+) decisions with type label
- /learnings: tabbed/sectioned view of learnings, patterns (failure/success/workflow), practices
- /gaps: shows severity, trigger status, evidence. Editable: severity, evidence_collected, last_reviewed. Read-only: trigger_check.check
- /search: keyword grep across all YAML + MD files, results grouped by artifact type
- All pages read YAML on demand, no caching

**Dependencies:** T-043 (directive IDs for decision linking), T-045 (web foundation)

## Specification Record

### Acceptance Criteria
- [ ] /decisions shows both architectural and operational decisions with type label
- [ ] Each decision shows: rationale, directives served (clickable), originating task (clickable)
- [ ] /learnings shows learnings, patterns (3 types), practices in organized sections
- [ ] Each entry links to originating task
- [ ] /gaps shows all gaps with severity badge, trigger status, evidence
- [ ] Gaps: severity and evidence_collected are editable inline
- [ ] /search accepts keyword, returns results grouped by type with context snippets
- [ ] Search covers: tasks, episodics, decisions, learnings, patterns, practices, gaps, specs

## Test Files

[References to test scripts and test artifacts]

## Updates

### 2026-02-14T11:34:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-049-decisions-learnings-gaps-and-search-page.md
- **Context:** Initial task creation
