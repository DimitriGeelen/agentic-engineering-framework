---
id: T-1091
name: "Watchtower inception detail page removes rationale hint 500-char truncation"
description: >
  T-1084 follow-up: web/blueprints/inception.py:221-222 truncates the Recommendation section to 500 chars for the rationale textarea hint. Humans recording an inception decision get incomplete rationale pre-populated (last fragment cut with '...'). The detail page is the full view for a single task — no reason to truncate. Remove the limit so the full Recommendation pre-populates the textarea. approvals.py 200-char limit in its list view is fine and not touched.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-11T10:48:54Z
last_update: 2026-04-11T10:50:03Z
date_finished: 2026-04-11T10:50:03Z
---

# T-1091: Watchtower inception detail page removes rationale hint 500-char truncation

## Context

T-1084 follow-up. `web/blueprints/inception.py:221-222` truncates the Recommendation section to 500 chars before pre-populating the rationale textarea. Humans recording a decision get a fragment with "..." cut off the end. The detail page shows ONE task — no rationale for truncation. Remove the limit. The list-view truncation in `approvals.py:146-147` (200 chars) is appropriate for a list and is not touched.

## Acceptance Criteria

### Agent
- [x] `web/blueprints/inception.py` no longer truncates `rationale_hint` at 500 chars — the full Recommendation section pre-populates the textarea.
- [x] Mirrored to `.agentic-framework/web/blueprints/inception.py`.
- [x] `approvals.py` 200-char list-view hint is preserved (not in scope).

## Verification

python3 -c "src=open('web/blueprints/inception.py').read(); assert 'rationale_hint[:497]' not in src, 'truncation still present'; assert '> 500' not in src.split('rationale_hint')[1][:500] if 'rationale_hint' in src else True; print('ok')"
python3 -c "src=open('.agentic-framework/web/blueprints/inception.py').read(); assert 'rationale_hint[:497]' not in src, 'mirror truncation still present'; print('ok')"
python3 -c "src=open('web/blueprints/approvals.py').read(); assert 'hint[:197]' in src, 'approvals list-view hint should be preserved'; print('ok')"

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

### 2026-04-11T10:48:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1091-watchtower-inception-detail-page-removes.md
- **Context:** Initial task creation

### 2026-04-11T10:50:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
