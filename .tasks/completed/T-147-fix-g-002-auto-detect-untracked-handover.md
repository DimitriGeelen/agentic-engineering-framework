---
id: T-147
name: "Fix G-002: Auto-detect untracked handover open questions at resume + audit"
description: >
  Fix G-002: Auto-detect untracked handover open questions at resume + audit

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T10:08:20Z
last_update: 2026-02-18T10:11:05Z
date_finished: 2026-02-18T10:11:05Z
---

# T-147: Fix G-002: Auto-detect untracked handover open questions at resume + audit

## Context

G-002: Handover open questions are prose-only markdown, never auto-registered in gaps/tasks. Lost across sessions. See `.context/inbox/2026-02-18-sprechloop-gap-feedback.md`.

## Acceptance Criteria

- [x] Audit agent warns when handover has untracked open questions
- [x] Resume agent surfaces open questions with register prompt
- [x] Template placeholders ([TODO], [Question]) correctly filtered out

## Verification

# Audit check exists
grep -q "HANDOVER OPEN QUESTIONS" agents/audit/audit.sh
# Resume check exists
grep -q "Unresolved Open Questions" agents/resume/resume.sh
# Sprechloop audit detects untracked question
bash -c 'PROJECT_ROOT=/opt/001-sprechloop ./agents/audit/audit.sh 2>&1 > /tmp/audit-g002.txt; grep -q "open question.*no matching" /tmp/audit-g002.txt'

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

### 2026-02-18T10:08:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-147-fix-g-002-auto-detect-untracked-handover.md
- **Context:** Initial task creation

### 2026-02-18T10:11:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
