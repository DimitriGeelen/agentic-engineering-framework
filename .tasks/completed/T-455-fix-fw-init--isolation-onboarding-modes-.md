---
id: T-455
name: "Fix fw init — isolation, onboarding modes, knowledge separation"
description: >
  Inception: Fix fw init — isolation, onboarding modes, knowledge separation

status: work-completed
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-12T16:03:33Z
last_update: 2026-03-12T17:00:23Z
date_finished: 2026-03-12T17:00:23Z
---

# T-455: Fix fw init — isolation, onboarding modes, knowledge separation

## Problem Statement

When `fw init` initializes a consumer project, three things break:

1. **Knowledge leakage** — 10 practices, 18 decisions, 12 patterns from the framework's 441-task history get copied into the project. Consumer sees framework-specific Watchtower/deployment decisions that pollute their governance.
2. **Weak onboarding** — Only 3 generic tasks created for existing projects, 1 for greenfield. No framework orientation, no validation proof, no hands-on cycle.
3. **No functional validation** — File creation is validated but hook functionality, governance isolation, and task-flow are not. commit-msg hook has a bug (calls undefined `find_task_file()`).

**Core tension:** Framework knowledge is functional (audit/healing reference specific decisions/patterns). Stripping it breaks governance. Keeping it pollutes consumer projects.

**For whom:** Any developer using `fw init` on a new or existing project.
**Why now:** User experiencing real friction with init on multiple projects.

## Research Completed

5 parallel research agents dispatched. All findings in `docs/reports/`:

| Spike | File | Key Finding |
|-------|------|-------------|
| 1. Init audit | `fw-agent-t455-spike1-init-audit.md` | Path isolation CORRECT. Data seeding is the problem. 11-step init documented. |
| 2. Knowledge taxonomy | `fw-agent-t455-spike2-knowledge-taxonomy.md` | 59% universal, 41% framework-specific. Patterns 100% universal. Decisions only 41%. |
| 3. Onboarding tasks | `fw-agent-t455-spike3-onboarding-tasks.md` | Proposed 6-7 tasks in 3 phases: orientation → health → hands-on. |
| 4. Post-init validation | `fw-agent-t455-spike4-post-init-validation.md` | Hook bug found. 0% functional validation. 3 critical issues. |
| 5. Prior decisions | (inline in research artifact) | T-032→T-306→T-294 history. fw upgrade (T-169) partially built. |

Full synthesis: `docs/reports/T-455-fw-init-isolation-research.md`

## Assumptions

- A-001: Consumer projects should start with minimal/no framework-specific data
- A-002: Universal governance principles (patterns, core decisions) add value even for new projects
- A-003: Post-init validation that proves "the loop works" prevents early abandonment
- A-004: Two distinct modes (greenfield vs adopt) serve different needs better than auto-detection

## 4 Design Decisions PENDING (Human)

### Q1: How to handle framework knowledge?
- **A.** Empty slate — no seeds at all
- **B.** Curated universal seed (~15 items: core decisions + all patterns)
- **C.** Two modes — empty default, `--seed-framework` opt-in
- **D.** Runtime reference — query framework at runtime, don't copy

### Q2: Naming for init modes?
- **A.** `fw init` (greenfield default) + `fw init --adopt` (existing codebase)
- **B.** `fw init --greenfield` + `fw init --existing`
- **C.** Auto-detect (current, fragile — has package.json?)
- **D.** `fw new` + `fw adopt` (separate top-level commands)

### Q3: Knowledge updates over time?
- **A.** One-shot copy, diverges forever (current)
- **B.** `fw upgrade` syncs seeds (T-169 partially built)
- **C.** Layered: framework base + project overlay (T-316 spike)

### Q4: Scope of fix?
- **A.** Fix hook bug + clean seeds only (1-2 sessions)
- **B.** A + onboarding tasks + validation tiers (3-4 sessions)
- **C.** B + runtime reference + fw upgrade sync (5-8 sessions)

