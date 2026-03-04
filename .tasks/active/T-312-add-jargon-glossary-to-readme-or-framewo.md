---
id: T-312
name: "Add jargon glossary to README or FRAMEWORK.md"
description: >
  New-user-perspective agent flagged 10+ undefined framework terms: horizon, inception, episodic memory, healing loop, antifragility, enforcement tiers, context fabric, sovereignty, working memory. Need definitions section. Source: T-294 new-user-perspective agent.

status: started-work
workflow_type: build
owner: agent
horizon: later
tags: []
components: []
related_tasks: [T-294]
created: 2026-03-04T17:28:42Z
last_update: 2026-03-04T22:13:23Z
date_finished: null
---

# T-312: Add jargon glossary to README or FRAMEWORK.md

## Context

T-294 new-user-perspective agent flagged 10+ undefined terms. Adding glossary section to FRAMEWORK.md (where terms are used).

## Acceptance Criteria

### Agent
- [x] FRAMEWORK.md has a "## Glossary" section
- [x] All flagged terms defined: horizon, inception, episodic memory, healing loop, antifragility, enforcement tiers, context fabric, sovereignty, working memory
- [x] Definitions are concise (1-2 sentences each)
- [x] README.md cross-references the glossary
- [x] Section placement is logical (after main content, before Installation)

## Verification

# Glossary section exists in FRAMEWORK.md
grep -q "## Glossary" FRAMEWORK.md
# All flagged terms present
grep -q "Horizon" FRAMEWORK.md
grep -q "Inception" FRAMEWORK.md
grep -q "Episodic Memory" FRAMEWORK.md
grep -q "Healing Loop" FRAMEWORK.md
grep -q "Antifragility" FRAMEWORK.md
grep -q "Enforcement Tiers" FRAMEWORK.md
grep -q "Context Fabric" FRAMEWORK.md
grep -q "Sovereignty" FRAMEWORK.md
grep -q "Working Memory" FRAMEWORK.md

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

### 2026-03-04T17:28:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-312-add-jargon-glossary-to-readme-or-framewo.md
- **Context:** Initial task creation

### 2026-03-04T22:13:23Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
