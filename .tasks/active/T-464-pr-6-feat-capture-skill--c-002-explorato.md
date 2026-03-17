---
id: T-464
name: "PR #6: feat: /capture skill + C-002 Exploratory Conversation Guard"
description: >
  OneDev PR #6 (branch: feature/conversation-guard-capture-skill)

## Problem

Claude Code fires zero hooks for pure conversation sessions. A session that never touches a file can lose all content on context exhaustion (G-005).

## Solution

1. **C-002 rule** (CLAUDE.md): Stop at 3 substantive exchanges on untracked topic, create inception task, invoke /capture.
2. **/capture skill**: Reads JSONL transcript, extracts current topic, writes structured artifact, commits.

Contributed from 010-termlink project (T-108). Tested: 24 turns captured, topic boundary corr

status: started-work
workflow_type: build
owner: human
horizon: next
tags: [onedev, pr]
components: []
related_tasks: []
created: 2026-03-12T18:00:01Z
last_update: 2026-03-12T18:00:01Z
date_finished: null
---

# T-464: PR #6: feat: /capture skill + C-002 Exploratory Conversation Guard

## Context

Cherry-pick PR #6 from OneDev branch `feature/conversation-guard-capture-skill`. Contributed from 010-termlink project (T-108). Branch is 126 commits behind master — cherry-pick is cleaner than merge.

## Acceptance Criteria

### Agent
- [ ] C-002 rule added to CLAUDE.md Inception Discipline section
- [ ] `/capture` skill exists at `.claude/commands/capture.md`
- [ ] `agents/capture/read-transcript.py` exists and passes syntax check
- [ ] Fabric component cards exist for capture reader and skill
- [ ] Feature branch deleted from remotes after merge

### Human
- [ ] [RUBBER-STAMP] Test `/capture` skill in a live session
  **Steps:**
  1. Start a conversation on an untracked topic
  2. Create a task: `fw work-on "test capture" --type build`
  3. Type `/capture`
  **Expected:** Conversation artifact written to `docs/reports/` and committed
  **If not:** Check `python3 agents/capture/read-transcript.py --dry-run` for transcript format issues

## Verification

test -f .claude/commands/capture.md
test -f agents/capture/read-transcript.py
python3 -c "import ast; ast.parse(open('agents/capture/read-transcript.py').read())"
grep -q "C-002" CLAUDE.md
test -f .fabric/components/capture-reader.yaml
test -f .fabric/components/capture-skill.yaml

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

### 2026-03-12T18:00:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-464-pr-6-feat-capture-skill--c-002-explorato.md
- **Context:** Initial task creation
