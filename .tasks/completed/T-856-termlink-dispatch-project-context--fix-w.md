---
id: T-856
name: "TermLink dispatch project context — fix worker CWD resolution so hooks find
  correct PROJECT_ROOT"
description: >
  Inception: TermLink dispatch project context — fix worker CWD resolution so hooks
  find correct PROJECT_ROOT

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-04T18:23:31Z
last_update: '2026-06-11T22:24:31Z'
date_finished: 2026-04-13T13:20:22Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:31Z'
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

# T-856: TermLink dispatch project context — fix worker CWD resolution so hooks find correct PROJECT_ROOT

## Problem Statement

`fw termlink dispatch` spawns Claude workers in `/tmp/tl-dispatch/<name>/`. When the worker
uses any tool, framework PreToolUse hooks fire and try to find PROJECT_ROOT by walking up
from CWD. Since CWD is `/tmp/`, hooks either fail or find the wrong project. This causes
3 cascading failures: wrong project boundary, stale budget gate, wrong dispatch counter.

The dispatch preamble tells agents to `cd` into the project, but hooks fire on the very first
tool call before the agent can execute `cd`. Chicken-and-egg problem.

Evidence: T-842 test-suite worker fully blocked. T-835 workers succeeded only because they
were research-only (no Write/Edit needed inside the project).

## Assumptions

- A1: TermLink binary could support a `--working-dir` or `--cwd` flag for `termlink spawn`
- A2: Alternatively, `fw termlink dispatch` could create the tmux session WITH an initial `cd` command
- A3: The Claude Code `--cwd` flag (if it exists) could set the working directory before hooks fire
- A4: A `.framework.yaml` symlink in `/tmp/tl-dispatch/<name>/` pointing to the real project could trick the hook resolution

## Exploration Plan

1. **Spike A (30 min)**: Check if `tmux new-session -c <dir>` sets initial CWD — test with `termlink spawn --shell` + manual cd
2. **Spike B (30 min)**: Check if `claude -p` supports `--cwd` or if PROJECT_ROOT env var is inherited
3. **Spike C (30 min)**: Try `.framework.yaml` symlink in dispatch dir as lightweight workaround
4. **Evaluate**: Compare options on reliability, TermLink binary changes needed, upstream compatibility

## Technical Constraints

- TermLink binary is a separate Rust project (`https://github.com/DimitriGeelen/termlink`)
- Changes to TermLink require a separate PR + release cycle
- Framework-side workarounds (env vars, symlinks) are faster to ship
- Worker sessions must survive parent context compaction (T-818)

## Scope Fence

**IN scope:** Fix worker CWD so hooks resolve PROJECT_ROOT correctly
**OUT of scope:** TermLink binary modifications (those go via T-682 pickup)

## Acceptance Criteria

### Agent
- [x] Problem statement validated — T-792 already fixed the root cause (export PROJECT_ROOT in run.sh)
- [x] At least 2 approaches investigated — env var export (implemented), --cwd flag (not needed), symlink (not needed)
- [x] Recommendation written with rationale (NO-GO — already fixed)

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read the research artifact at `docs/reports/T-856-termlink-dispatch-context.md`
  2. Evaluate go/no-go criteria against findings
  3. Decide via Watchtower at http://192.168.10.107:3000/approvals
  **Expected:** Decision recorded
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- A framework-side fix exists that doesn't require TermLink binary changes
- The fix works for both `fw termlink dispatch` and manual `termlink spawn` workflows

**NO-GO if:**
- All viable fixes require TermLink binary changes (defer to T-682)
- The fix introduces fragile symlink or env var hacks that break on path changes

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

- **Recommendation:** NO-GO (already fixed by T-792)
- **Rationale:** The core issue (worker CWD resolution) was fixed by commit `305038d8` (T-792) which exports `PROJECT_ROOT` and `FRAMEWORK_ROOT` in the worker's `run.sh` before launching `claude -p`. All four assumptions were invalidated — no TermLink binary changes, no `--cwd` flag, no symlink hacks needed. The fix is simpler than any proposed approach.
- **Evidence:**
  - T-792 commit `305038d8` exports PROJECT_ROOT in `agents/termlink/termlink.sh:300-308`
  - `lib/paths.sh:33` respects pre-set PROJECT_ROOT
  - T-856 was created (18:23 UTC) before T-792 was committed (19:47 UTC)
  - Suggested action: close T-856 as superseded by T-792

## Decision

**Decision**: NO-GO

**Rationale**: - Recommendation: NO-GO (already fixed by T-792)
- Rationale: The core issue (worker CWD resolution) was fixed by commit `305038d8` (T-792) which exports `PROJECT_ROOT` and `FRAMEWORK_ROOT` in the worker's `run.sh` before launching `claude -p`. All four assumptions were invalidated — no TermLink binary changes, no `--cwd` flag, no symlink hacks needed. The fix is simpler than any proposed approach.
- Evidence:
  - T-792 commit `305038d8` exports PROJECT_ROOT in `agents/termlink/termlink.sh:300-308`
  - `lib/paths.sh:33` respects pre-set PROJECT_ROOT
  - T-856 was created (18:23 UTC) before T-792 was committed (19:47 UTC)
  - Suggested action: close T-856 as superseded by T-792

**Date**: 2026-04-13T11:27:34Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-05T12:01:03Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-06T22:23:16Z — status-update [task-update-agent]
- **Change:** horizon: now → later

### 2026-04-13T11:27:34Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** - Recommendation: NO-GO (already fixed by T-792)
- Rationale: The core issue (worker CWD resolution) was fixed by commit `305038d8` (T-792) which exports `PROJECT_ROOT` and `FRAMEWORK_ROOT` in the worker's `run.sh` before launching `claude -p`. All four assumptions were invalidated — no TermLink binary changes, no `--cwd` flag, no symlink hacks needed. The fix is simpler than any proposed approach.
- Evidence:
  - T-792 commit `305038d8` exports PROJECT_ROOT in `agents/termlink/termlink.sh:300-308`
  - `lib/paths.sh:33` respects pre-set PROJECT_ROOT
  - T-856 was created (18:23 UTC) before T-792 was committed (19:47 UTC)
  - Suggested action: close T-856 as superseded by T-792

### 2026-04-13T13:20:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)
- **Reason:** T-1226: Status fix for stuck inception

### 2026-04-13T13:20:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** T-1226: NO-GO decision recorded via Watchtower

## Reviewer Verdict (v1.5)

- **Scan ID:** R-59528e03
- **Timestamp:** 2026-06-02T15:05:16Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
