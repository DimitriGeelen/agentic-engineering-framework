---
id: T-418
name: "Extract JS StreamFetcher utility — deduplicate askQuestion/chatAsk (J2)"
description: >
  Extract shared StreamFetcher from search-qa.js:askQuestion (155 lines) and chat.js:chatAsk
  (169 lines) — 70% code overlap. Both implement identical SSE parsing, abort control,
  event handling. A protocol change fixed in one but not the other creates silent
  behavioral divergence. Directive score: J2=8. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: work-completed
workflow_type: refactor
owner: human
horizon:
tags: [refactoring, javascript, watchtower, reliability]
components: [web/static/js/chat.js]
related_tasks: [T-409, T-411]
created: 2026-03-10T21:03:18Z
last_update: '2026-06-11T22:24:21Z'
date_finished: 2026-03-10T23:34:07Z
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

# T-418: Extract JS StreamFetcher utility — deduplicate askQuestion/chatAsk (J2)

## Context

Refactoring finding J2 (score 8) from `docs/reports/T-411-refactoring-directive-scoring.md`.

**J2 — Duplicated stream handling (askQuestion/chatAsk — 70% overlap):**
search-qa.js:93-247 (askQuestion, 155 lines) and chat.js:160-329 (chatAsk, 169 lines) share
nearly identical SSE parsing (processBuffer/handleEvent), abort controller, and rendering logic.
A protocol change fixed in one but not the other creates silent behavioral divergence.
See research artifact § "JAVASCRIPT" row J2.

Key shared logic: SSE event parsing, abort control, token rendering, source display, error handling.

## Acceptance Criteria

### Agent
- [x] Shared StreamFetcher utility extracted (function or class)
- [x] askQuestion() and chatAsk() both use the shared utility
- [x] SSE parsing logic exists in exactly one place
- [x] Both Q&A and chat streaming still work end-to-end
- [x] Abort (cancel) works in both modes

### Human
- [x] [REVIEW] Chat and Q&A streaming both work after refactor
  **Steps:**
  1. Open http://localhost:3000/search
  2. In Q&A mode, ask 'What is the audit system?'
  3. Switch to Ask AI tab, ask the same question
  4. Verify both stream responses correctly
  **Expected:** Both modes show streaming text with sources
  **If not:** Note which mode broke and check browser console

## Verification

grep -q 'streamSSE' web/static/js/chat.js web/static/js/search-qa.js
# Both files should reference the shared utility, not duplicate SSE parsing

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

### 2026-03-10T21:03:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-418-extract-js-streamfetcher-utility--dedupl.md
- **Context:** Initial task creation

### 2026-03-10T23:29:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-10T23:34:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1fb60a99
- **Timestamp:** 2026-06-02T15:02:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - human-ac-mechanical-signal @ AC#1 (Human)
