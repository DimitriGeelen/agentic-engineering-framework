---
id: T-050
name: CLI discovery commands (sovereignty backstop)
description: >
  Add discovery CLI commands to fw as sovereignty backstop — these work without the web UI or AI. (1) fw task list: all tasks filterable by --status, --type, --component. Data from episodic files. (2) fw decisions: all decisions with rationale, both architectural and operational. (3) fw timeline: structured chronological list of sessions and tasks. (4) fw learnings: all learnings with context. (5) fw patterns: failure/success/workflow patterns. (6) fw practices: graduated principles. (7) fw task show T-XXX: episodic summary for a single task. (8) fw search keyword: grep across all YAML + MD artifacts. All read-only terminal output. Can run in parallel with web UI development. Design authority: 025-ArtifactDiscovery.md. Relevant sections: fw CLI Commands table, Four-Layer Architecture (CLI is Layer 3). No dependencies — independent of web UI.
status: captured
workflow_type: build
owner: claude-code
priority: medium
tags: []
agents:
  primary:
  supporting: []
created: 2026-02-14T11:34:55Z
last_update: 2026-02-14T11:34:55Z
date_finished: null
---

# T-050: CLI discovery commands (sovereignty backstop)

## Design Record

**Design authority:** [025-ArtifactDiscovery.md](../../025-ArtifactDiscovery.md)
**Relevant sections:** fw CLI Commands table, Four-Layer Architecture (CLI is Layer 3)

**Key decisions:**
- CLI commands are the sovereignty backstop — work without web UI or AI
- All commands are read-only terminal output
- Data sources same as web UI (episodic files, project memory YAML)
- Human-readable by default, pipe-friendly output
- Can be developed in parallel with web UI — no dependencies

**No dependencies — independent track.**

## Specification Record

### Acceptance Criteria
- [ ] `fw task list` shows all tasks, filterable by --status, --type, --component
- [ ] `fw task show T-XXX` shows episodic summary for one task
- [ ] `fw decisions` shows all decisions with rationale
- [ ] `fw timeline` shows structured chronological list
- [ ] `fw learnings` shows all learnings with context
- [ ] `fw patterns` shows failure/success/workflow patterns
- [ ] `fw practices` shows graduated principles
- [ ] `fw search <keyword>` greps across all YAML + MD artifacts
- [ ] All commands produce clean terminal output (colors, alignment)
- [ ] All commands work from any project using fw (respects PROJECT_ROOT)

## Test Files

[References to test scripts and test artifacts]

## Updates

### 2026-02-14T11:34:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-050-cli-discovery-commands-sovereignty-backs.md
- **Context:** Initial task creation
