---
id: T-174
name: "Investigate: can handover replace compaction entirely?"
description: >
  Deep investigation (2-3 agents): Claude Code auto-compacts at ~180K tokens, summarizing prior context. But the framework already creates handovers that preserve context for session continuity. Questions: (1) What exactly does Anthropic's compaction step do? What information is preserved/lost? (2) Is compaction redundant given our handover system? (3) If we could forgo compaction, we'd gain ~20-30K usable tokens (safe zone up to ~160K with 20K reserved for handover routine). (4) What are the risks of disabling compaction — is it even possible to disable? (5) Could we configure compaction to use our handover as the summary source? This needs research into Claude Code internals and careful analysis of what compaction provides that handovers don't.

status: work-completed
workflow_type: inception
owner: claude-code
horizon: next
tags: []
related_tasks: []
created: 2026-02-18T18:24:39Z
last_update: 2026-02-18T18:51:17Z
date_finished: 2026-02-18T18:51:17Z
---

# T-174: Investigate: can handover replace compaction entirely?

## Problem Statement

Claude Code auto-compacts at ~98% of 200K tokens, producing a lossy LLM summary. The framework already has a handover system that writes structured context to disk (tasks, git state, decisions, suggestions). The compaction step is disruptive (mid-session), lossy (summary vs structured data), and has caused operational issues (T-145 deadlock, T-148 noise, cascade compactions). Question: can we eliminate compaction entirely and rely on handover + `fw resume` for context continuity?

## Assumptions

1. **Handovers capture equivalent or better information than compaction** — VALIDATED. 3-agent analysis confirmed handovers capture tasks, git state, decisions, suggestions. Gap: investigation breadcrumbs and tool outputs (addressable by strengthening emergency handover).
2. **Auto-compaction can be disabled** — VALIDATED. `autoCompactEnabled: false` already set in `~/.claude.json`. Setting is effective.
3. **Budget gate provides sufficient enforcement** — VALIDATED. Gate blocks Write/Edit/Bash at 150K tokens, forcing handover. Emergency handover fires automatically.
4. **Disabling compaction reclaims usable context** — VALIDATED. No compaction buffer needed (~33K), extending safe zone to ~170K.

## Exploration Plan

1. ~~Research Claude Code compaction internals~~ — DONE (Agent 1: claude-code-guide)
2. ~~Analyze handover vs compaction gap~~ — DONE (Agent 2: explore)
3. ~~Evaluate architectural options A/B/C/D~~ — DONE (Agent 3: plan)

## Technical Constraints

- `autoCompactEnabled: false` in `~/.claude.json` disables auto-compaction
- `/compact` command still triggers manual compaction (PreCompact hook still fires)
- No PostCompact hook available (feature requests pending)
- Claude Code CLI doesn't expose compaction API's `instructions` parameter (rules out Option C)

## Scope Fence

**IN:** Whether compaction is redundant, what to strengthen in handovers, budget threshold adjustments
**OUT:** Implementing the build tasks (separate tasks T-175/T-176/T-177)

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Handovers capture equivalent or better info than compaction summary — YES
- Auto-compaction can be disabled without breaking Claude Code — YES
- Budget gate provides enforcement that compaction previously provided — YES

**NO-GO if:**
- Compaction preserves critical info that handovers cannot capture — NO (gap is addressable)
- Disabling compaction causes session failures — NO (already disabled, system works)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

### 2026-02-18 — Compaction vs Handover architecture

- **Chose:** Option B — disable compaction, rely on handovers + `fw resume`
- **Why:** 3-agent investigation confirmed: (1) `autoCompactEnabled: false` already set and working, (2) budget gate provides structural enforcement at 150K, (3) emergency handover captures tasks/git/commits automatically, (4) compaction's lossy summary is strictly inferior to structured handover, (5) eliminating compaction buffer reclaims ~20-30K usable tokens
- **Rejected:** Option A (status quo — compaction causes T-145/T-148/cascade issues), Option C (feed handover to compaction API — CLI doesn't expose `instructions` param), Option D (auto-restart — is just Option B reframed)

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-02-18T18:30:05Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-18T18:50:32Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 3-agent investigation confirms Option B (disable compaction, rely on handovers) is correct. autoCompactEnabled:false already set. Budget gate provides structural enforcement. Emergency handover captures tasks/git/commits automatically. Compaction lossy summary is strictly inferior to structured handover + fw resume. Build tasks: strengthen emergency handover, adjust budget thresholds, clean up compact hooks.

### 2026-02-18T18:51:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
