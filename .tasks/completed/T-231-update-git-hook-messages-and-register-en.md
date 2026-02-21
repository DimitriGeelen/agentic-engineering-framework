---
id: T-231
name: "Update git hook messages and register enforcement gaps"
description: >
  Follow-up from T-228/T-229 enforcement hardening: (1) Update commit-msg and pre-push hook messages — they still say 'Emergency bypass: git commit --no-verify' but Tier 0 now blocks --no-verify. Update messaging to reference 'fw tier0 approve'. (2) Register remaining bypass vectors (B-002, B-006, B-009) in gaps.yaml. (3) Run unit tests to verify no regressions.

status: work-completed
workflow_type: refactor
owner: agent
horizon: now
tags: []
components: [agents/git/lib/hooks.sh]
related_tasks: []
created: 2026-02-21T14:35:37Z
last_update: 2026-02-21T14:38:35Z
date_finished: 2026-02-21T14:38:35Z
---

# T-231: Update git hook messages and register enforcement gaps

## Context

Follow-up from T-228/T-229/T-230 enforcement hardening. See `docs/reports/T-228-enforcement-bypass-analysis.md`.

## Acceptance Criteria

### Agent
- [x] commit-msg hook references `fw tier0 approve` instead of bare `--no-verify` for bypass
- [x] pre-push hook references `fw tier0 approve` instead of bare `--no-verify` for bypass
- [x] Remaining bypass vectors registered in gaps.yaml (G-011 for B-009, G-012 for B-012)
- [x] Unit tests pass (84/84, no regressions from enforcement changes)

## Verification

grep -q "tier0 approve" /opt/999-Agentic-Engineering-Framework/.git/hooks/commit-msg
grep -q "tier0 approve" /opt/999-Agentic-Engineering-Framework/.git/hooks/pre-push
python3 -c "import yaml; yaml.safe_load(open('/opt/999-Agentic-Engineering-Framework/.context/project/gaps.yaml'))"

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

### 2026-02-21T14:35:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-231-update-git-hook-messages-and-register-en.md
- **Context:** Initial task creation

### 2026-02-21T14:38:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
