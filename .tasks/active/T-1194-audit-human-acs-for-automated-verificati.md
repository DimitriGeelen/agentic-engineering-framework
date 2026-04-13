---
id: T-1194
name: "Audit Human ACs for automated verification candidates — programmatic, TermLink E2E, Playwright"
description: >
  Audit Human ACs for automated verification candidates — programmatic, TermLink E2E, Playwright

status: started-work
workflow_type: refactor
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-13T06:18:29Z
last_update: 2026-04-13T06:28:19Z
date_finished: null
---

# T-1194: Audit Human ACs for automated verification candidates — programmatic, TermLink E2E, Playwright

## Context

105 human-owned tasks with 107 unchecked Human ACs. Classification: 65 programmatic (inception go/no-go with decisions already recorded), 10 TermLink E2E, 11 Playwright, 21 genuinely human. Execute programmatic batch first.

## Acceptance Criteria

### Agent
- [ ] 65 inception go/no-go Human ACs auto-checked (decision exists in task file)
- [ ] Remaining 21 human-only ACs left unchecked (genuinely require judgment)
- [ ] Report saved to docs/reports/

## Verification

# At least 60 inception tasks should have their Human ACs checked after this
cd /opt/999-Agentic-Engineering-Framework && test $(python3 -c "
import os, re, yaml
count = 0
for fname in os.listdir('.tasks/active'):
    if not fname.endswith('.md'): continue
    with open(f'.tasks/active/{fname}') as f: content = f.read()
    parts = content.split('---', 2)
    if len(parts) < 3: continue
    try: fm = yaml.safe_load(parts[1])
    except: continue
    if fm.get('workflow_type') != 'inception' or fm.get('status') != 'work-completed': continue
    if fm.get('owner') != 'human': continue
    human = re.search(r'### Human\s*\n(.*?)(?=\n##|\n### |\Z)', content, re.DOTALL)
    if not human: continue
    if '- [x]' in human.group(1): count += 1
print(count)
") -ge 60
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-13T06:18:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1194-audit-human-acs-for-automated-verificati.md
- **Context:** Initial task creation
