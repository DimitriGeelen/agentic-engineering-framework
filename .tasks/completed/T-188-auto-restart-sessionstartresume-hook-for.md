---
id: T-188
name: "Auto-restart: SessionStart:resume hook for context injection"
description: >
  From T-179 GO. Register a SessionStart hook with matcher 'resume' that injects handover context when claude -c restarts the session. Extends the existing post-compact-resume.sh or creates a parallel hook.

status: work-completed
workflow_type: build
owner: claude-code
horizon: now
tags: []
related_tasks: []
created: 2026-02-19T07:41:34Z
last_update: 2026-02-19T07:42:44Z
date_finished: 2026-02-19T07:42:44Z
---

# T-188: Auto-restart: SessionStart:resume hook for context injection

## Context

Component 3 of T-179 auto-restart. Reuse existing `post-compact-resume.sh` for `SessionStart:resume` event (fires on `claude -c`).

## Acceptance Criteria

- [x] `SessionStart` hook in settings.json has entry with matcher `resume` pointing to `post-compact-resume.sh`
- [x] `post-compact-resume.sh` footer text updated to be generic (not compaction-specific)
- [x] settings.json is valid JSON

## Verification

# settings.json has resume matcher
python3 -c "import json; d=json.load(open('/opt/999-Agentic-Engineering-Framework/.claude/settings.json')); hooks=[h for h in d['hooks']['SessionStart'] if 'resume' in h.get('matcher','')]; assert len(hooks)>0, 'no resume hook'"
# Valid JSON
python3 -c "import json; json.load(open('/opt/999-Agentic-Engineering-Framework/.claude/settings.json'))"

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

### 2026-02-19T07:41:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-188-auto-restart-sessionstartresume-hook-for.md
- **Context:** Initial task creation

### 2026-02-19T07:42:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
