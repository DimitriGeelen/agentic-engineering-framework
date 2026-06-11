---
id: T-625
name: "Global framework sync — eliminate stale /root/.agentic-framework deadlock"
description: >
  Recurring deadlock: Claude Code hooks use bare `fw` → resolves to global /root/.agentic-framework/bin/fw
  → global has stale/missing scripts → all Bash/Write/Edit blocked. Happened 2+ times.
  Investigate: symlink, upgrade propagation, relative hook paths, or combination.
  Multi-agent exploration.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: [governance, hooks, deadlock]
components: [lib/upgrade.sh]
related_tasks: [T-622, T-614, T-481]
created: 2026-03-26T13:41:33Z
last_update: '2026-06-11T22:24:26Z'
date_finished: 2026-03-28T17:06:36Z
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
---

# T-625: Global framework sync — eliminate stale /root/.agentic-framework deadlock

## Problem Statement

Claude Code hooks in `.claude/settings.json` use bare `fw` which resolves to the global install at `/root/.agentic-framework/bin/fw`. When new hook scripts are added to the framework (e.g., `check-project-boundary.sh`, `commit-cadence.sh`, `loop-detect.sh`), the global copy is never synced. This causes total deadlock — Bash blocked by broken boundary hook, Write/Edit blocked by task gate. Has occurred 3+ times across sessions, requiring manual `cp` commands to unblock.

**For whom:** All framework users with a global install + project-local framework.
**Why now:** It's actively blocking work every session. The pattern is: add a new hook → deploy to consumers → global install becomes stale → next session deadlocks.

## Assumptions

A1: The global `/root/.agentic-framework/` is installed by `install.sh` and never updated afterwards
A2: `fw upgrade` only syncs to consumer project `.agentic-framework/` dirs, not to the global install
A3: Claude Code hooks run from the project working directory (can use relative paths)
A4: Symlinking the global install to a specific repo would break if that repo is removed
A5: Multiple machines may have different primary framework repos (not always /opt/999-*)
A6: Consumer projects on other machines (Mac .107) have the same vulnerability

## Exploration Plan

5 parallel investigation agents:

1. **Agent: hook-resolution** — Trace exactly how Claude Code resolves `fw` in hook commands. Test relative paths (`.agentic-framework/bin/fw`), absolute paths, PATH precedence. Does Claude Code run hooks from project root or CWD?

2. **Agent: upgrade-propagation** — Analyze `lib/upgrade.sh` and `install.sh` to map all sync targets. Where does the global install come from? What triggers updates? What's the gap?

3. **Agent: symlink-feasibility** — Test symlinking `/root/.agentic-framework` → a framework repo's `.agentic-framework/`. What breaks? What about multiple framework repos? What about `install.sh` behavior?

4. **Agent: hook-path-audit** — Audit all `.claude/settings.json` files (framework + 7 consumers) to catalog which hooks use bare `fw` vs relative paths. Map the blast radius.

5. **Agent: cross-machine-scan** — Check if `.107` Mac has the same stale global install problem. Scan via TermLink if available.

## Technical Constraints

- Claude Code hooks are defined in `.claude/settings.json` and snapshot at session start — changes require restart
- Hook `command` field is a string executed by the shell — env vars and relative paths may work
- The global install at `$HOME/.agentic-framework/` is created by `install.sh` for PATH-based `fw` access
- Consumer projects have vendored `.agentic-framework/` dirs synced by `fw upgrade`
- macOS and Linux have different PATH resolution behaviors

## Scope Fence

**IN scope:**
- How to keep global install in sync with framework source
- Whether hooks should use relative vs absolute vs bare `fw`
- Whether symlink, upgrade propagation, or hook path change is best
- Cross-machine applicability

**OUT of scope:**
- Rewriting the hook system entirely
- Changing Claude Code's hook execution model
- Consumer project hook format changes beyond path fixes

## Acceptance Criteria

### Agent
- [x] Problem statement validated with evidence (3 incidents, 2+ affected consumer projects, 3 vulnerable hook configs)
- [x] All 5 investigation spikes completed with findings
- [x] Assumptions A1-A6 validated or invalidated (4 confirmed, 1 partial, 1 unknown)
- [x] Recommendation written with rationale and rejected alternatives
- [x] Research artifact committed: `docs/reports/T-625-global-framework-sync.md`

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read `docs/reports/T-625-global-framework-sync.md`
  2. Evaluate the recommended approach against your multi-machine setup
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-625 go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Root cause is confirmed and reproducible
- Proposed fix eliminates the deadlock class (not just the current instance)
- Fix works for both framework repo AND consumer projects
- No breaking changes to existing `install.sh` or `fw upgrade` workflows

**NO-GO if:**
- Problem is Claude Code-specific and will be fixed upstream
- Fix requires invasive changes to hook execution model
- Cross-machine testing reveals fundamentally different root causes

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: Root cause is confirmed and reproducible; Proposed fix eliminates the deadlock class (not just the current instance); Fix works for both framework repo AND consumer projects; No breaking changes to...

**Date**: 2026-03-28T17:06:36Z
## Decision

**Decision**: GO

**Rationale**: Root cause is confirmed and reproducible; Proposed fix eliminates the deadlock class (not just the current instance); Fix works for both framework repo AND consumer projects; No breaking changes to...

**Date**: 2026-03-28T17:06:36Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-27T17:34:08Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-03-28T17:06:36Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Root cause is confirmed and reproducible; Proposed fix eliminates the deadlock class (not just the current instance); Fix works for both framework repo AND consumer projects; No breaking changes to...

### 2026-03-28T17:06:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-85235d5f
- **Timestamp:** 2026-06-02T15:03:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
