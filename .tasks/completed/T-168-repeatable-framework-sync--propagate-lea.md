---
id: T-168
name: "Repeatable framework sync — propagate learnings and improvements to Sprechloop project"
description: >
  Inception: Define a repeatable process to sync framework improvements into consumer projects (starting with /opt/001-sprechloop)

status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T16:11:48Z
last_update: 2026-02-18T16:45:23Z
date_finished: 2026-02-18T16:45:23Z
---

# T-168: Repeatable framework sync — propagate learnings and improvements to Sprechloop project

## Problem Statement

The framework evolves continuously (new agents, updated CLAUDE.md rules, new `fw` commands, Watchtower, hooks). Consumer projects like Sprechloop (`/opt/001-sprechloop`) are linked via `.framework.yaml` and share `bin/fw` + agents, but:
- **CLAUDE.md is stale**: Sprechloop has the init template with `__PROJECT_NAME__` placeholders, not the current governance rules
- **No update mechanism**: `fw init` scaffolds once but there's no `fw upgrade` or `fw sync` to propagate improvements
- **Learnings don't transfer**: Patterns, decisions, and learnings from the framework project aren't available to Sprechloop sessions
- This should be a **repeatable process** — not a one-off fix

## Assumptions

- A1: Sprechloop's `.framework.yaml` correctly points to framework and `fw` commands already work there
- A2: CLAUDE.md needs a project-specific section + shared governance section (not a full copy)
- A3: Learnings/patterns from the framework project may be useful in Sprechloop but need curation, not bulk copy
- A4: A `fw upgrade` or `fw sync` command could handle the mechanical parts

## Exploration Plan

1. **Audit current gap** (5 min) — Compare what Sprechloop has vs what framework now provides
2. **Design sync mechanism** (15 min) — What should `fw upgrade` do? What's project-specific vs shared?
3. **Prototype on Sprechloop** (20 min) — Run the sync manually, document what changes
4. **Codify as `fw upgrade`** — Make it repeatable for any consumer project

## Technical Constraints

- Shared tooling mode: framework lives in `/opt/999-Agentic-Engineering-Framework`, projects reference it via `.framework.yaml`
- CLAUDE.md must preserve project-specific sections while updating shared governance
- Must not overwrite project decisions, learnings, or task history

## Scope Fence

**IN:** CLAUDE.md sync, template updates, `fw upgrade` command design, learning transfer strategy
**OUT:** Migrating Sprechloop to a different framework version, changing Sprechloop's task structure

## Acceptance Criteria

- [x] Problem statement validated with user
- [x] Gap analysis complete (what's stale in Sprechloop)
- [x] Sync mechanism designed (manual steps or `fw upgrade` spec)
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Clear gap exists between framework state and Sprechloop state
- A repeatable sync process can be defined (not project-specific hacks)

**NO-GO if:**
- Sprechloop is already current (no real gap)
- Sync would require project-specific customization that can't be generalized

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: fw upgrade command — pulls latest CLAUDE.md governance, updates templates, preserves project-specific sections, repeatable for any consumer project

**Date**: 2026-02-18T16:45:18Z
## Decision

**Decision**: GO

**Rationale**: fw upgrade command — pulls latest CLAUDE.md governance, updates templates, preserves project-specific sections, repeatable for any consumer project

**Date**: 2026-02-18T16:45:18Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-02-18T16:45:18Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** fw upgrade command — pulls latest CLAUDE.md governance, updates templates, preserves project-specific sections, repeatable for any consumer project

### 2026-02-18T16:45:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
