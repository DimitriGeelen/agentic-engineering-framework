---
id: T-050
name: CLI discovery commands (sovereignty backstop)
description: >
  Add discovery CLI commands to fw as sovereignty backstop — these work without the
  web UI or AI. (1) fw task list: all tasks filterable by --status, --type, --component.
  Data from episodic files. (2) fw decisions: all decisions with rationale, both architectural
  and operational. (3) fw timeline: structured chronological list of sessions and
  tasks. (4) fw learnings: all learnings with context. (5) fw patterns: failure/success/workflow
  patterns. (6) fw practices: graduated principles. (7) fw task show T-XXX: episodic
  summary for a single task. (8) fw search keyword: grep across all YAML + MD artifacts.
  All read-only terminal output. Can run in parallel with web UI development. Design
  authority: 025-ArtifactDiscovery.md. Relevant sections: fw CLI Commands table, Four-Layer
  Architecture (CLI is Layer 3). No dependencies — independent of web UI.
status: work-completed
workflow_type: build
owner: claude-code
priority: medium
tags: []
agents:
  primary:
  supporting: []
created: 2026-02-14T11:34:55Z
last_update: '2026-06-11T22:23:36Z'
date_finished: 2026-02-14T12:27:34Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:36Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
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

### 2026-02-14T12:18:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-14T12:24:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-02-14T12:27:26Z — status-update [task-update-agent]
- **Change:** status: work-completed → started-work

### 2026-02-14T12:27:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-29bc7fa9
- **Timestamp:** 2026-06-02T14:54:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
