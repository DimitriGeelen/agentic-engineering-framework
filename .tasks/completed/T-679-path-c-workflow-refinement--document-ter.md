---
id: T-679
name: "Path C workflow refinement — document TermLink-based external ingestion, redo
  vnx experiment from scratch, capture learnings for TermLink and framework"
description: >
  Inception: Path C workflow refinement — document TermLink-based external ingestion,
  redo vnx experiment from scratch, capture learnings for TermLink and framework

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [path-c, termlink, ingestion, process-improvement]
components: []
related_tasks: [T-678, T-677, T-549, T-559]
created: 2026-03-28T21:30:03Z
last_update: '2026-05-19T17:56:24Z'
date_finished: 2026-03-28T21:55:27Z
bvp_scores_proposed:
  - ts: '2026-05-19T17:56:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 5
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=5 (body:class-neutral)
    rubric_sha: e4a00f38e801
---

# T-679: Path C workflow refinement — document TermLink-based external ingestion, redo vnx experiment from scratch, capture learnings for TermLink and framework

## Problem Statement

Path C ("External codebase ingestion") is the framework's workflow for analyzing external codebases. First attempted with OpenClaw (T-549), then vnx-orchestration (T-678). Both attempts hit significant friction:

1. **Boundary hook blocks TermLink** — The project boundary hook (T-559) scans bash command text literally. Any mention of an external path — even inside TermLink interact/inject/dispatch arguments — triggers a block. This makes the entire TermLink cross-project workflow broken without ugly workarounds (base64 encoding, temp scripts via Write tool).

2. **fw init/upgrade doesn't replace project hooks** — When a project has pre-existing `.claude/settings.json`, `fw upgrade` counts hooks but doesn't validate they're FRAMEWORK hooks. Pre-existing project hooks survive init+upgrade, leaving the project ungoverned.

3. **fw init re-vendors from self** — When `.agentic-framework/` already exists, vendor copies from itself to itself (source == target), making it a no-op.

4. **No documented workflow** — Path C exists as tribal knowledge from two attempts but has no written procedure, no seed task template, and no TermLink integration doc.

5. **TermLink MCP not seeded** — `fw init` seeds context7 and playwright MCP servers but not TermLink, which is the primary tool for cross-project isolation.

**For whom:** Framework users wanting to analyze/onboard existing codebases.
**Why now:** Two failed attempts prove the workflow needs structural fixes before it can be reliable.

## Prior Attempts (Evidence)

### T-549: OpenClaw deep-dive (first Path C attempt)
- Partial success — codebase survey and some fabric built
- Friction: no formal workflow, ad-hoc approach

### T-678: vnx-orchestration deep-dive (second Path C attempt)
- Clone to `/opt/051-Vinix24` succeeded
- `fw init` ran but skipped hooks (T-677 bug — fixed in `lib/init.sh`)
- Agent oscillated 5 times on hook strategy (merge vs replace vs keep both)
- User corrected fundamental workflow: "you set it up, prime it, seed tasks, then close activity and go to the working directory and start a session THERE"
- Boundary hook blocked ALL TermLink commands referencing the external path
- `fw upgrade` said "OK 8/0 hooks" but all 8 hooks pointed to Mac paths (non-functional)
- 6 seed tasks created (T-001 through T-006) but never executed

### Dialogue Log (T-678, 6 exchanges, 5 corrections)
See `.context/episodic/T-678-dialogue.yaml` for full log. Key corrections:
1. Don't init without asking
2. Framework hooks are authoritative — replace, not merge
3. Keep original hooks as investigation artifacts (.pre-fw backup)
4. Both framework AND project hooks needed (framework for governance, project for investigation)
5. Analysis happens IN the target project, not FROM the framework
6. Onboarding process IS the test — friction points become framework tasks

## Friction Points (7 discovered)

| # | Issue | Category | Severity |
|---|-------|----------|----------|
| F-1 | Boundary hook blocks TermLink commands (R-037) | Framework | **HIGH** — breaks entire Path C |
| F-2 | `fw upgrade` doesn't validate hook content | Framework | HIGH — leaves project ungoverned |
| F-3 | `fw init` re-vendors from self when .agentic-framework/ exists | Framework | Medium |
| F-4 | Version display confusing (pinned vs installed mismatch) | Framework | Low |
| F-5 | TermLink MCP not in default `fw init` MCP config | Framework | Medium |
| F-6 | No `termlink spawn --working-dir` flag | TermLink product | Medium |
| F-7 | TermLink interact also blocked by boundary hook | Framework (same root as F-1) | HIGH |

## Assumptions

