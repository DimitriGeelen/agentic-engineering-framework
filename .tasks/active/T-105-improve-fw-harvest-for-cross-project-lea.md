---
id: T-105
name: Improve fw harvest for cross-project learning
description: >
  fw harvest (lib/harvest.sh) handles patterns, learnings, and decisions but misses the highest-value knowledge sources. Gaps to fix: (1) Episodic memory not harvested — .context/episodic/T-*.yaml files contain rich completed-task data (summary, outcomes, challenges, decisions, metrics). These are the densest knowledge artifacts and harvest.sh never touches them. Add harvest_episodics() that copies/anonymizes relevant episodics to framework. (2) Practices not harvested — .context/project/practices.yaml (graduated learnings with 3+ applications) never read. Add harvest_practices(). (3) CLAUDE.md improvements not harvested — project may extend CLAUDE.md with project-specific protocols that have framework value. Add diff detection between project CLAUDE.md and template to surface additions. (4) Consider adding provenance tracking — when a learning is harvested, record which project(s) it came from and how many projects have seen the same pattern (feeds graduation pipeline). INDEPENDENT — no dependencies on other tasks, can be done in parallel. Files: lib/harvest.sh.
status: captured
workflow_type: build
owner: agent
tags: [fw-harvest, cross-project, learning, episodic]
related_tasks: []
created: 2026-02-17T08:54:11Z
last_update: 2026-02-17T08:54:11Z
date_finished: null
---

# T-105: Improve fw harvest for cross-project learning

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-17T08:54:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-105-improve-fw-harvest-for-cross-project-lea.md
- **Context:** Initial task creation
