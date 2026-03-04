---
id: T-307
name: "Inception: hybrid onboarding test (deterministic + AI interpretation)"
description: >
  A pure deterministic script cannot interpret nuanced onboarding results (expected day-1 noise vs real failures, CLAUDE.md quality, UX clarity). Need hybrid approach: deterministic scaffolding (bash runs steps, captures output) + stochastic reasoning (AI interprets results). Follows CLI/Agent/Skill hierarchy: (1) CLI fw test-onboarding runs mechanical steps, (2) agents/onboarding-test/ with bash script + AGENT.md intelligence, (3) /test-onboarding skill for in-session use. This inception scopes: what checkpoints, what interpretation criteria, how to structure the AGENT.md, what 'good' looks like at each step. Evidence: T-294 live simulation found 9 issues that no deterministic script would have caught. L-029: dry-running onboarding catches bugs unit tests miss. Source: T-294 dialogue.

status: started-work
workflow_type: inception
owner: human
horizon: next
tags: []
components: []
related_tasks: [T-294]
created: 2026-03-04T17:15:20Z
last_update: 2026-03-04T21:09:17Z
date_finished: null
---

# T-307: Inception: hybrid onboarding test (deterministic + AI interpretation)

## Problem Statement

Static audits (T-286 self-audit, fw audit) check configuration but cannot catch **flow-level bugs** — wizard step failures, focus persistence, sentinel logic, cross-step scope. T-294 live simulation found 9 issues (7 flow-level) that no static check would detect. L-029 confirms dry-running onboarding catches bugs unit tests miss. Need a hybrid approach: deterministic scaffolding (bash captures output at checkpoints) + AI interpretation (agent diagnoses partial failures, distinguishes day-1 noise from real bugs).

**For:** Framework maintainers and consumers deploying to new projects.
**Why now:** T-313/T-314/T-315 fixed generator bugs — need regression testing to prevent recurrence.

## Assumptions

- A-1: 8 checkpoints (scaffold → hooks → task → gate → commit → audit → self-audit → handover) cover the critical onboarding path
- A-2: AI interpretation adds meaningful value over pure pass/fail (diagnosis, not just detection)
- A-3: The test can run in <60 seconds on a clean system (acceptable CI overhead)
- A-4: Temp directory isolation is sufficient — no risk of corrupting real projects

## Exploration Plan

1. **Spike 1: Checkpoint design** (30 min) — Define 8 checkpoints with exact commands and assertions. Validate against T-294 issues: would each O-00X be caught?
2. **Spike 2: Deterministic script** (1 hour) — Build `agents/onboarding-test/test-onboarding.sh` with checkpoint scaffolding. Run against framework. Capture structured output.
3. **Spike 3: Agent interpretation** (30 min) — Write `agents/onboarding-test/AGENT.md` with interpretation criteria. Test on a deliberately broken project (reintroduce O-003 or O-008).

## Technical Constraints

- Must work without `fw` dependency (same chicken-and-egg as T-286)
- Needs `git` (for hook testing), `python3` (for YAML/JSON validation), `bash 4+`
- Creates temp directory — needs write access to `/tmp` or user-specified dir
- Cleanup must be reliable (trap on exit) to avoid leaving orphan dirs

## Scope Fence

**IN scope:**
- CLI script (`fw test-onboarding`)
- Agent guidance (`AGENT.md` with interpretation criteria)
- 8 checkpoints covering init → first-task → first-commit flow
- Structured output (PASS/WARN/FAIL per checkpoint)

**OUT of scope:**
- `/test-onboarding` skill (build task, not inception)
- Platform-specific testing (macOS, WSL — separate task)
- CI integration (separate task)
- Testing upgrade flow (`fw upgrade` on existing project)

## Acceptance Criteria

- [ ] Problem statement validated
- [ ] Assumptions tested (A-1 through A-4)
- [ ] Go/No-Go decision made
- [ ] Research artifact complete: `docs/reports/T-307-hybrid-onboarding-test.md`

## Go/No-Go Criteria

**GO if:**
- 8 checkpoints cover all 7 flow-level T-294 issues (O-003 through O-009)
- AI interpretation demonstrably catches something deterministic script misses
- Script runs in <60 seconds

**NO-GO if:**
- Deterministic pass/fail is sufficient (AI adds no diagnostic value)
- Checkpoint design cannot cover T-294 flow bugs
- Overhead is too high for the value delivered

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

### 2026-03-04T21:09:17Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
