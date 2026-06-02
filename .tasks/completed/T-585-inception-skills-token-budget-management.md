---
id: T-585
name: "Inception: Skills token budget management — dynamic prompt compression to preserve working context"
description: >
  CLAUDE.md (~25K tokens) + skills + memory + system reminders consume ~40-50K tokens at session start. After compaction this is 25-30% of effective working context. Problem worsens as skills grow. OpenClaw solved this at 150 skills with applySkillsPromptLimits(): try full format, switch to compact (saves ~80%), binary-search largest prefix that fits. Budget cap 30K chars. Three-tier: bundled (always) > managed (if relevant) > workspace (if in scope). Investigate: (1) Measure current prompt overhead (CLAUDE.md + skills + memory + system). (2) Extract/adapt applySkillsPromptLimits() (~100 LOC) for SKILL.md format. (3) Classify skills by relevance to current task type (build tasks need /commit /plan, not /write /explore). (4) Dynamic compression: full format for high-relevance, compact (name + trigger) for medium, name-only for low. (5) Budget cap configurable via env var. Connects to P-009 (context budget management) — we gate context during session via budget-gate.sh but dont gate prompt overhead at startup. Research source: /opt/openclaw-evaluation/.context/working/round2-T-021.md (P4 deep-dive, token budget algorithm). OpenClaw source: src/agents/skills/workspace.ts (applySkillsPromptLimits, formatSkillsForPrompt), src/agents/skills/frontmatter.ts (SKILL.md parsing). Related framework: CLAUDE.md (current monolithic prompt), agents/context/checkpoint.sh (budget monitoring), agents/context/budget-gate.sh (context gating).

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-23T21:26:30Z
last_update: 2026-03-28T09:31:54Z
date_finished: 2026-03-28T09:31:54Z
---

# T-585: Inception: Skills token budget management — dynamic prompt compression to preserve working context

## Problem Statement

CLAUDE.md + memory + settings consume ~20K tokens at session start (~10% of 200K context). Growing trend: CLAUDE.md was ~5K tokens at start, now ~13K. See `docs/reports/T-585-skills-token-budget.md`.

## Assumptions

1. Prompt overhead is a growing problem — validated (13K tokens in CLAUDE.md, trending up)
2. OpenClaw's compression approach is applicable — INVALIDATED (Claude Code auto-loads CLAUDE.md, no filtering control)
3. Size monitoring would catch the trend early — validated

## Exploration Plan

1. Measure current prompt overhead — DONE (20K tokens, 10% of context)
2. Evaluate OpenClaw compression approach — DONE (not applicable, different loading model)
3. Identify alternatives — DONE (monitoring, skill decomposition)

## Technical Constraints

- Claude Code auto-loads CLAUDE.md — we cannot filter sections pre-load
- Skills are deferred tools, not full prompt content

## Scope Fence

**IN:** Measuring overhead, evaluating compression strategies
**OUT:** Implementing compression, refactoring CLAUDE.md structure

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made (partial GO: monitoring only)

## Go/No-Go Criteria

**GO if:**
- Prompt overhead > 15% of context (currently 10% — approaching)
- We control prompt assembly pipeline (we don't — Claude Code auto-loads)

**NO-GO if:**
- Prompt overhead is manageable (<15%) — currently borderline
- No control over loading pipeline — this is the blocker for compression

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
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

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-27T19:20:34Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T09:31:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-22cda771
- **Timestamp:** 2026-06-02T15:03:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
