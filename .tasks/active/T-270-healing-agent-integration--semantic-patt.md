---
id: T-270
name: "Healing agent integration — semantic pattern matching via fw ask"
description: >
  Replace healing agent's 126 lines of bash keyword-matching (diagnose.sh find_similar_patterns) with a single fw ask --json --scope patterns call. The LLM understands semantic similarity (e.g. 'context explosion' matches 'memory overflow' even without keyword overlap). Also enhance context agent: on fw context focus T-XXX, generate a 200-word briefing from episodic predecessors + related patterns + CLAUDE.md sections. Files: agents/healing/healing.sh (simplify), agents/context/context.sh (add briefing). Ref: docs/reports/T-261-framework-enhancement.md §4 (programmatic access), §6 (session briefing). Depends on: T-264 (fw ask CLI).

status: started-work
workflow_type: build
owner: agent
horizon: next
tags: [qa, framework, healing, agents]
components: []
related_tasks: []
created: 2026-02-24T08:38:16Z
last_update: 2026-02-24T10:23:36Z
date_finished: null
---

# T-270: Healing agent integration — semantic pattern matching via fw ask

## Context

Replace keyword matching in healing agent with semantic search via fw ask. Add task briefing to context focus. Ref: T-261 research §4, §6.

## Acceptance Criteria

### Agent
- [x] diagnose.sh find_similar_patterns uses fw ask instead of keyword matching
- [x] score_pattern function removed (no longer needed)
- [x] Graceful fallback if Ollama/index unavailable
- [x] context focus.sh generates task briefing via fw ask
- [x] classify_failure preserved (fast, no LLM needed)

## Verification

# find_similar_patterns calls lib/ask.py
grep -q "lib/ask.py" agents/healing/lib/diagnose.sh
# score_pattern function removed
python3 -c "assert 'score_pattern' not in open('agents/healing/lib/diagnose.sh').read(); print('OK')"
# classify_failure still exists
grep -q "classify_failure" agents/healing/lib/diagnose.sh
# focus.sh has briefing
grep -q "Task Briefing" agents/context/lib/focus.sh
# diagnose.sh still runs (syntax check)
bash -n agents/healing/lib/diagnose.sh
# focus.sh still runs (syntax check)
bash -n agents/context/lib/focus.sh

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

### 2026-02-24T08:38:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-270-healing-agent-integration--semantic-patt.md
- **Context:** Initial task creation

### 2026-02-24T10:23:36Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
