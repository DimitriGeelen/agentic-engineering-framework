---
id: T-141
name: Fix create-task.sh template wiring + backfill sprechloop knowledge + add tests
description: >
  Fix create-task.sh template wiring + backfill sprechloop knowledge + add tests
status: work-completed
workflow_type: build
horizon: now
owner: agent
tags: []
related_tasks: []
created: 2026-02-18T08:07:34Z
last_update: 2026-02-18T08:32:16Z
date_finished: 2026-02-18T08:32:16Z
---

# T-141: Fix create-task.sh template wiring + backfill sprechloop knowledge + add tests

## Context

Root cause: T-124 validation revealed sprechloop tasks were thin (no Decisions, weak AC/Verification) because `create-task.sh` used a hardcoded heredoc instead of `default.md` template. Also `add-pattern` command never wrote because `init.sh` created `patterns: []` but `pattern.sh` expected `failure_patterns:` sections. Also `learnings: []` and `decisions: []` headers created invalid YAML when entries appended after them.

Predecessor: T-140 (inception — root cause analysis). Parent: T-124 (framework validation).

## Acceptance Criteria

- [x] create-task.sh uses default.md template for non-inception tasks
- [x] P-011 verification gate strips HTML comment blocks before extracting commands
- [x] add-pattern writes to patterns.yaml and produces valid YAML
- [x] add-learning writes to learnings.yaml and produces valid YAML
- [x] add-decision writes to decisions.yaml and produces valid YAML
- [x] init.sh creates YAML files in format compatible with add-* commands
- [x] Old format migration: `patterns: []` auto-converts to sectioned format
- [x] Old format migration: `learnings: []` / `decisions: []` auto-converts
- [x] Sprechloop knowledge backfill: 15 learnings, 8 decisions, 5 patterns — all parseable
- [x] Test suite: tests/test-knowledge-capture.sh (21 tests, all pass)

## Verification

tests/test-knowledge-capture.sh
python3 -c "import yaml; d=yaml.safe_load(open('/opt/001-sprechloop/.context/project/patterns.yaml')); assert len(d.get('failure_patterns', [])) >= 2"
python3 -c "import yaml; d=yaml.safe_load(open('/opt/001-sprechloop/.context/project/learnings.yaml')); assert len(d.get('learnings', [])) >= 15"
python3 -c "import yaml; d=yaml.safe_load(open('/opt/001-sprechloop/.context/project/decisions.yaml')); assert len(d.get('decisions', [])) >= 8"

## Updates

### 2026-02-18T08:07:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-141-fix-create-tasksh-template-wiring--backf.md
- **Context:** Initial task creation

### 2026-02-18T08:32:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
