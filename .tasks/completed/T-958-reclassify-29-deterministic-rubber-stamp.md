---
id: T-958
name: "Reclassify 29 deterministic RUBBER-STAMP Human ACs to Agent ACs with verification commands (T-954 Phase 2)"
description: >
  Convert 29 CLI-testable RUBBER-STAMP Human ACs to Agent ACs. Each gets a verification command in the Verification section. Split 12 UI ACs into functional (Agent) and aesthetic (Human) where applicable. Target: reduce Human AC backlog by 35-40%. From T-954 GO.

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-06T12:11:32Z
last_update: 2026-04-06T12:59:12Z
date_finished: 2026-04-06T12:59:12Z
---

# T-958: Reclassify 29 deterministic RUBBER-STAMP Human ACs to Agent ACs with verification commands (T-954 Phase 2)

## Context

Reclassify deterministic RUBBER-STAMP Human ACs to Agent ACs per T-954 GO decision. See `docs/reports/T-954-human-ac-classification-reform.md` for the 29 candidates.

## Acceptance Criteria

### Agent
- [x] RUBBER-STAMP ACs with deterministic tests converted to Agent ACs (19 converted)
- [x] Each converted AC has a verification command in ## Verification
- [x] Human AC count reduced (19 converted, 14% reduction — remaining 17 need macOS/phone/live session)
- [x] No subjective/judgment ACs reclassified (voice, tone, UX, inception go/no-go stay Human)

## Verification

# Count of unchecked Human ACs should be less than the starting 129
python3 -c "import os,re; count=sum(len(re.findall(r'- \[ \]',m.group(1))) for f in os.listdir('.tasks/active') if f.endswith('.md') for m in [re.search(r'### Human\n(.*?)(?=\n## |\Z)',open(f'.tasks/active/{f}').read(),re.DOTALL)] if m); assert count<129, f'{count}>=129'"

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

### 2026-04-06T12:11:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-958-reclassify-29-deterministic-rubber-stamp.md
- **Context:** Initial task creation

### 2026-04-06T12:55:06Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-06T12:59:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
