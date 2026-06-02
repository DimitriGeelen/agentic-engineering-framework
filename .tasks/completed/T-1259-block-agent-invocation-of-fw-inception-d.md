---
id: T-1259
name: "Block agent invocation of fw inception decide — enforce T-679 via CLAUDECODE env check"
description: >
  Block agent invocation of fw inception decide — enforce T-679 via CLAUDECODE env check

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-14T22:53:22Z
last_update: 2026-04-15T13:49:33Z
date_finished: 2026-04-15T13:49:33Z
---

# T-1259: Block agent invocation of fw inception decide — enforce T-679 via CLAUDECODE env check

## Context

CLAUDE.md §"Presenting Work for Human Review" (T-679) says: *"Agents MUST present
inception decisions via `fw task review T-XXX` (Watchtower URL/QR). NEVER give raw
CLI commands (`fw inception decide`, `fw task update --status work-completed --force`)
for human approvals."*

Agents keep violating this rule — most recently on `/003-NTB-ATC-Plugin` (T-1257
cross-session report). Relying on agent discipline has failed enough times to
warrant a structural guard.

This task adds a CLI-level block: `fw inception decide` detects agent context via
`$CLAUDECODE=1` and refuses, directing to `fw task review` instead. Human
invocation (no `$CLAUDECODE`) still works; explicit override via `--i-am-human`
flag available for edge cases (tests, scripts, rare legitimate agent cases).

## Acceptance Criteria

### Agent
- [x] `lib/inception.sh` `do_inception_decide` adds `$CLAUDECODE=1` detection + refusal (early gate, before other checks) — landed in commit 4589bc60
- [x] Refusal message references T-679 + suggests `fw task review T-XXX` instead (lib/inception.sh:204-217)
- [x] `--i-am-human` flag bypasses the block (lib/inception.sh:188 parser, line 204 condition)
- [x] `bats tests/unit/lib_inception.bats` adds 3 tests for blocked / bypassed / no-env (lib_inception.bats:127-153)
- [x] CLAUDE.md §"Presenting Work for Human Review" updated with structural enforcement note + T-1260 caveat about Watchtower regression
- [x] All 15 inception unit tests pass (also fixed setup() to unset CLAUDECODE for env-determinism — was breaking pre-existing tests 9-10)

**Note:** T-1260 Spike A identified that this guard regresses Watchtower-driven decide because Flask inherits `CLAUDECODE=1`. Fix tracked under T-1260 build B1-B3 (`--from-watchtower` exemption). T-1259's own contract is met; the Watchtower regression is queued separately.

## Verification

grep -q "CLAUDECODE" lib/inception.sh
grep -q "i-am-human\|i_am_human" lib/inception.sh
grep -q "T-1259\|CLAUDECODE" CLAUDE.md

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-14T22:53:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1259-block-agent-invocation-of-fw-inception-d.md
- **Context:** Initial task creation

### 2026-04-14T23:01:07Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-04-15T13:49:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
- **Reason:** Tests + CLAUDE.md done — closing

### 2026-04-15T13:49:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** All 6 Agent ACs met: guard implemented (lib/inception.sh:204), tests pass (15/15), CLAUDE.md updated, regression flagged to T-1260

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d299ce5f
- **Timestamp:** 2026-06-02T14:56:16Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#4 (Agent)** — `bats tests/unit/lib_inception.bats` adds 3 tests for blocked / bypassed / no-env (lib_inception.bats:127-153)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/unit/lib_inception.bats in: `bats tests/unit/lib_inception.bats` adds 3 tests for blocked / bypassed / no-env (lib_inception.bats:127-153)`
