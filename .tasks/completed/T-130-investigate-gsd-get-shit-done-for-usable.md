---
id: T-130
name: Investigate GSD (get-shit-done) for usable concepts, skills, patterns
description: >
  Review github.com/gsd-build/get-shit-done — a meta-prompting and context engineering system for Claude Code. Key areas to investigate: (1) Wave-based parallel execution model — plans grouped by dependency, independent tasks run parallel within waves. (2) Spec-driven development flow — structured requirements extraction before coding. (3) Context rot mitigation — fresh 200K context per executor. (4) Agent specialization — 11 agents (executor, planner, verifier, debugger, researchers, codebase-mapper, etc). (5) XML-structured plans with built-in verification. (6) STATE.md / PLAN.md / ROADMAP.md persistent state pattern. Compare with our framework's approach and identify concepts worth adopting.

status: work-completed
workflow_type: inception
owner: human
horizon: later
tags: []
related_tasks: []
created: 2026-02-17T20:37:02Z
last_update: 2026-02-19T08:12:27Z
date_finished: 2026-02-19T08:12:27Z
---

# T-130: Investigate GSD (get-shit-done) for usable concepts, skills, patterns

## Problem Statement

Can GSD's execution-optimized patterns (wave-based parallelism, plan-checking, 3-level verification) strengthen AEF's governance-optimized framework? GSD (15.9K stars) solves fresh-context parallel execution — a different design space from AEF's institutional memory and enforcement. The question: which patterns translate without distorting our architecture?

## Investigation Findings

### GSD Architecture
- **Not standalone** — Claude Code slash-command meta-prompting layer (npm install)
- 11 agents (markdown system prompts), 31 slash command orchestrators
- Persistent state in `.planning/`: STATE.md (<100 lines), ROADMAP.md, PLAN.md files
- Plans use YAML frontmatter + XML task bodies with embedded verification

### Key Patterns Compared

| GSD Pattern | AEF Equivalent | Gap? |
|---|---|---|
| Wave-based parallel execution (dependency graph → waves) | Ad-hoc Task tool dispatch | Yes — no pre-computed waves |
| gsd-plan-checker (static validation before execution) | Audit agent (post-hoc) | Yes — AEF validates after, not before |
| 3-level verification (exists/substantive/wired) | P-011 shell commands | Yes — no stub detection or wiring check |
| gsd-integration-checker (E2E flow, orphan exports) | Nothing | Yes |
| CONTEXT.md locked decisions (binding downstream) | Task Decisions section | Partial |
| gsd-codebase-mapper (CONVENTIONS.md, STACK.md) | Nothing | Yes |
| Research hierarchy + confidence levels | Nothing formal | Yes |
| Quick mode (lightweight ad-hoc) | `fw work-on` | Equivalent |
| STATE.md session bridge | LATEST.md handover | Equivalent |
| Fresh sub-agent contexts | Task tool dispatch | Equivalent |
| Write-to-disk, return path | Sub-Agent Dispatch Protocol | Equivalent |

### AEF Advantages GSD Lacks
- Metered budget enforcement (budget-gate.sh, actual token counting)
- Healing loop (failure classification, pattern learning)
- Episodic memory (searchable task history)
- Gaps register (persistent structural debt)
- Authority model (Tier 0-3, pre-tool-use hooks)
- Task lifecycle state machine (side-effect triggers)
- Auto-restart (claude-fw wrapper)
- Provider portability (any CLI agent)
- Assumption tracking

### Architectural Summary
- **GSD** = execution-optimized (parallel plans, fresh contexts, upfront specification)
- **AEF** = governance-optimized (reliability, auditability, cross-session learning)
- Complementary, not competing

## Assumptions

1. GSD wave parallelization requires different task model — **VALIDATED**: Plans with dependency graphs over file modifications ≠ AEF tasks
2. Some patterns translate as bounded enhancements — **VALIDATED**: 3-level verification, codebase conventions, research protocol
3. GSD has no institutional memory — **VALIDATED**: No episodic, no healing, no gaps, no assumptions

## Scope Fence

**IN:** Identify patterns adoptable as AEF enhancements
**OUT:** GSD's PLAN.md format, wave execution model, npm packaging

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- At least 2 patterns translate to concrete, bounded build tasks
- Patterns don't require restructuring the task model

**NO-GO if:**
- All valuable patterns require PLAN.md format or wave model
- Effort to adapt exceeds value

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: 3 adoptable patterns identified: (1) 3-level verification (exists/substantive/wired), (2) codebase-mapper convention (CONVENTIONS.md), (3) research confidence protocol. Each translates to a bounded build task without restructuring the task model.

**Date**: 2026-02-19T08:12:27Z
## Decision

**Decision**: GO

**Rationale**: 3 adoptable patterns identified: (1) 3-level verification (exists/substantive/wired), (2) codebase-mapper convention (CONVENTIONS.md), (3) research confidence protocol. Each translates to a bounded build task without restructuring the task model.

**Date**: 2026-02-19T08:12:27Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-02-19T07:31:08Z — status-update [task-update-agent]
- **Change:** horizon: later → next

### 2026-02-19T07:31:11Z — status-update [task-update-agent]
- **Change:** horizon: next → later

### 2026-02-19T07:31:15Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-19T07:31:21Z — status-update [task-update-agent]
- **Change:** status: started-work → captured

### 2026-02-19T08:08:00Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-19T08:12:27Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 3 adoptable patterns identified: (1) 3-level verification (exists/substantive/wired), (2) codebase-mapper convention (CONVENTIONS.md), (3) research confidence protocol. Each translates to a bounded build task without restructuring the task model.

### 2026-02-19T08:12:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
