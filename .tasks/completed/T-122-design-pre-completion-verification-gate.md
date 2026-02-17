---
id: T-122
name: Design pre-completion verification gate
description: >
  Inception: Design pre-completion verification gate

status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: []
related_tasks: []
created: 2026-02-17T16:36:39Z
last_update: 2026-02-17T16:46:29Z
date_finished: 2026-02-17T16:46:29Z
---

# T-122: Design pre-completion verification gate

## Problem Statement

The agent self-assesses acceptance criteria and marks tasks complete without verifying outputs work end-to-end. This pattern has shipped bugs in 3 tasks:

- **T-108** (premature closure): Onboarding bugs found only during live dry-run
- **T-118** (error rationalization): Silent error bypass — agent rationalized failures as expected
- **T-121** (3 post-completion bugs): Invalid YAML (backticks), missing Watchtower UI, Flask cache stale

**Current state:** The AC gate in `update-task.sh` (line 147-170) checks that `[x]` checkboxes are ticked. It verifies the agent *says* it's done — not that the work *actually works*.

**What exists but doesn't solve it:** The `superpowers:verification-before-completion` skill is advisory (agent discipline). The framework philosophy is structural enforcement (framework authority). Advisory guidance has failed 3 times.

**For whom:** The agent (prevent shipping bugs) and the user (stop catching bugs that the framework should catch).

**Why now:** User identified this as a recurring pattern across 3 tasks in a single day. Frustration is high and justified.

## Assumptions

- A-1: Verification commands can be defined per-task in a structured way
- A-2: Automated verification catches the majority of the bugs that shipped (YAML parse, HTTP status, template render)
- A-3: The overhead of defining verification steps is small relative to the cost of shipping bugs
- A-4: A structural gate (not advisory skill) is required because the advisory approach has failed 3 times

## Exploration Plan

**Spike 1: Evidence audit** (5 min)
Review T-108, T-118, T-121 — what specific verification would have caught each bug? Classify by type (parse check, HTTP check, functional check).

**Spike 2: Design options** (15 min)
Evaluate approaches:
1. Verification section in task template (agent writes commands + expected results; gate checks they ran)
2. Post-AC hook in update-task.sh (runs commands defined in task before allowing completion)
3. Verification log (.context/verification/T-XXX.log — must exist and be recent)
4. Two-phase completion (work-completed → verification-pending → verified)

Score each on: enforcement strength, overhead, portability, false-positive risk.

**Spike 3: Prototype** (20 min)
Build the chosen approach as a working prototype. Test against the T-121 failure cases.

## Scope Fence

**IN scope:**
- Structural verification gate in the task completion flow
- Integration with update-task.sh work-completed transition
- Task template changes for verification steps
- Testing against historical failure cases

**OUT of scope:**
- Changing the advisory verification skill (it can coexist)
- Full CI/CD integration
- Multi-agent verification (G-004)
- Verification for non-code tasks (docs, decisions)

## Acceptance Criteria

- [x] Problem statement validated with evidence from 3+ tasks (T-108, T-118, T-121)
- [x] At least 3 design options evaluated with trade-offs (4 evaluated: template section, post-AC hook, log file, two-phase)
- [x] Go/No-Go decision made with rationale
- [x] If GO: prototype built and tested (4 test cases: pass, fail, force-bypass, backward-compat)

## Go/No-Go Criteria

**GO if:**
- A structural gate can catch >=2 of the 3 historical bug classes (YAML parse, HTTP status, template render)
- Overhead per task is <2 minutes of agent time
- Gate integrates into existing update-task.sh flow without breaking backward compatibility

**NO-GO if:**
- All viable approaches require >5 min overhead per task (cost exceeds benefit)
- Verification requires capabilities the agent doesn't reliably have (e.g., browser testing)
- The problem is better solved by improving the advisory skill alone

## Decisions

**Decision**: GO

**Rationale**: All 3 GO criteria met. Prototype built and tested with 4 test cases. Gate catches all historical bug classes.

**Date**: 2026-02-17T16:46:29Z
## Decision

**Decision**: GO

**Rationale**: All 3 GO criteria met. Prototype built and tested with 4 test cases. Gate catches all historical bug classes.

**Date**: 2026-02-17T16:46:29Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-02-17T16:46:29Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** All 3 GO criteria met. Prototype built and tested with 4 test cases. Gate catches all historical bug classes.

### 2026-02-17T16:46:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
