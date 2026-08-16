---
id: T-168
name: "Repeatable framework sync — propagate learnings and improvements to Sprechloop
  project"
description: >
  Inception: Define a repeatable process to sync framework improvements into consumer
  projects (starting with /opt/001-sprechloop)

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
related_tasks: []
created: 2026-02-18T16:11:48Z
last_update: '2026-08-16T22:24:41Z'
date_finished: 2026-02-18T16:45:23Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:55Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:41Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
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

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c5573ae7
- **Timestamp:** 2026-06-02T14:59:08Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
