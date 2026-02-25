---
id: T-266
name: "Streaming UX — marked.js, syntax highlighting, copy buttons"
description: >
  Replace custom renderAnswer() with marked.js for full CommonMark rendering. Add highlight.js for code syntax highlighting. Add copy buttons on code blocks. Improve thinking phase with progressive status messages and elapsed timer. Debounce markdown rendering to ~100ms intervals to prevent flicker. Add DOMPurify for XSS prevention. Files: web/templates/search.html (JS), web/static/ (marked.min.js, highlight.min.js, purify.min.js). Ref: docs/reports/T-261-arch-improvements.md §4 (full code sketches for marked integration, highlight, copy buttons, thinking phases). Predecessor: T-257 (frontend).

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [qa, frontend, ux]
components: [web/templates/base.html, web/templates/search.html]
related_tasks: []
created: 2026-02-24T08:37:26Z
last_update: 2026-02-25T20:37:12Z
date_finished: 2026-02-24T09:31:14Z
---

# T-266: Streaming UX — marked.js, syntax highlighting, copy buttons

## Context

Streaming UX improvements for Q&A. Ref: [T-261-arch-improvements.md](../../docs/reports/T-261-arch-improvements.md) §4

## Acceptance Criteria

### Agent
- [x] marked.js loaded for full CommonMark markdown rendering
- [x] highlight.js loaded for code syntax highlighting
- [x] DOMPurify loaded for XSS prevention
- [x] Copy buttons added to code blocks
- [x] Rendering debounced to ~100ms to prevent flicker
- [x] All JS libraries served locally (no CDN dependency)
- [x] Citation references styled with sup.citation class

### Human
- [x] Markdown renders correctly (headers, lists, bold, code blocks)
- [x] Code blocks have syntax highlighting with appropriate colors
- [x] Copy button works and shows "Copied!" feedback
- [x] Streaming feels smooth without flicker

## Verification

# marked.js exists locally
test -f web/static/marked.min.js
# DOMPurify exists locally
test -f web/static/purify.min.js
# highlight.js exists locally
test -f web/static/highlight.min.js
# marked integration in search template
grep -q "marked.parse" web/templates/search.html
# DOMPurify used for sanitization
grep -q "DOMPurify.sanitize" web/templates/search.html
# Copy button function exists
grep -q "addCopyButtons" web/templates/search.html
# Debounce function exists
grep -q "renderAnswerDebounced" web/templates/search.html
# Base template loads local libraries
grep -q "marked.min.js" web/templates/base.html
# Search page loads
curl -sf http://localhost:3000/search > /dev/null

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

### 2026-02-24T08:37:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-266-streaming-ux--markedjs-syntax-highlighti.md
- **Context:** Initial task creation

### 2026-02-24T09:20:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-24T09:31:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
