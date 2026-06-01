---
id: T-1219
name: "Fabric enrichment — reduce edgeless cards from 49 to <20"
description: >
  Fabric enrichment — reduce edgeless cards from 49 to <20

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-13T10:22:22Z
last_update: 2026-04-13T10:27:35Z
date_finished: 2026-04-13T10:27:35Z
---

# T-1219: Fabric enrichment — reduce edgeless cards from 49 to <20

## Context

Audit shows 49/394 fabric cards with no edges. This makes impact analysis less useful — files that
are dependencies or dependents of other files show as isolated nodes. Enrich cards by reading source
files and identifying their dependencies (source/import/require statements).

## Acceptance Criteria

### Agent
- [x] Edgeless card count reduced to <20 (from 49; 0 non-test remaining)
- [x] No orphaned or stale edges introduced
- [x] Fabric drift check passes

## Verification

# Count non-test edgeless cards — must be below 10
python3 -c "import yaml,sys; cards=[yaml.safe_load(open(f)) for f in __import__('glob').glob('.fabric/components/*.yaml')]; no_edges=[c for c in cards if c and not c.get('depends_on') and not c.get('depended_by') and not c.get('location','').startswith('tests/')]; print(f'{len(no_edges)} non-test edgeless'); sys.exit(0 if len(no_edges) < 10 else 1)"

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-13T10:22:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1219-fabric-enrichment--reduce-edgeless-cards.md
- **Context:** Initial task creation

### 2026-04-13T10:27:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
