---
id: T-351
name: "Rewrite README Quickstart with 3 onboarding paths + Watchtower"
description: >
  Rewrite README Quickstart with 3 onboarding paths + Watchtower

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-08T14:14:53Z
last_update: 2026-03-08T14:14:53Z
date_finished: null
---

# T-351: Rewrite README Quickstart with 3 onboarding paths + Watchtower

## Context

README Quickstart was a single code block. Needs 3 distinct onboarding paths (inception, vanilla build, existing project) plus Watchtower dashboard instructions.

## Acceptance Criteria

### Agent
- [x] Path 1: Fresh project with inception (thinking-first exploration)
- [x] Path 2: Fresh project, start building (task-first)
- [x] Path 3: Existing project ingestion (fw init + fabric register)
- [x] Watchtower dashboard startup instructions included

### Human
- [ ] [REVIEW] Quickstart paths read clearly and match real workflows
  **Steps:**
  1. Read the three Quickstart paths in README.md
  2. Compare each against actual `fw` command behavior
  **Expected:** Commands are accurate, descriptions match intent
  **If not:** Note which path needs adjustment

## Verification

grep -q "Path 1" README.md
grep -q "Path 2" README.md
grep -q "Path 3" README.md
grep -q "fw serve" README.md

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

### 2026-03-08T14:14:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-351-rewrite-readme-quickstart-with-3-onboard.md
- **Context:** Initial task creation
