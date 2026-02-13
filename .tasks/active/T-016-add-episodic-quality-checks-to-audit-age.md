---
id: T-016
name: Add episodic quality checks to audit agent
description: >
  Audit agent has ZERO episodic checks. Add: (1) Check all completed tasks have episodic files, (2) Check episodic summary field is non-empty (>50 chars), (3) Check successes OR challenges has entries, (4) Check decisions populated if Design Record exists. FAIL on missing, WARN on low-quality.
status: captured
workflow_type: build
owner: human
priority: high
tags: [audit, D2, P-002]
agents:
  primary:
  supporting: []
created: 2026-02-13T21:21:30Z
last_update: 2026-02-13T21:21:30Z
date_finished: null
---

# T-016: Add episodic quality checks to audit agent

## Design Record

[Architecture decisions, approach rationale — inline or link to artifact]

## Specification Record

[Requirements, acceptance criteria — inline or link to artifact]

## Test Files

[References to test scripts and test artifacts]

## Updates

### 2026-02-13T21:21:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-016-add-episodic-quality-checks-to-audit-age.md
- **Context:** Initial task creation
