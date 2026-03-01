---
id: T-287
name: "Fix audit warnings: enrich edgeless fabric cards, narrow T-278 verification"
description: >
  Fix audit warnings: enrich edgeless fabric cards, narrow T-278 verification

status: started-work
workflow_type: refactor
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-01T11:13:51Z
last_update: 2026-03-01T11:22:31Z
date_finished: null
---

# T-287: Fix audit warnings: enrich edgeless fabric cards, narrow T-278 verification

## Context

Fix CTL-013 false positive (T-278 verification too broad) and enrich 11 edgeless fabric cards.

## Acceptance Criteria

### Agent
- [x] CTL-013 passes for T-278 (no more false positive)
- [x] Zero edgeless fabric cards (was 11)
- [x] T-278 verification narrowed to task-specific checks

## Verification

# CTL-013 passes for T-278
fw audit --section oe-daily --quiet 2>&1 | grep -q "T-278 verification re-run.*pass"
# No edgeless cards
python3 -c "import yaml,os;d='.fabric/components';e=[f for f in os.listdir(d) if f.endswith('.yaml') and not(yaml.safe_load(open(os.path.join(d,f))).get('depends_on') or yaml.safe_load(open(os.path.join(d,f))).get('depended_by'))];assert len(e)==0,f'{len(e)} edgeless'"

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

### 2026-03-01T11:13:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-287-fix-audit-warnings-enrich-edgeless-fabri.md
- **Context:** Initial task creation
