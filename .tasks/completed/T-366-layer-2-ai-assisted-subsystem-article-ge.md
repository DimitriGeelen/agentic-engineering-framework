---
id: T-366
name: "Layer 2: AI-assisted subsystem article generator"
description: >
  Build fw docs article {subsystem}: assembles context from fabric cards, source code, CLAUDE.md, episodic memory, then generates deep-dive article using proven 4-section template (analogy, concept, rationale, try-it). Can output prompt file or call LLM directly. See docs/reports/T-362-auto-doc-generation.md

status: work-completed
workflow_type: build
owner: human
horizon: next
tags: [documentation, fabric, cli]
components: [bin/fw]
related_tasks: []
created: 2026-03-08T22:03:34Z
last_update: 2026-03-12T12:41:19Z
date_finished: 2026-03-08T23:14:59Z
---

# T-366: Layer 2: AI-assisted subsystem article generator

## Context

Layer 2 of the auto-doc system (T-362). Assembles context from fabric cards, source code, CLAUDE.md, episodic memory, then generates deep-dive articles via Ollama or outputs prompt files.

## Acceptance Criteria

### Agent
- [x] `generate_article.py` assembles context from cards, source headers, CLAUDE.md, episodic, learnings, decisions
- [x] `generate-article.sh` shell wrapper with --list, --generate, --help
- [x] `fw docs article <subsystem>` produces prompt file
- [x] `fw docs article <subsystem> --generate` calls Ollama and writes article
- [x] Style reference from existing deep-dive injected into prompt
- [x] Generated article follows 4-section template (analogy → mechanism → research → try-it)

### Human
- [x] [REVIEW] Generated article quality
  **Steps:**
  1. Read `docs/articles/deep-dives/08-healing.md`
  2. Compare tone/structure to `docs/articles/deep-dives/01-task-gate.md`
  **Expected:** Similar structure, cites real task IDs, no emojis, peer-to-peer tone
  **If not:** Adjust prompt instructions in generate_article.py build_prompt()

## Verification

test -x agents/docgen/generate-article.sh
python3 -c "import agents.docgen.generate_article" 2>/dev/null || python3 -c "exec(open('agents/docgen/generate_article.py').read()[:50])"
grep -q "article" bin/fw
test -f docs/generated/articles/healing-prompt.md

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

### 2026-03-08T22:03:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-366-layer-2-ai-assisted-subsystem-article-ge.md
- **Context:** Initial task creation

### 2026-03-08T23:06:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-08T23:14:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:13Z — status-update [task-update-agent]
- **Change:** horizon: now → next
