---
id: T-141
name: Fix create-task.sh template wiring + backfill sprechloop knowledge + add 
  tests
description: >
  Fix create-task.sh template wiring + backfill sprechloop knowledge + add tests
status: work-completed
workflow_type: build
horizon:
owner: agent
tags: []
related_tasks: []
created: 2026-02-18T08:07:34Z
last_update: '2026-08-16T22:24:31Z'
date_finished: 2026-02-18T08:32:16Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
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
  - ts: '2026-08-16T22:24:31Z'
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

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6b248e2e
- **Timestamp:** 2026-06-02T14:57:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
