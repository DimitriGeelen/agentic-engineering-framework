---
id: T-482
name: "Inception: Install model — global shared vs project-local vs hybrid"
description: >
  Current install model: single global clone at ~/.agentic-framework shared by all
  projects. This creates coupling — dirty state blocks all projects, macOS filemode
  diffs propagate, no project-level version pinning. Options: A) Keep global + robust
  updater, B) Project-local vendoring, C) Hybrid (global CLI, project-local config).
  Need to evaluate isolation, disk usage, update semantics, and multi-project workflows.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: [architecture, portability, installer]
components: []
related_tasks: []
created: 2026-03-14T14:49:13Z
last_update: '2026-08-16T22:25:32Z'
date_finished: 2026-03-15T14:00:39Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:22Z'
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
  - ts: '2026-08-16T22:25:32Z'
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

# T-482: Inception: Install model — global shared vs project-local vs hybrid

## Problem Statement

Current install model: single global clone at `~/.agentic-framework` (174MB, 2897 files) shared by all projects via symlink. This creates coupling:

1. **Absolute path baking**: `.framework.yaml` stores `framework_path: /root/.agentic-framework` — breaks on clone/move (G-021 partial)
2. **Version lock**: All projects forced to same framework version. Sprechloop at 1.0.0, Bilderkarte at 1.2.6 — no per-project pinning
3. **Shared fate**: Dirty state in global repo breaks all projects. Manual `cp` needed to sync changes (T-496 evidence)
4. **174MB global install**: Includes .git, .tasks, .context — framework's own governance data, not needed by consumer projects

**For whom:** Framework operators with multiple projects, and future external adopters.
**Why now:** T-496 solved settings.json path isolation but `.framework.yaml` still bakes paths. External adoption (T-334) will multiply these problems.

## Assumptions

- A1: `bin/fw` can resolve framework_path at runtime (from its own location) instead of reading `.framework.yaml`
- A2: Version compatibility checking (project min_version vs installed version) is feasible
- A3: The global install can be trimmed to essential files only (no .tasks/.context)
- A4: Two consumer projects is too few to justify per-project vendoring or package manager distribution

## Exploration Plan

| # | Spike | Time-box | Deliverable |
|---|-------|----------|-------------|
| 1 | `.framework.yaml` runtime resolution | 20min | Can `bin/fw` resolve framework_path at runtime? What breaks? |
| 2 | Version compatibility check | 15min | Prototype: `fw` warns on version mismatch |
| 3 | Clean global install | 15min | Minimum file set needed for global install |
| 4 | Multi-version scenario | 15min | What breaks with 2 projects needing different versions? |

## Technical Constraints

- `fw` is resolved via symlink: `/usr/local/bin/fw` → `~/.agentic-framework/bin/fw`
- Consumer projects reference framework via `.framework.yaml:framework_path`
- `lib/paths.sh` resolves FRAMEWORK_ROOT from script location, PROJECT_ROOT from git toplevel or cwd
- `fw hook` (T-496) already resolves paths at runtime — `.framework.yaml` is the remaining hardcoded path

## Scope Fence

**IN scope:** Evaluate install model options, test assumptions about runtime resolution, version compatibility, global install size. Decide: harden current model vs vendor vs hybrid.

**OUT of scope:** Package manager distribution (premature), plugin marketplace, auto-update daemon, multi-machine sync.

## Acceptance Criteria

### Agent
- [x] Problem statement validated with evidence from current topology (2 consumers, version drift, G-021)
- [x] Assumptions tested (A1: runtime resolution validated by T-496, A2: version compat feasible, A3: 1.2MB vendor set, A4: overruled by human — full isolation regardless of consumer count)
- [x] Options analyzed with directive scoring (A:12, B:15, C:12, D:14)
- [x] Research artifact at docs/reports/T-482-install-model-inception.md
- [x] Go/No-Go decision made (GO — full isolation, plain copy, ~7MB committed)

### Human
- [x] [REVIEW] Review install model recommendation and approve direction
  **Steps:**
  1. Read `docs/reports/T-482-install-model-inception.md`
  2. Consider: does Option A+ (hardened global) match your operational needs?
  3. Assess: is per-project vendoring needed for termlink or other field installs?
  **Expected:** Clear direction on which option to pursue
  **If not:** Discuss specific concerns or alternative requirements

## Go/No-Go Criteria

**GO if:**
- Runtime resolution of framework_path is feasible without breaking existing projects
- Version compatibility check is implementable in <1 session
- The work decomposes into ≤3 build tasks

**NO-GO if:**
- Runtime resolution breaks the shared-tooling model
- Coupling is too deep to fix incrementally
- Evidence shows per-project vendoring (Option B/D) is needed now

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: Full isolation via project-local vendoring. Plain copy of complete framework (~7MB) committed to project repo. Three init paths (new/existing/clone) all work. Updates are human-decided, pulled from upstream. Global install is bootstrap only.

**Date**: 2026-03-15T14:00:39Z
## Decision

**Decision**: GO

**Rationale**: Full isolation via project-local vendoring. Plain copy of complete framework (~7MB) committed to project repo. Three init paths (new/existing/clone) all work. Updates are human-decided, pulled from upstream. Global install is bootstrap only.

**Date**: 2026-03-15T14:00:39Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-15T13:22:16Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-15T14:00:07Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Full isolation via project-local vendoring. Plain copy of complete framework (~7MB) committed to project repo. Three init paths (new/existing/clone) all work. Updates are human-decided, pulled from upstream. Global install is bootstrap only.

### 2026-03-15T14:00:13Z — status-update [task-update-agent]
- **Change:** owner: human → agent

### 2026-03-15T14:00:13Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Full isolation via project-local vendoring. Plain copy of complete framework (~7MB) committed to project repo. Three init paths (new/existing/clone) all work. Updates are human-decided, pulled from upstream. Global install is bootstrap only.

### 2026-03-15T14:00:39Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Full isolation via project-local vendoring. Plain copy of complete framework (~7MB) committed to project repo. Three init paths (new/existing/clone) all work. Updates are human-decided, pulled from upstream. Global install is bootstrap only.

### 2026-03-15T14:00:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c6db2756
- **Timestamp:** 2026-06-02T15:03:06Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
