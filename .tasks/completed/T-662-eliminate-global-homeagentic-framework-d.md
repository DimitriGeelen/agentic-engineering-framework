---
id: T-662
name: "Eliminate global HOME/.agentic-framework dependency — full project isolation
  without PATH-based fw resolution"
description: >
  Inception: Eliminate global HOME/.agentic-framework dependency — full project isolation
  without PATH-based fw resolution

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: [T-625, T-660, T-559, T-614]
created: 2026-03-28T16:44:24Z
last_update: '2026-08-16T22:25:36Z'
date_finished: 2026-03-28T17:06:18Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:26Z'
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
  - ts: '2026-08-16T22:25:36Z'
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

# T-662: Eliminate global HOME/.agentic-framework dependency — full project isolation without PATH-based fw resolution

## Problem Statement

The framework violates its own Constitutional Directive D4 (Portability) and project isolation principle by depending on `$HOME/.agentic-framework/` — a global install created by `install.sh`. Claude Code hooks resolve bare `fw` via PATH to this global copy. When the global copy goes stale, all Bash/Write/Edit operations deadlock (3+ incidents documented in T-625).

T-660 made the problem worse by syncing MORE files to the global install during `fw upgrade`, reinforcing the dependency instead of eliminating it. The correct fix is architectural: remove the need for the global install entirely.

**For whom:** All framework users. Every project should be fully self-contained in its own directory.
**Why now:** T-660 just expanded the global install dependency surface. Every new hook or lib/ script widens the blast radius of stale global installs. The problem compounds with each release.

**Prior art:** T-625 researched this (5 parallel agents, GO decision pending). Key finding: hooks already use relative paths (`agents/context/check-active-task.sh`), consumer projects have vendored `.agentic-framework/bin/fw`, the global install is only needed for PATH-based `fw` resolution and for hooks that internally call `fw`.

## Assumptions

- A1: Claude Code hooks run from the project working directory (CWD = project root) — meaning relative paths in hook commands resolve correctly
- A2: Consumer project hooks can use `.agentic-framework/bin/fw` instead of bare `fw` — tested in T-625 Agent 1
- A3: The framework repo itself can use `bin/fw` directly — no PATH dependency needed
- A4: `install.sh` can stop creating the global install without breaking existing users (backward compat concern)
- A5: Removing the global install does not break terminal usage (`fw` typed at any directory)
- A6: Cross-machine setups (Mac .107 ↔ Linux .112) have different PATH resolution that may complicate this

## Exploration Plan

1. **Spike 1: Hook resolution audit (30min)** — Trace every hook command in `.claude/settings.json` across framework + 7 consumers. Map which ones use bare `fw`, which use relative paths. Test: does Claude Code set CWD to project root before running hooks?

2. **Spike 2: Internal fw calls audit (30min)** — Grep all hook scripts for internal calls to `fw` or `bin/fw`. Map the dependency chain. Can all internal calls use `$FRAMEWORK_ROOT/bin/fw` instead of bare `fw`?

3. **Spike 3: Vendored fw path feasibility (30min)** — Test replacing bare `fw` in hook commands with `.agentic-framework/bin/fw` for consumers and `bin/fw` for the framework repo. Does `fw upgrade` propagate this correctly? Edge cases: new hooks added post-upgrade.

4. **Spike 4: install.sh deprecation path (20min)** — What breaks if `install.sh` stops creating `$HOME/.agentic-framework/`? Can it create a symlink to the framework repo instead? Or should it just add `bin/` to PATH in shell profile?

5. **Spike 5: Terminal UX impact (20min)** — Without a global install, how does the user type `fw` from any directory? Options: shell alias, PATH entry pointing to framework repo, project-detection script. What's the D4-compliant approach?

6. **Spike 6: T-660 revert assessment (10min)** — What's the safest way to handle T-660? Revert entirely, keep as bridge with deprecation notice, or extract the global sync into a separate opt-in command?

## Technical Constraints

- Claude Code hooks snapshot at session start — changes to `.claude/settings.json` require restart
- Hook `command` field is a shell string — env vars and relative paths work
- Consumer projects may not have identical directory structures
- macOS and Linux have different PATH resolution
- Multiple framework repos may exist on one machine (dev + production)
- The framework repo uses `bin/fw` directly, consumer projects use `.agentic-framework/bin/fw`

## Scope Fence

**IN scope:**
- How to eliminate the `$HOME/.agentic-framework/` dependency
- What hook path format achieves full project isolation
- Whether `install.sh` should change behavior
- Terminal UX for users who want `fw` on PATH
- T-660 disposition (revert/keep/deprecate)

**OUT of scope:**
- Rewriting Claude Code's hook execution model
- Changing the vendored framework directory structure (`.agentic-framework/`)
- Cross-machine sync (that's TermLink's domain)

## Acceptance Criteria

### Agent
- [x] Problem statement validated with evidence (deadlock incidents, portability violation, isolation violation)
- [x] All 6 spikes completed with findings
- [x] Assumptions A1-A6 validated or invalidated
- [x] Recommendation written with rationale and migration path
- [x] Research artifact committed: `docs/reports/T-662-eliminate-global-install.md`

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read `docs/reports/T-662-eliminate-global-install.md`
  2. Evaluate whether the proposed approach preserves terminal UX while achieving isolation
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-662 go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, build tasks created for migration
  **If not:** Ask agent for clarification on specific spikes

## Go/No-Go Criteria

**GO if:**
- A path format exists that eliminates the global install for both framework and consumer projects
- The migration is backward-compatible (existing users aren't broken immediately)
- Terminal UX has a clean solution (user can still type `fw` without knowing project paths)
- T-660 can be safely deprecated or reverted as part of the migration

**NO-GO if:**
- Claude Code hook execution requires PATH-based resolution (no workaround)
- Multiple framework repos on one machine make relative paths ambiguous
- The terminal UX degradation is unacceptable (user must `cd` to project before any `fw` command)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Recommendation

**Recommendation:** GO
**Rationale:** A path format exists that eliminates the global install for both framework and consumer projects; The migration is backward-compatible (existing users aren't broken immediately); Terminal UX has a ...

## Decisions

**Decision**: GO

**Rationale**: A path format exists that eliminates the global install for both framework and consumer projects; The migration is backward-compatible (existing users aren't broken immediately); Terminal UX has a ...

**Date**: 2026-03-28T17:06:18Z
## Decision

**Decision**: GO

**Rationale**: A path format exists that eliminates the global install for both framework and consumer projects; The migration is backward-compatible (existing users aren't broken immediately); Terminal UX has a ...

**Date**: 2026-03-28T17:06:18Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-28T16:58:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T17:06:18Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** A path format exists that eliminates the global install for both framework and consumer projects; The migration is backward-compatible (existing users aren't broken immediately); Terminal UX has a ...

### 2026-03-28T17:06:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-06T22:29:20Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-915fe47d
- **Timestamp:** 2026-06-02T15:04:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
