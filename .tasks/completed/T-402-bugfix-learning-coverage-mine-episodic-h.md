---
id: T-402
name: "Bugfix-learning coverage: mine episodic history to close 25%→40% gap"
description: >
  Bugfix-learning coverage at 25% (14/56), target 40%. 48 bugfix tasks produced zero learnings. Mine episodic summaries for completed bugfix tasks, extract patterns, add learnings via fw fix-learned. Also consider structural trigger in update-task.sh for bugfix completions (G-016).

status: work-completed
workflow_type: refactor
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-10T09:44:36Z
last_update: 2026-03-10T12:51:27Z
date_finished: 2026-03-10T12:51:27Z
---

# T-402: Bugfix-learning coverage: mine episodic history to close 25%→40% gap

## Context

Bugfix-learning coverage was 25% (14/56). Mined episodic summaries for 9 high-value completed bugfix tasks (hook wiring, enforcement gates, YAML processing, config generation) and added learnings via `fw context add-learning`. Coverage now 41% (26/63).

## Acceptance Criteria

### Agent
- [x] Mined episodic history for completed bugfix tasks without learnings
- [x] Added 9 new learnings from highest-value categories (hook/config, enforcement, YAML, portability)
- [x] Bugfix-learning coverage >= 40%
- [x] learnings.yaml parses cleanly

## Verification

# learnings.yaml parses
python3 -c "import yaml; yaml.safe_load(open('.context/project/learnings.yaml'))"
# Coverage >= 40%
python3 -c "import yaml,glob,os; data=yaml.safe_load(open('.context/project/learnings.yaml')); ls=data.get('learnings',[]); ts=set(l.get('task','') for l in ls if l.get('task')); bc=len(glob.glob('.tasks/completed/T-*fix*.md')+glob.glob('.tasks/completed/T-*bug*.md')); wl=sum(1 for f in glob.glob('.tasks/completed/T-*fix*.md')+glob.glob('.tasks/completed/T-*bug*.md') if os.path.basename(f).split('-')[0]+'-'+os.path.basename(f).split('-')[1] in ts); assert wl/bc>=0.40, f'{wl}/{bc}={100*wl/bc:.0f}%'"
# At least 90 learnings total
python3 -c "import yaml; data=yaml.safe_load(open('.context/project/learnings.yaml')); assert len(data.get('learnings',[]))>=90"

## Decisions

None — straightforward mining of existing episodic history.

## Updates

### 2026-03-10T09:44:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-402-bugfix-learning-coverage-mine-episodic-h.md
- **Context:** Initial task creation

### 2026-03-10T12:48:14Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-10T12:51:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
