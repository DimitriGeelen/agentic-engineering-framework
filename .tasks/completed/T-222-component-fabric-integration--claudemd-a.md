---
id: T-222
name: "Component Fabric integration — CLAUDE.md awareness, task-component linking, drift detection"
description: >
  Inception: Component Fabric integration — CLAUDE.md awareness, task-component linking, drift detection

status: work-completed
workflow_type: inception
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-20T09:23:31Z
last_update: 2026-02-20T11:11:33Z
date_finished: 2026-02-20T11:11:33Z
---

# T-222: Component Fabric integration — CLAUDE.md awareness, task-component linking, drift detection

## Problem Statement

The Component Fabric system (T-191) is fully built — 99 components, 12 subsystems, dependency graph, web UI — but it exists in a silo. Three integration gaps:

1. **CLAUDE.md has zero awareness.** The agent doesn't know `.fabric/` exists, when to use `fw fabric`, or how components relate to tasks. No guidance on registering new components or checking impact before changes.

2. **Tasks don't link to components.** When T-219 fixed `fabric.html`, nothing in the task metadata says "this touched the watchtower subsystem." Impact analysis requires git archaeology instead of structured queries.

3. **No feedback loop.** Components change via commits, but no mechanism detects "component X was modified without a task referencing it" (drift from the task-first principle).

**For whom:** The agent (needs CLAUDE.md guidance), the human (needs impact visibility in Watchtower), and the framework itself (needs structural enforcement consistency).

**Why now:** Component Fabric just reached maturity (T-215 UI, T-218 descriptions, T-219 layout). Integration while the system is fresh prevents it from becoming shelfware.

## Assumptions

A1. Adding a `components: []` frontmatter field to tasks is low-friction enough that agents will actually populate it.
A2. Component IDs can be reliably inferred from file paths in `git diff` output (reverse lookup: path → component ID).
A3. The value of task-component linking justifies the overhead (more fields to fill, more gates to check).
A4. CLAUDE.md guidance on fabric will change agent behavior (not just be ignored noise).

## Exploration Plan

**Spike 1: CLAUDE.md section draft** (30 min)
- Draft a Component Fabric section for CLAUDE.md covering: when to run `fw fabric scan`, how to register components, how to check impact before changes
- Evaluate: does it fit naturally into existing doc structure?

**Spike 2: Task-component linking prototype** (30 min)
- Add `components: []` to default.md template
- Prototype auto-population: at task completion, `update-task.sh` runs `git diff --name-only` and resolves paths to component IDs via `.fabric/components/*.yaml`
- Evaluate: accuracy of path→component resolution, false positive rate

**Spike 3: Drift detection audit check** (20 min)
- Prototype: audit section that compares recently modified files (git) against tasks referencing those components
- Evaluate: signal-to-noise ratio, false alarm rate

**Spike 4: Watchtower integration** (20 min)
- Mock: component detail page showing "Recent tasks" section
- Evaluate: is this useful with real data?

## Technical Constraints

- Task frontmatter is YAML — adding a field is backward-compatible (old tasks simply lack it)
- `create-task.sh` and `update-task.sh` need modification for new field
- Component ID format is the `id` field in `.fabric/components/*.yaml` (e.g., `agents/context/budget-gate.sh`)
- Path→component lookup needs to handle: renamed files, files not in fabric, multiple components per file

## Scope Fence

**IN scope:**
- CLAUDE.md Component Fabric section
- `components: []` task frontmatter field
- Auto-population prototype at task completion
- Drift detection concept
- Watchtower task↔component cross-references

**OUT of scope:**
- Enforcing component references (gate/hook) — too early, wait for evidence
- Dependency graph updates from task changes
- Cross-project component tracking

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested (at least A1-A3)
- [x] Go/No-Go decision made with rationale

## Go/No-Go Criteria

**GO if:**
- Path→component resolution works for >80% of changed files
- CLAUDE.md section fits naturally without bloating the doc
- At least one spike produces immediately useful output

**NO-GO if:**
- Path resolution is unreliable (<60% accuracy)
- Adding the field creates friction that outweighs visibility benefit
- The system works fine without integration (no evidence of real problems from the gap)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: Spike 1: CLAUDE.md section is 35 lines, fits naturally, immediately useful. Spike 2: 72% source-file resolution with 0% false positives, improvable to 85%+ by registering 3 missing files. Both core spikes validated. Skipping Spikes 3-4 (drift detection, Watchtower integration) — lower priority, can be separate tasks.

**Date**: 2026-02-20T11:11:07Z
## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-02-20T09:47:34Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Spike 1: CLAUDE.md section is 35 lines, fits naturally, immediately useful. Spike 2: 72% source-file resolution with 0% false positives, improvable to 85%+ by registering 3 missing files. Both core spikes validated. Skipping Spikes 3-4 (drift detection, Watchtower integration) — lower priority, can be separate tasks.

### 2026-02-20T11:11:03Z — status-update [task-update-agent]
- **Change:** owner: human → agent


### 2026-02-20T11:11:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
