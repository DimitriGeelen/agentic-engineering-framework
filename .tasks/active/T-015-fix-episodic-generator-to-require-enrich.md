---
id: T-015
name: Fix episodic generator to require enrichment
description: >
  The episodic generator produces empty templates that look complete but contain no useful content. Fix by: (1) Add enrichment_status: pending|complete field, (2) Replace empty sections with explicit TODO prompts for LLM enrichment, (3) Make incomplete episodics visually obvious. Per multi-agent review finding.
status: captured
workflow_type: build
owner: human
priority: high
tags: [context-fabric, D1, D2, D3]
agents:
  primary:
  supporting: []
created: 2026-02-13T21:21:25Z
last_update: 2026-02-13T21:21:25Z
date_finished: null
---

# T-015: Fix episodic generator to require enrichment

## Design Record

[Architecture decisions, approach rationale — inline or link to artifact]

## Specification Record

[Requirements, acceptance criteria — inline or link to artifact]

## Test Files

[References to test scripts and test artifacts]

## Updates

### 2026-02-13T21:21:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-015-fix-episodic-generator-to-require-enrich.md
- **Context:** Initial task creation
