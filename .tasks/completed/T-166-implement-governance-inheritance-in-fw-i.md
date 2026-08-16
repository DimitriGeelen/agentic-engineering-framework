---
id: T-166
name: "Implement governance inheritance in fw init — seed practices, decisions, and
  patterns"
description: >
  Implement governance inheritance in fw init — seed practices, decisions, and patterns

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
related_tasks: []
created: 2026-02-18T14:32:22Z
last_update: '2026-08-16T22:24:40Z'
date_finished: 2026-02-18T14:38:28Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:55Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 2
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=2 (body:default-change); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:40Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 2
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=2 (body:default-change); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-166: Implement governance inheritance in fw init — seed practices, decisions, and patterns

## Context

T-164 GO decision: 78% of framework governance (40/51 items) is universal. `fw init` should seed
practices, decisions, and patterns. Research: `.context/research/T-164-*.md`

## Acceptance Criteria

- [x] Seed files created: `lib/seeds/{practices,decisions,patterns}.yaml` with scope tags
- [x] `fw init` copies seeds instead of empty governance files
- [x] New governance items default to `scope: project` (pattern.sh, decision.sh, promote.sh)
- [x] Sprechloop retroactively seeded with universal governance
- [x] All seed YAML files parse correctly (10 practices, 18 decisions, 12 patterns)
- [x] `fw init --force` on test directory seeds governance correctly

## Verification

# Seed files parse correctly
python3 -c "import yaml; d=yaml.safe_load(open('lib/seeds/practices.yaml')); assert len(d['practices'])==10"
python3 -c "import yaml; d=yaml.safe_load(open('lib/seeds/decisions.yaml')); assert len(d['decisions'])==18"
python3 -c "import yaml; d=yaml.safe_load(open('lib/seeds/patterns.yaml')); total=sum(len(v) for v in d.values() if isinstance(v,list)); assert total==12"
# All seeded items have scope: universal
python3 -c "import yaml; d=yaml.safe_load(open('lib/seeds/practices.yaml')); assert all(p.get('scope')=='universal' for p in d['practices'])"
# Sprechloop has practices now
python3 -c "import yaml; d=yaml.safe_load(open('/opt/001-sprechloop/.context/project/practices.yaml')); assert len(d['practices'])>=10"

## Decisions

### 2026-02-18 — Seed file approach vs copy-and-filter
- **Chose:** Curated seed files in `lib/seeds/` with `scope: universal` tags
- **Why:** Explicit control over what gets inherited. No filter logic needed at init time. Forward-compatible — new items tagged `scope: project` by default, promoted to universal manually.
- **Rejected:** Copy framework files and filter (fragile filter logic), Copy as-is (includes project-specific items), Reference symlinks (breaks portability)

## Updates

### 2026-02-18T14:32:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-166-implement-governance-inheritance-in-fw-i.md
- **Context:** Initial task creation

### 2026-02-18T14:38:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b6769e39
- **Timestamp:** 2026-06-02T14:59:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
