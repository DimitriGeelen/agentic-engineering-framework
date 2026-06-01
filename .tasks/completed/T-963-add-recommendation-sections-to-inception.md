---
id: T-963
name: "Add Recommendation sections to inception tasks — enable Watchtower batch review"
description: >
  Add Recommendation sections to inception tasks — enable Watchtower batch review

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-06T17:56:51Z
last_update: 2026-04-06T17:58:54Z
date_finished: 2026-04-06T17:58:54Z
---

# T-963: Add Recommendation sections to inception tasks — enable Watchtower batch review

## Context

T-959 added inline recommendation summaries to the Watchtower `/inception?decision=pending` page. However, it only extracts `## Recommendation` sections — 26 inception tasks had `## Decisions` sections but no `## Recommendation`. This refactoring adds the standardized sections so the batch review page can display them. T-316's corrupted GO decision was corrected to NO-GO based on research findings.

## Acceptance Criteria

### Agent
- [x] All inception tasks with decisions have `## Recommendation` sections
- [x] T-316 corrected from corrupted GO to NO-GO
- [x] Script saved for reproducibility at `docs/reports/T-963-add-recommendations.py`
- [x] 26 tasks modified, 32 already had recommendations

## Verification

# Verify all decided inception tasks have ## Recommendation sections
python3 -c "import os,re; tasks=[f for f in os.listdir('.tasks/active') if f.startswith('T-') and f.endswith('.md')]; missing=[]; [missing.append(f) for f in tasks if 'inception' in open(f'.tasks/active/{f}').read() and '**Decision**' in open(f'.tasks/active/{f}').read() and '## Recommendation' not in open(f'.tasks/active/{f}').read()]; print(f'{len(missing)} missing'); exit(1 if missing else 0)"
# Verify T-316 says NO-GO
grep -q 'NO-GO' .tasks/active/T-316-spike-layered-claudemd-framework-base--p.md

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

### 2026-04-06T17:56:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-963-add-recommendation-sections-to-inception.md
- **Context:** Initial task creation

### 2026-04-06T17:58:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
