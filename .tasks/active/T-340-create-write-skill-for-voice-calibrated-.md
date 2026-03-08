---
id: T-340
name: "Create /write skill for voice-calibrated content"
description: >
  Create .claude/commands/write.md skill that reads docs/style-guide.md and task ACs, produces voice-calibrated drafts. Design from T-338 style anchor agent.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-08T08:37:32Z
last_update: 2026-03-08T08:48:38Z
date_finished: 2026-03-08T08:48:30Z
---

# T-340: Create /write skill for voice-calibrated content

## Context

Design from T-338 style anchor agent analysis. Skill follows the same pattern as `/plan` — reads a reference file, reads the task, produces an artifact.

## Acceptance Criteria

### Agent
- [x] `.claude/commands/write.md` exists and is recognized as a skill
- [x] Skill references `docs/style-guide.md` as voice source
- [x] Skill includes self-check step with mechanical tests from style guide
- [x] Skill follows existing skill patterns (prerequisites, workflow steps, rules)

### Human
- [ ] Skill produces acceptable voice-calibrated output when invoked on a content task

## Verification

test -f .claude/commands/write.md
grep -q "style-guide.md" .claude/commands/write.md
grep -q "Self-Check" .claude/commands/write.md
grep -q "Prerequisites" .claude/commands/write.md

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

### 2026-03-08T08:37:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-340-create-write-skill-for-voice-calibrated-.md
- **Context:** Initial task creation

### 2026-03-08T08:47:26Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-08T08:48:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
