---
id: T-006
name: "Record first project learning for __PROJECT_NAME__"
description: >
  Capture something learned during onboarding as the first project-specific learning.
  This validates the knowledge pipeline: learning → pattern → practice graduation.
status: captured
workflow_type: build
owner: agent
horizon: now
tags: [onboarding]
components: []
related_tasks: []
created: __DATE__
last_update: __DATE__
date_finished: null
---

# T-006: Record first project learning for __PROJECT_NAME__

## Context

Capture something learned during setup (a gotcha, a pattern, a shortcut) as a project-specific learning. This seeds the knowledge pipeline and proves the capture mechanism works.

## Acceptance Criteria

### Agent
- [ ] Identify something learned during T-001 through T-005
- [ ] Record it: `fw context add-learning "description" --task T-006`
- [ ] Verify it appears in `.context/project/learnings.yaml`

## Verification

# At least one project-specific learning exists
python3 -c "import yaml; d=yaml.safe_load(open('.context/project/learnings.yaml')); assert len(d.get('learnings',[])) >= 1, 'No learnings found'"
