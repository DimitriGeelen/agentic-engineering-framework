---
id: T-402
name: "Bugfix-learning coverage: mine episodic history to close 25%→40% gap"
description: >
  Bugfix-learning coverage at 25% (14/56), target 40%. 48 bugfix tasks produced zero
  learnings. Mine episodic summaries for completed bugfix tasks, extract patterns,
  add learnings via fw fix-learned. Also consider structural trigger in update-task.sh
  for bugfix completions (G-016).

status: work-completed
workflow_type: refactor
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-10T09:44:36Z
last_update: '2026-08-16T22:25:29Z'
date_finished: 2026-03-10T12:51:27Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:20Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 3
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=3 (body:fw-recall-or-memory-link);
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=3 (body:fw-recall-or-memory-link);
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
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

## Reviewer Verdict (v1.5)

- **Scan ID:** R-00c210bf
- **Timestamp:** 2026-06-02T15:02:37Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