## Scope Fence

**IN scope:**
- Fix knowledge seeding (isolation)
- Redesign onboarding tasks (both modes)
- Post-init validation (functional + semantic)
- Init output and naming
- Fix commit-msg hook bug (find_task_file undefined)

**OUT of scope:**
- `fw upgrade` command (T-434 / T-169)
- Layered CLAUDE.md (T-316)
- Multi-project management
- Watchtower integration for init

## Acceptance Criteria

- [x] Problem statement validated
- [x] Research spikes completed (5/5)
- [x] 4 design decisions answered by human
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Design decisions Q1-Q4 answered
- Scope bounded to Option A or B (Q4)
- Build tasks decomposed

**NO-GO if:**
- Requires architectural changes to agent path resolution (already correct)
- Scope creeps to C (runtime reference + upgrade sync) without separate inception

## Verification

test -f docs/reports/T-455-fw-init-isolation-research.md
test -f docs/reports/fw-agent-t455-spike1-init-audit.md
test -f docs/reports/fw-agent-t455-spike2-knowledge-taxonomy.md
test -f docs/reports/fw-agent-t455-spike3-onboarding-tasks.md
test -f docs/reports/fw-agent-t455-spike4-post-init-validation.md

## Decisions

**Decision**: GO

**Rationale**: Research complete (5 spikes, 3 prior inceptions reviewed). Decisions: curated universal seed, thin bootstrap + template-based onboarding tasks, PD-/PL-/PP- project prefix, scope B. Templates over dynamic creation for determinism and maintainability.

**Date**: 2026-03-12T17:00:22Z
## Decision

**Decision**: GO

**Rationale**: Research complete (5 spikes, 3 prior inceptions reviewed). Decisions: curated universal seed, thin bootstrap + template-based onboarding tasks, PD-/PL-/PP- project prefix, scope B. Templates over dynamic creation for determinism and maintainability.

**Date**: 2026-03-12T17:00:22Z

## Updates

### 2026-03-12T16:03:33Z — task-created
- Created inception task for fw init overhaul

### 2026-03-12T16:10:00Z — research-dispatched
- 5 parallel Explore agents dispatched for spikes 1-5
- Spike 1: fw init audit (what it does, path isolation, data seeding)
- Spike 2: knowledge taxonomy (universal vs framework-specific)
- Spike 3: onboarding tasks design (greenfield vs adopt)
- Spike 4: post-init validation (what fails, what should be checked)
- Spike 5: prior decisions search (T-032→T-306→T-294 history)

### 2026-03-12T17:00:00Z — research-complete
- All 5 spikes complete. Findings synthesized in docs/reports/T-455-fw-init-isolation-research.md
- Spike files persisted to docs/reports/ (not just /tmp)
- Critical bug found: commit-msg hook calls undefined find_task_file()
- Knowledge taxonomy: 59% universal, 41% framework-specific
- 4 design decisions awaiting human input

### 2026-03-12T16:59:32Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Research complete (5 spikes, 3 prior inceptions reviewed). Decisions: curated universal seed, thin bootstrap + template-based onboarding tasks, PD-/PL-/PP- project prefix, scope B. Templates over dynamic creation for determinism and maintainability.

### 2026-03-12T16:59:45Z — status-update [task-update-agent]
- **Change:** owner: human → agent

### 2026-03-12T16:59:53Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Research complete (5 spikes, 3 prior inceptions reviewed). Decisions: curated universal seed, thin bootstrap + template-based onboarding tasks, PD-/PL-/PP- project prefix, scope B. Templates over dynamic creation for determinism and maintainability.

### 2026-03-12T17:00:22Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Research complete (5 spikes, 3 prior inceptions reviewed). Decisions: curated universal seed, thin bootstrap + template-based onboarding tasks, PD-/PL-/PP- project prefix, scope B. Templates over dynamic creation for determinism and maintainability.

### 2026-03-12T17:00:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
