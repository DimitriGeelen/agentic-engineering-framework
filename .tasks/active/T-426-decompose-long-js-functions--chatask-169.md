---
id: T-426
name: "Decompose long JS functions — chatAsk (169 lines), askQuestion (155 lines) (J6)"
description: >
  Break chatAsk and askQuestion into initializeChat(), streamFetch(), handleStreamEvent(), renderResponse(), finalizeChat(). Currently each function handles UI state, fetching, streaming, parsing, rendering, and history in one block. Directive score: J6=5. Ref: docs/reports/T-411-refactoring-directive-scoring.md. Note: may overlap with T-418 (StreamFetcher) — coordinate.

status: started-work
workflow_type: refactor
owner: agent
horizon: next
tags: [refactoring, javascript, watchtower]
components: []
related_tasks: [T-411]
created: 2026-03-10T21:04:07Z
last_update: 2026-03-11T15:26:09Z
date_finished: null
---

# T-426: Decompose long JS functions — chatAsk (169 lines), askQuestion (155 lines) (J6)

## Context

JS function decomposition (J6). See `docs/reports/T-411-refactoring-directive-scoring.md` § JS row J6 (score 5). chatAsk (169 lines) and askQuestion (155 lines). Depends on T-418 (StreamFetcher) — coordinate to avoid conflicts.

## Acceptance Criteria

### Agent
- [x] chatAsk() reduced to ≤60 lines (from ~114) — now 20 lines
- [x] askQuestion() reduced to ≤60 lines (from ~114) — now 23 lines
- [x] Shared thinking timer helper extracted to utils.js
- [x] No behavioral changes — functions produce same DOM output
- [x] Web UI loads without JS errors (curl check)

### Human
- [ ] [REVIEW] Chat and Q&A streaming both work after decomposition
  **Steps:**
  1. Open http://localhost:3000/search in browser
  2. Ask a question in the search bar (Q&A mode)
  3. Switch to Ask AI tab and ask a question (chat mode)
  4. Check browser console for errors
  **Expected:** Both streaming responses render correctly, sources show, follow-up works
  **If not:** Note which mode broke and check console errors

## Verification

# chatAsk is ≤60 lines (function start to closing brace)
test $(awk '/^function chatAsk\(/{ s=NR } s && /^}$/ && NR>s { print NR-s+1; s=0 }' web/static/js/chat.js) -le 60
# askQuestion is ≤60 lines
test $(awk '/^function askQuestion\(/{ s=NR } s && /^}$/ && NR>s { print NR-s+1; s=0 }' web/static/js/search-qa.js) -le 60
# Shared thinking helper exists in utils.js
grep -q "createThinkingTracker" web/static/js/utils.js
# Web UI loads without errors
curl -sf http://localhost:3000/search > /dev/null
# JS files have no syntax errors (basic check)
node -c web/static/js/utils.js
node -c web/static/js/chat.js
node -c web/static/js/search-qa.js

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

### 2026-03-10T21:04:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-426-decompose-long-js-functions--chatask-169.md
- **Context:** Initial task creation

### 2026-03-11T15:26:09Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
