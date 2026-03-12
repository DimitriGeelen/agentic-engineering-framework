---
id: T-470
name: "Deep-dive article 17: Why Bash, YAML and Files — the anti-enterprise stack"
description: >
  Deep-dive article 17: Why Bash, YAML and Files — the anti-enterprise stack

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-12T20:34:15Z
last_update: 2026-03-12T20:36:29Z
date_finished: 2026-03-12T20:36:29Z
---

# T-470: Deep-dive article 17: Why Bash, YAML and Files — the anti-enterprise stack

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Article file exists at docs/articles/deep-dives/17-why-bash-yaml-files.md
- [x] References real decision IDs (D-002, D-005, D-012, D-013, D-040, AD-004, AD-008, P-006)
- [x] README tracker updated with article 17

### Human
- [ ] [REVIEW] Voice and tone match Dimitri's writing style
  **Steps:**
  1. Read the article at `docs/articles/deep-dives/17-why-bash-yaml-files.md`
  2. Compare to published articles (01-task-gate, 16-honest-machines)
  3. Check for anti-patterns: emojis, exclamation marks, hedging, AI slop
  **Expected:** Reads like the other deep-dives — first person, direct, honest about tradeoffs
  **If not:** Note specific paragraphs for revision

## Verification

test -f docs/articles/deep-dives/17-why-bash-yaml-files.md
grep -q "D-013" docs/articles/deep-dives/17-why-bash-yaml-files.md
grep -q "17" docs/articles/deep-dives/README.md

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

### 2026-03-12T20:34:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-470-deep-dive-article-17-why-bash-yaml-and-f.md
- **Context:** Initial task creation

### 2026-03-12T20:36:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
