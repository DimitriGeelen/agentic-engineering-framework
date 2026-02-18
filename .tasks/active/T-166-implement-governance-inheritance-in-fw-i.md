---
id: T-166
name: "Implement governance inheritance in fw init — seed practices, decisions, and patterns"
description: >
  Implement governance inheritance in fw init — seed practices, decisions, and patterns

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T14:32:22Z
last_update: 2026-02-18T14:32:22Z
date_finished: null
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
