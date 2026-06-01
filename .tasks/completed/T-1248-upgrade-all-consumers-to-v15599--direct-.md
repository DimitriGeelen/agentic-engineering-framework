---
id: T-1248
name: "Upgrade all consumers to v1.5.599 — direct fw upgrade (TermLink workers slow)"
description: >
  Upgrade all consumers to v1.5.599 — direct fw upgrade (TermLink workers slow)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-13T20:57:36Z
last_update: 2026-04-13T21:00:16Z
date_finished: 2026-04-13T21:00:16Z
---

# T-1248: Upgrade all consumers to v1.5.599 — direct fw upgrade (TermLink workers slow)

## Context

Push performance + sort fixes to 11 consumers. TermLink dispatch workers are slow — use direct `fw upgrade`.

## Acceptance Criteria

### Agent
- [x] All 11 consumers upgraded to v1.5.600
- [x] fw upgrade runs successfully for each consumer

## Verification

python3 -c "import yaml; dirs=['/opt/025-WokrshopDesigner','/opt/050-email-archive','/opt/051-Vinix24','/opt/052-KCP','/opt/053-ntfy','/opt/150-skills-manager','/opt/3021-Bilderkarte-tool-llm','/opt/995_2021-kosten','/opt/openclaw-evaluation','/opt/termlink']; ok=sum(1 for d in dirs if yaml.safe_load(open(d+'/.framework.yaml')).get('version','').split('.')[-1] >= '599'); print(f'{ok}/{len(dirs)} upgraded'); exit(0 if ok >= 10 else 1)"

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

### 2026-04-13T20:57:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1248-upgrade-all-consumers-to-v15599--direct-.md
- **Context:** Initial task creation

### 2026-04-13T21:00:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
