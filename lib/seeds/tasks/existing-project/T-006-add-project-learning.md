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

## For the Operator

**What is happening:** the last step of the prologue. The agent records one thing it
actually learned during T-001 through T-005 as a **learning** — a durable note that later
sessions read.

**Why it matters to you:** this is the framework's first directive, antifragility, made
concrete. A failure or a surprise is supposed to leave the project stronger than it found
it, and that only works if the lesson outlives the session that learned it. Learnings are
surfaced back at task creation, so the next agent gets told before it repeats you.

Worth checking what it wrote. A learning like *"the framework has hooks"* is noise; a
learning like *"`fw audit` exits 1 for warnings, so `test $? -le 1` is the right check"* is
the kind that saves someone an hour. You are a better judge of that than it is.

**After this task closes, the prologue is over.** The gate holding the agent to onboarding
work lifts, and it starts on whatever you actually came here to build. That is the moment
this curriculum exists for: you should now have enough of the model to follow along,
disagree, and redirect.

**Go deeper:** `fw corpus explain aef-audit-cron` — how the framework keeps checking itself
without being asked. And Watchtower `/designer` for every map at once.

## Acceptance Criteria

### Agent
- [ ] Identify something learned during T-001 through T-005
- [ ] Record it: `fw context add-learning "description" --task T-006`
- [ ] Verify it appears in `.context/project/learnings.yaml`

## Verification

# At least one project-specific learning exists
python3 -c "import yaml; d=yaml.safe_load(open('.context/project/learnings.yaml')); assert len(d.get('learnings',[])) >= 1, 'No learnings found'"
