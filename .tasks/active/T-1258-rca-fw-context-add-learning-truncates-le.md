---
id: T-1258
name: "RCA: fw context add-learning truncates learnings.yaml (recurrence 3+ in one week)"
description: >
  RCA: fw context add-learning truncates learnings.yaml (recurrence 3+ in one week)

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-14T22:05:42Z
last_update: 2026-04-15T15:33:52Z
date_finished: null
---

# T-1258: RCA: fw context add-learning truncates learnings.yaml (recurrence 3+ in one week)

## Problem Statement

`.context/project/learnings.yaml` has been truncated from ~1688 lines (240+ entries) down to 17-24 lines on four separate commits in April 2026. Each truncation required manual restoration from git history (T-1242, T-1254, T-1257). The task name assumes `fw context add-learning` is the culprit, but root cause investigation shows it's a different write path — `add-learning` itself uses safe awk-passthrough.

## Assumptions

- A1: `add-learning` (learning.sh) is NOT the truncation mechanism (appends via awk) — CONFIRMED
- A2: The truncation happens at write-time, not commit-time (existing shrinkage guard is WARN-only) — CONFIRMED
- A3: The same operator is responsible in all four recurrences (agents during task-completion commits) — CONFIRMED by pattern
- A4: A structural PreToolUse hook can prevent recurrence (T-1115/T-1117 pattern)

## Exploration Plan

All spikes executed 2026-04-15 via direct investigation:
- Spike A: Trace add-learning code path (ruled out as cause)
- Spike B: Audit all writers to learnings.yaml across codebase (only consolidate.py, doesn't match schema)
- Spike C: Analyze truncation commit shapes (matches "fresh file rewrite" hypothesis)
- Spike D: Identify which agent action produces the observed output (Write/Edit tool bypass)
- Spike E: Check existing guards (commit-msg hook is WARN-only, advisory)

## Scope Fence

**IN:** RCA root cause, four-layer structural fix proposal (B1-B7), build decomposition, interim workaround
**OUT:** Actual fix (post-GO build tasks), auto-recovery mechanism, migration of other YAML files (B1 covers them as a family)

## Acceptance Criteria

### Agent
- [x] Root cause identified: agents using Write/Edit tool directly on learnings.yaml, bypassing `fw context add-learning`
- [x] Evidence documented for 4 truncation commits + restoration cycle
- [x] Ruled-out mechanisms documented (add-learning, consolidate.py, audit, scanner, harvest)
- [x] Four-layer structural fix proposed with LOC estimates and priority tags
- [x] Research artifact written to `docs/reports/T-1258-add-learning-truncation-rca.md`
- [x] Recommendation section complete (GO)

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-1258` (opens Watchtower with recommendation + research artifact link)
  2. Review the Recommendation section and evidence
  3. Record decision via Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, reversible

**NO-GO if:**
- Problem requires fundamental redesign
- Fix cost exceeds benefit given current evidence

## Verification

# For inception tasks, verification is not needed (decisions, not code).

## Recommendation

**Recommendation:** DEFER (was GO — downgraded after live reproduction)

**Update 2026-04-15T19:15Z:** Original RCA (Write/Edit tool bypass) was WRONG. The truncation was reproduced live during this session's T-1262 completion flow — NOT via Write/Edit tool. The proposed B1-B7 fix would have added defence in depth but would NOT have prevented the actual truncation. Recommendation DEFERRED pending proper spike of update-task.sh lines 790-855 (auto-capture decisions, generate-episodic, fabric-enrich, bugfix-learning check). See corrected Updates section and next-session action.

**Original (incorrect) rationale retained below for history:**

**Rationale:** Fourth recurrence confirms the existing WARN-only guard is insufficient. Root cause identified: agents using Write tool directly on learnings.yaml instead of `fw context add-learning`. The write-time PreToolUse hook (B1) closes the gap structurally — agents cannot accidentally overwrite the file; they receive an immediate redirect to the correct command. Same structural pattern as T-1115/T-1117 (block TodoWrite et al.) — proven to work. Layered with commit-msg BLOCK (B3) and invariant test (B4), recurrence is prevented by construction rather than by warning.

**Evidence:**
- `git log --oneline -- .context/project/learnings.yaml | head -15` shows 4 truncation/restore cycles in 10 days
- `agents/context/lib/learning.sh do_add_learning` confirmed correct (awk passthrough preserves entries)
- `.git/hooks/commit-msg:151-172` confirmed WARN-only: `exit 0` after warning message
- `agents/context/consolidate.py:351` is the only other writer, uses sort_keys=False (not matching observed schema)
- `lib/init.sh:294` matches the regenerated L-001 default text "First learning" exactly — confirming the FRESH file hypothesis
- Truncation shape (L-001 with today's date + new L-002) matches "Write tool overwrite, then add-learning appends" — NOT any single code path
- Comprehensive codebase grep found no other production writer producing this schema

**Research artifact:** `docs/reports/T-1258-add-learning-truncation-rca.md` (full investigation trail + B1-B7 build decomposition).

**Interim workaround (until B1-B3 ship):**
> When capturing learnings, ONLY use `fw context add-learning "text" --task T-XXX --source P-001`. NEVER use Write/Edit tools on `.context/project/learnings.yaml` (or patterns.yaml, practices.yaml, decisions.yaml, gaps.yaml).

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

### 2026-04-14T22:05:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1258-rca-fw-context-add-learning-truncates-le.md
- **Context:** Initial task creation

### 2026-04-15T15:31:24Z — status-update [task-update-agent]
- **Change:** workflow_type: build → inception
- **Reason:** RCA task — inception is the correct workflow type per T-1115/T-1117 pattern

### 2026-04-15T19:15:00Z — RCA CORRECTION — reproduced bug live

Previous RCA was WRONG. Root cause is NOT agents using Write/Edit tool.
Reproduced the truncation in real time during this session:

1. Committed T-1262 at 676136a2 (learnings.yaml: 241 entries intact)
2. Ran `bin/fw task update T-1262 --status work-completed`
3. Flow triggered: auto-capture decisions, generate-episodic, fabric refresh
4. After flow completed, learnings.yaml was at 1 entry (L-001, regenerated with today's date)
5. Subsequent `fw fix-learned T-1262` added L-002 on top of the truncation

The completion flow (update-task.sh lines 790-855) is the culprit, NOT any
Write/Edit tool call. Something in:
- `auto-capture decisions from task file` (calls `add-decision` — uses awk, should be safe)
- `generate-episodic` (calls `context.sh generate-episodic` → `lib/episodic.sh`)
- `fabric-enrich` (via fabric.sh)

...rewrites learnings.yaml with just L-001.

Supporting evidence:
- decisions.yaml was ALSO modified: D-001 date updated from 2026-04-13 to 2026-04-15, D-002 appended
- Same "first entry date updated" pattern on both files
- decisions.yaml preserved remaining entries; learnings.yaml did not (because decisions.yaml only had 1 entry, so no loss to measure)

**NEXT-SESSION ACTION:** spike the completion flow (update-task.sh lines 790-855) with strace or by disabling each handler one at a time to identify the truncation line. The B1-B7 structural fix (PreToolUse hook) may still help as defence in depth, but the PRIMARY fix is elsewhere.

Learnings.yaml has been RESTORED (git checkout HEAD) and L-242 added via add-learning. Commit to follow.
