---
id: T-389
name: "Save inferred question title instead of raw input in Q&A"
description: >
  When saving Q&A answers via /search/save, store the LLM's inferred/rephrased question as the title and filename instead of the raw typed text (which contains voice-transcription typos). Add a 'suggested_title' field to the SSE done event from the LLM, modify the system prompt to request a clean title, update the save endpoint to use it. Predecessor: T-388.

status: work-completed
workflow_type: build
owner: human
horizon: next
tags: []
components: [C-003]
related_tasks: []
created: 2026-03-09T11:35:21Z
last_update: 2026-03-12T12:41:19Z
date_finished: 2026-03-09T11:44:17Z
---

# T-389: Save inferred question title instead of raw input in Q&A

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] System prompt includes rule 8 requesting `<!-- Q: ... -->` comment
- [x] LLM produces clean inferred title (verified: "how doez the healng loop workk" → "How does the healing loop work in this framework?")

### Human
- [x] [REVIEW] Ask a voice-transcribed question in the search page, save it, and verify the saved file uses a clean title
  **Steps:**
  1. Go to http://localhost:3000/search
  2. Type a question with typos (e.g. "whats teh compoennt fabrik")
  3. Wait for the answer, click Save
  4. Check `.context/qa/` for the new file — filename should use clean words
  **Expected:** File title is clean (e.g. "What is the Component Fabric?"), raw query preserved as metadata
  **If not:** Check if `<!-- Q: ... -->` comment appears in the answer text

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

### 2026-03-09T11:35:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-389-save-inferred-question-title-instead-of-.md
- **Context:** Initial task creation

### 2026-03-09T11:44:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:14Z — status-update [task-update-agent]
- **Change:** horizon: now → next
