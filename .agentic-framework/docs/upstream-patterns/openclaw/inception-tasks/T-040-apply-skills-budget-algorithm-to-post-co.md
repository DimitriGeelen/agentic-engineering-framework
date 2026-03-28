---
id: T-040
name: "Apply skills budget algorithm to post-compaction context injection"
description: >
  Inception: Evaluate using OpenClaw's 3-tier budget algorithm to fit context
  into post-compaction resume. Currently fixed-format with no budget adaptation.

status: captured
workflow_type: inception
owner: human
horizon: now
tags: [framework-improvement, extracted-pattern, context-budget]
components: []
related_tasks: [T-036, T-024]
created: 2026-03-27T18:55:29Z
last_update: 2026-03-27T18:55:29Z
date_finished: null
---

# T-040: Apply skills budget algorithm to post-compaction context injection

## Problem Statement

After compaction, `post-compact-resume.sh` injects a structured context block (handover summary,
active tasks, git state, suggested action, discoveries). The block is fixed-format — no adaptation
to available budget. With 17 active tasks in this evaluation, the injected block was large and
consumed a significant portion of fresh context.

OpenClaw's 3-tier budget algorithm (full → compact → binary-search-fit) solves this: fit N items
into a character budget with graceful degradation.

**For:** Post-compaction recovery quality (every session restart)
**Why now:** Pattern extracted via T-036; daily pain point during this evaluation.

## Key Artifacts

| Artifact | Location | Description |
|----------|----------|-------------|
| Extracted pattern | `docs/extracted/skills-budget.ts` | Zero-dep standalone, 90 LOC |
| OpenClaw original | `src/agents/skills/workspace.ts:567-613` | `applySkillsPromptLimits` |
| OpenClaw tests | `src/agents/skills/compact-format.test.ts` | Budget tier tests |
| Framework resume | `.agentic-framework/agents/context/post-compact-resume.sh` | Current injector |
| Budget gate | `.agentic-framework/agents/context/budget-gate.sh` | Token-aware enforcement |

## 3-Tier Degradation Model

```
Tier 1 (Full):    Where We Are + All Tasks (with status) + Git + Suggested Action + Findings
Tier 2 (Compact): Where We Are + Task IDs only + Suggested Action
Tier 3 (Minimal): Where We Are + Suggested Action (binary search for fit)
```

## Assumptions

- A-001: Post-compaction injection size matters (large injections waste fresh context)
- A-002: Implementable in bash/Python without TS compilation
- A-003: Char-based budget approximation (~4 chars/token) is sufficient

## Exploration Plan

1. **Spike 1 (30min):** Measure current injection sizes across sessions
2. **Spike 2 (1h):** Prototype 3-tier degradation in post-compact-resume.sh
3. **Spike 3 (30min):** Test with a real compaction

## Technical Constraints

- post-compact-resume.sh outputs to stdout (SessionStart hook)
- Must work in bash (no Node.js dependency)
- Budget estimable without actual tokenization

## Scope Fence

**IN:** Budget-aware context injection in post-compact-resume.sh
**OUT:** Changing compaction behavior, modifying budget-gate thresholds

## Acceptance Criteria

- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Current injection sizes vary significantly (>2x range)
- 3-tier degradation implementable in <100 LOC bash
- Measurable improvement in recovery quality

**NO-GO if:**
- Injection sizes consistently small (<5K chars)
- Budget estimation too inaccurate
- Better solved by reducing generation, not fitting

## Verification

## Decisions

## Decision

## Updates
