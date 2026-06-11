---
id: T-419
name: "Encapsulate JS conversation state — replace 11 global variables (J3)"
description: >
  Create ConversationState class to replace 11 unencapsulated globals across chat.js
  (4: _chatHistory, _chatAbort, _chatScope, _chatLoadedConvId) and search-qa.js (7:
  _askAbort, _lastQuestion, _lastAnswer, etc). Global state makes test isolation impossible
  and enables hard-to-reproduce state leakage. Directive score: J3=7. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: work-completed
workflow_type: refactor
owner: agent
horizon:
tags: [refactoring, javascript, watchtower, reliability]
components: [web/static/js/chat.js]
related_tasks: [T-411]
created: 2026-03-10T21:03:19Z
last_update: '2026-06-11T22:24:21Z'
date_finished: 2026-03-11T07:46:42Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:21Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-419: Encapsulate JS conversation state — replace 11 global variables (J3)

## Context

Refactoring finding J3 (score 7) from `docs/reports/T-411-refactoring-directive-scoring.md`.

**J3 — Global mutable state without encapsulation (11 globals):**
chat.js:3-6 has 4 globals (_chatHistory, _chatAbort, _chatScope, _chatLoadedConvId).
search-qa.js:3-9 has 7 globals (_askAbort, _lastQuestion, _lastAnswer, _lastInferredTitle,
_lastSources, _lastModel, _conversationHistory). State leakage between conversations possible.
See research artifact § "JAVASCRIPT" row J3.

## Acceptance Criteria

### Agent
- [x] ConversationState object/class encapsulates chat state
- [x] QAState object/class encapsulates Q&A state
- [x] No module-level mutable globals remain (except state instances)
- [x] State reset works correctly on 'New Chat' and new Q&A sessions

### Human
<!-- No human verification needed for this refactoring -->

## Verification

! grep -E '^(var|let) _chat(History|Abort|Scope)' web/static/js/chat.js | grep -q .
! grep -E '^(var|let) _(askAbort|lastQuestion|lastAnswer)' web/static/js/search-qa.js | grep -q .

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

### 2026-03-10T21:03:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-419-encapsulate-js-conversation-state--repla.md
- **Context:** Initial task creation

### 2026-03-11T07:44:16Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-11T07:46:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3cb5df87
- **Timestamp:** 2026-06-02T15:02:43Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `! grep -E '^(var|let) _chat(History|Abort|Scope)' web/static/js/chat.js | grep -q .`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `! grep -E '^(var|let) _(askAbort|lastQuestion|lastAnswer)' web/static/js/search-qa.js | grep -q .`
