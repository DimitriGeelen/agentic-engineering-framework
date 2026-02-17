---
id: T-118
name: Investigate and remediate silent error bypass behavior
description: >
  User observed a recurring pattern: agent silently works around errors instead of investigating root causes. Examples this session: (1) fw command not found — silently switched to direct path instead of investigating PATH issue. (2) Previous sessions had similar patterns where errors were glossed over. This is a Level D (ways of working) issue. The agent treats errors as friction to work around, not signals to investigate. Need to: audit episodic memory for all instances of silent bypass, identify root cause in agent behavior/instructions, design remediation (CLAUDE.md instructions, hook-based enforcement, or practice codification). This is a governance gap similar to T-108 premature closure — the framework should make investigation the path of least resistance.

status: started-work
workflow_type: inception
owner: agent
tags: []
related_tasks: []
created: 2026-02-17T14:43:20Z
last_update: 2026-02-17T14:43:20Z
date_finished: null
---

# T-118: Investigate and remediate silent error bypass behavior

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- [Criterion 1]
- [Criterion 2]

**NO-GO if:**
- [Criterion 1]
- [Criterion 2]

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
