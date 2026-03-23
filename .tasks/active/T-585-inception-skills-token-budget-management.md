---
id: T-585
name: "Inception: Skills token budget management — dynamic prompt compression to preserve working context"
description: >
  CLAUDE.md (~25K tokens) + skills + memory + system reminders consume ~40-50K tokens at session start. After compaction this is 25-30% of effective working context. Problem worsens as skills grow. OpenClaw solved this at 150 skills with applySkillsPromptLimits(): try full format, switch to compact (saves ~80%), binary-search largest prefix that fits. Budget cap 30K chars. Three-tier: bundled (always) > managed (if relevant) > workspace (if in scope). Investigate: (1) Measure current prompt overhead (CLAUDE.md + skills + memory + system). (2) Extract/adapt applySkillsPromptLimits() (~100 LOC) for SKILL.md format. (3) Classify skills by relevance to current task type (build tasks need /commit /plan, not /write /explore). (4) Dynamic compression: full format for high-relevance, compact (name + trigger) for medium, name-only for low. (5) Budget cap configurable via env var. Connects to P-009 (context budget management) — we gate context during session via budget-gate.sh but dont gate prompt overhead at startup. Research source: /opt/openclaw-evaluation/.context/working/round2-T-021.md (P4 deep-dive, token budget algorithm). OpenClaw source: src/agents/skills/workspace.ts (applySkillsPromptLimits, formatSkillsForPrompt), src/agents/skills/frontmatter.ts (SKILL.md parsing). Related framework: CLAUDE.md (current monolithic prompt), agents/context/checkpoint.sh (budget monitoring), agents/context/budget-gate.sh (context gating).

status: captured
workflow_type: inception
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-23T21:26:30Z
last_update: 2026-03-23T21:26:30Z
date_finished: null
---

# T-585: Inception: Skills token budget management — dynamic prompt compression to preserve working context

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

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
