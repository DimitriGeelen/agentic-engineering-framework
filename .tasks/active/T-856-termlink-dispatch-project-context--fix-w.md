---
id: T-856
name: "TermLink dispatch project context — fix worker CWD resolution so hooks find correct PROJECT_ROOT"
description: >
  Inception: TermLink dispatch project context — fix worker CWD resolution so hooks find correct PROJECT_ROOT

status: captured
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-04T18:23:31Z
last_update: 2026-04-04T18:23:31Z
date_finished: null
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
- [ ] Problem statement validated with reproduction evidence
- [ ] At least 2 approaches investigated
- [ ] Recommendation written with rationale

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

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
