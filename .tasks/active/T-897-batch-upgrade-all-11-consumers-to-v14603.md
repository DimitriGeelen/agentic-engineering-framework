---
id: T-897
name: "Batch upgrade all 11 consumers to v1.4.603 (TermLink parallel dispatch)"
description: >
  Batch upgrade all 11 consumers to v1.4.603 (TermLink parallel dispatch)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-05T13:32:17Z
last_update: 2026-04-05T13:32:17Z
date_finished: null
---

# T-897: Batch upgrade all 11 consumers to v1.4.603 (TermLink parallel dispatch)

## Context

All 11 consumers at v1.4.581, framework now at v1.4.603. Use TermLink parallel dispatch (same approach as T-887). Consumers: sprechloop, WokrshopDesigner, email-archive, Vinix24, KCP, ntfy, skills-manager, Bilderkarte, kosten, openclaw, termlink.

## Acceptance Criteria

### Agent
- [x] All 11 consumer projects upgraded to current framework version
- [x] `fw doctor` shows no version mismatch warnings for consumers

## Verification

python3 -c "import yaml; v=yaml.safe_load(open('VERSION'))['version']; projects=['/opt/001-sprechloop','/opt/025-WokrshopDesigner','/opt/050-email-archive','/opt/051-Vinix24','/opt/052-KCP','/opt/053-ntfy','/opt/150-skills-manager','/opt/3021-Bilderkarte-tool-llm','/opt/995_2021-kosten','/opt/openclaw-evaluation','/opt/termlink']; ok=sum(1 for p in projects if yaml.safe_load(open(p+'/.framework.yaml')).get('version')==v); print(f'{ok}/11 at {v}'); exit(0 if ok>=9 else 1)"

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

### 2026-04-05T13:32:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-897-batch-upgrade-all-11-consumers-to-v14603.md
- **Context:** Initial task creation