1. TermLink MCP tools bypass the boundary hook (MCP tools aren't bash commands) — **to test**
2. Adding TermLink exception to boundary hook is safe and doesn't create a security hole — **to evaluate**
3. `fw init --force` with T-677 fix properly replaces hooks when run from inside the project — **to test**
4. Seed tasks (T-001 through T-006) are sufficient for onboarding — **to validate during redo**
5. The documented workflow is reproducible by a fresh agent session — **ultimate validation**

## Exploration Plan

- **Spike 1: Document the corrected Path C workflow** (~30 min)
  Write `docs/reports/T-679-path-c-workflow.md` with step-by-step procedure using TermLink

- **Spike 2: Fix boundary hook for TermLink** (~30 min)
  Add TermLink command exception to `check-project-boundary` hook

- **Spike 3: Fix fw upgrade hook validation** (~30 min)
  Make upgrade detect framework vs project hooks and replace when needed

- **Spike 4: Redo vnx experiment from scratch** (~1 hr)
  Clean `/opt/051-Vinix24`, re-clone, execute full Path C workflow, log every friction point

- **Spike 5: Capture learnings and create improvement tasks** (~30 min)
  Split learnings into TermLink product feedback and framework improvement tasks

## Technical Constraints

- Project boundary hook (T-559) is a PreToolUse hook on Bash — scans command text before execution
- TermLink 0.9.33 installed at `/root/.local/bin/termlink`
- TermLink MCP server available (`termlink mcp serve`) but not yet active (needs session restart)
- vnx project has Mac-specific paths in hooks — cannot execute on Linux server
- Framework hooks require `.agentic-framework/bin/fw hook <name>` path pattern

## Scope Fence

**IN:** Path C workflow documentation, boundary hook fix for TermLink, upgrade hook validation fix, redo vnx experiment, learnings capture, improvement task creation
**OUT:** Actually completing the vnx deep-dive (that's T-678), TermLink product changes (file issues only), changing TermLink's codebase

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Path C workflow documented in `docs/reports/T-679-path-c-workflow.md`
- [x] Boundary hook TermLink exception implemented (F-1/F-7 fix) — `check-project-boundary.sh`
- [x] fw upgrade hook content validation implemented (F-2 fix) — `lib/upgrade.sh`
- [x] vnx experiment redone from scratch — fw init + doctor + audit all pass
- [x] Friction points logged with severity and category (7 items in task + research artifact)
- [x] TermLink product learnings documented (for TermLink creator) — T-682
- [x] Framework improvement tasks created: T-680 (vendor self-ref), T-681 (MCP seeding), T-682 (TermLink feedback)
- [x] Research artifact committed — `docs/reports/T-679-path-c-workflow.md`

### Human
- [x] [REVIEW] Review Path C workflow document — is it clear enough for a fresh agent?
  **Steps:**
  1. Read `docs/reports/T-679-path-c-workflow.md`
  2. Evaluate: could a new session follow this without tribal knowledge?
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-679 go|no-go --rationale "your rationale"`
  **Expected:** Workflow is reproducible, friction points addressed
  **If not:** Note which steps are unclear or missing

## Go/No-Go Criteria

**GO if:**
- Path C workflow is documented and reproducible
- Boundary hook allows TermLink cross-project commands
- vnx experiment completes without manual workarounds
- At least 3 framework improvement tasks created from learnings

**NO-GO if:**
- TermLink cross-project workflow still requires workarounds after fixes
- fw init/upgrade still fails to apply framework hooks to existing projects
- Workflow documentation requires tribal knowledge to follow

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: GO

Rationale: Path C workflow was broken — two sessions failed with 5 course corrections. This inception fixed the two structural blockers (boundary hook blocking TermLink, upgrade ignoring non-framework hooks), documented the workflow, proved it end-to-end on a clean vnx experiment (fw doctor 0 failures, fw audit 47 pass), and created 3 improvement tasks for remaining issues. The workflow is now reproducible without tribal knowledge.

Evidence:
- F-1/F-7 FIXED: `check-project-boundary.sh` n...

**Date**: 2026-03-28T21:55:26Z

## Recommendation

**GO**

**Rationale:** Path C workflow was broken — two sessions failed with 5 course corrections. This inception fixed the two structural blockers (boundary hook blocking TermLink, upgrade ignoring non-framework hooks), documented the workflow, proved it end-to-end on a clean vnx experiment (fw doctor 0 failures, fw audit 47 pass), and created 3 improvement tasks for remaining issues. The workflow is now reproducible without tribal knowledge.

**Evidence:**
- F-1/F-7 FIXED: `check-project-boundary.sh` now whitelists TermLink commands
- F-2 FIXED: `lib/upgrade.sh` detects non-framework hooks and replaces them
- Clean experiment: `/opt/051-Vinix24` — fresh init → doctor all green → audit passes
- Workflow doc: `docs/reports/T-679-path-c-workflow.md`
- Improvement tasks: T-680 (vendor self-ref), T-681 (MCP seeding), T-682 (TermLink feedback)
- L-122: Path C L-117 exception recorded
- CLAUDE.md: "Presenting Work for Human Review" rule added

**Remaining (non-blocking):** T-680/T-681/T-682 are follow-up tasks, not blockers for this decision.

## Decision

**Decision**: GO

**Rationale**: GO

Rationale: Path C workflow was broken — two sessions failed with 5 course corrections. This inception fixed the two structural blockers (boundary hook blocking TermLink, upgrade ignoring non-framework hooks), documented the workflow, proved it end-to-end on a clean vnx experiment (fw doctor 0 failures, fw audit 47 pass), and created 3 improvement tasks for remaining issues. The workflow is now reproducible without tribal knowledge.

Evidence:
- F-1/F-7 FIXED: `check-project-boundary.sh` n...

**Date**: 2026-03-28T21:55:26Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-28T21:31:52Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T21:55:26Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** GO

Rationale: Path C workflow was broken — two sessions failed with 5 course corrections. This inception fixed the two structural blockers (boundary hook blocking TermLink, upgrade ignoring non-framework hooks), documented the workflow, proved it end-to-end on a clean vnx experiment (fw doctor 0 failures, fw audit 47 pass), and created 3 improvement tasks for remaining issues. The workflow is now reproducible without tribal knowledge.

Evidence:
- F-1/F-7 FIXED: `check-project-boundary.sh` n...

### 2026-03-28T21:55:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-06T22:29:20Z — status-update [task-update-agent]
- **Change:** horizon: now → next
