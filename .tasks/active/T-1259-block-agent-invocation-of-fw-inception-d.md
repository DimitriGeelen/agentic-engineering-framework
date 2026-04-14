---
id: T-1259
name: "Block agent invocation of fw inception decide — enforce T-679 via CLAUDECODE env check"
description: >
  Block agent invocation of fw inception decide — enforce T-679 via CLAUDECODE env check

status: captured
workflow_type: build
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-04-14T22:53:22Z
last_update: 2026-04-14T23:01:07Z
date_finished: null
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
- [ ] `lib/inception.sh` `do_inception_decide` adds `$CLAUDECODE=1` detection + refusal (early gate, before other checks)
- [ ] Refusal message references T-679 + suggests `fw task review T-XXX` instead
- [ ] `--i-am-human` flag bypasses the block (for explicit human override if needed)
- [ ] `bats tests/unit/lib_inception.bats` adds test: with CLAUDECODE=1 no flag → exit non-zero with clear message; with CLAUDECODE=1 --i-am-human → passes gate; without CLAUDECODE → passes gate
- [ ] CLAUDE.md §"Presenting Work for Human Review" updated to note the new enforcement
- [ ] All existing tests still pass (`fw test unit`)

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
