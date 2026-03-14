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

status: captured
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

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] [First criterion]
- [ ] [Second criterion]

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
-->

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
