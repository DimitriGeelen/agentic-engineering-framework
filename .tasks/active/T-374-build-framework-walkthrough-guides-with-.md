---
id: T-374
name: "Build framework walkthrough guides with audience tracks"
description: >
  Create docs/walkthrough/ with ordered guides for 3 audience tracks (new user, contributor, agent implementer). Each guide sequences the 12 subsystems in dependency order and links to existing generated docs (Layer 1 component refs, Layer 2 subsystem articles, deep-dives). No new content creation — routing/sequencing only. Source: T-305 GO decision. See docs/reports/T-305-walkthrough-inception.md.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-09T07:24:56Z
last_update: 2026-03-09T07:24:56Z
date_finished: null
---

# T-374: Build framework walkthrough guides with audience tracks

## Context

Build task from T-305 GO decision. Content already exists (160+ docs). Walkthrough is routing/sequencing into audience tracks. See `docs/reports/T-305-walkthrough-inception.md`.

## Acceptance Criteria

### Agent
- [x] README index with track selection and subsystem dependency map
- [x] Track 1: New User (core governance cycle — 6 subsystems)
- [x] Track 2: Contributor (internal architecture — 6 subsystems + patterns)
- [x] Track 3: Agent Implementer (enforcement, memory model, integration points)
- [x] All tracks link to existing generated docs (no content duplication)
- [x] Subsystems ordered by dependency, not alphabetically

### Human
- [ ] [REVIEW] Walkthrough reads naturally for target audience
  **Steps:**
  1. Read `docs/walkthrough/01-new-user.md` as if you've never used the framework
  2. Follow the "Try it" commands — do they make sense?
  3. Skim Track 2 and 3 for contributor/implementer relevance
  **Expected:** Each track is self-contained, progressively deeper, and links work
  **If not:** Note which sections feel unclear or misorderd

## Verification

test -f docs/walkthrough/README.md
test -f docs/walkthrough/01-new-user.md
test -f docs/walkthrough/02-contributor.md
test -f docs/walkthrough/03-agent-implementer.md
grep -q "New User" docs/walkthrough/README.md
grep -q "Contributor" docs/walkthrough/README.md
grep -q "Agent Implementer" docs/walkthrough/README.md

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

### 2026-03-09T07:24:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-374-build-framework-walkthrough-guides-with-.md
- **Context:** Initial task creation
