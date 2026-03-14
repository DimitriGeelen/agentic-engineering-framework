---
id: T-495
name: "Path isolation — eliminate hardcoded absolute paths from all committed files"
description: >
  G-021. fw init bakes machine-specific absolute paths into .claude/settings.json (12 hooks), .framework.yaml, and CLAUDE.md. On any clone/move/different machine, ALL enforcement hooks silently fail — task gate, tier 0, budget gate, plan mode block, all of them. fw doctor, fw upgrade, and fw self-test all give false green because they dont validate paths. This is existential: the frameworks entire enforcement layer is a facade on any non-original environment. Spikes: (1) fw hook subcommand for runtime path resolution, (2) .framework.yaml path discovery, (3) fw doctor hook path validation, (4) fw upgrade path repair, (5) cross-machine self-test phase, (6) CLAUDE.md template path elimination.

status: work-completed
workflow_type: inception
owner: agent
horizon: now
tags: [portability, enforcement, P0]
components: []
related_tasks: []
created: 2026-03-14T22:25:26Z
last_update: 2026-03-14T22:35:38Z
date_finished: 2026-03-14T22:35:38Z
---

# T-495: Path isolation — eliminate hardcoded absolute paths from all committed files

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

- [x] Problem statement validated (G-021 registered, 3 contamination points, 4 detection gaps identified)
- [x] Assumptions tested (fw hook 4ms overhead, PATH available in hook context, cwd=project root)
- [x] Go/No-Go decision made (GO — 5 build tasks, ~2-3h effort)

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

**Decision**: GO

**Rationale**: All spikes validated: fw hook resolves at runtime (4ms overhead), PROJECT_ROOT from cwd, portable settings.json with zero absolute paths. 5 build tasks, ~2-3h effort. Urgent — G-021.

**Date**: 2026-03-14T22:35:38Z
## Decision

**Decision**: GO

**Rationale**: All spikes validated: fw hook resolves at runtime (4ms overhead), PROJECT_ROOT from cwd, portable settings.json with zero absolute paths. 5 build tasks, ~2-3h effort. Urgent — G-021.

**Date**: 2026-03-14T22:35:38Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-14T22:32:15Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-14T22:35:05Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** All spikes validated: fw hook resolves at runtime (4ms overhead), PROJECT_ROOT from cwd, portable settings.json with zero absolute paths. 5 build tasks, ~2-3h effort. This is urgent — G-021 silently disables all enforcement on any non-original machine.

### 2026-03-14T22:35:11Z — status-update [task-update-agent]
- **Change:** owner: human → agent

### 2026-03-14T22:35:16Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** All spikes validated: fw hook resolves at runtime (4ms overhead), PROJECT_ROOT from cwd, portable settings.json with zero absolute paths. 5 build tasks, ~2-3h effort. Urgent — G-021 silently disables all enforcement on any non-original machine.

### 2026-03-14T22:35:38Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** All spikes validated: fw hook resolves at runtime (4ms overhead), PROJECT_ROOT from cwd, portable settings.json with zero absolute paths. 5 build tasks, ~2-3h effort. Urgent — G-021.

### 2026-03-14T22:35:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
