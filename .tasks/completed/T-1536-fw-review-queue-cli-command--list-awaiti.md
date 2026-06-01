---
id: T-1536
name: "fw review-queue CLI command — list awaiting-review tasks with verdicts"
description: >
  fw review-queue CLI command — list awaiting-review tasks with verdicts

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-27T10:52:55Z
last_update: 2026-04-27T11:00:30Z
date_finished: 2026-04-27T11:00:30Z
---

# T-1536: fw review-queue CLI command — list awaiting-review tasks with verdicts

## Context

CLI mirror of the Watchtower /approvals "Awaiting Human ACs" view. Lets the human triage from the terminal: `fw review-queue` lists tasks with verdict prefix, age, ID, and name — same data, no browser needed. Companion to the T-1530-T-1535 review-workflow arc.

## Acceptance Criteria

### Agent
- [x] `bin/fw review-queue` is wired and prints a tabular listing of all active tasks with at least one unchecked Human AC
- [x] Each row shows: verdict (`GO`/`DEFER`/`NO-GO`/`?`) + age (e.g. `12d`) + task ID + truncated name
- [x] Sort: GO first (rubber-stamp candidates), then DEFER, then NO-GO, then unknown; within each verdict, oldest first
- [x] `fw review-queue --help` shows usage
- [x] Tabular output contains at least 5 `GO` lines on the current host (matches /approvals state)
- [x] Trailing summary line shows total count (e.g. "42 task(s) awaiting human review")

## Verification

bin/fw review-queue --help 2>&1 | grep -qi review-queue
bin/fw review-queue 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -qE '^GO\b'
test $(bin/fw review-queue 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -cE '^GO\b') -ge 5
bin/fw review-queue 2>&1 | grep -qE 'task\(s\) awaiting human review'

## Recommendation

**Recommendation:** GO

**Rationale:** Closes the parity gap between Watchtower /approvals and the terminal — the human can now triage the awaiting-review queue without leaving the shell. Output is sorted GO-first to match the rubber-stamp-friendly ordering, with colour coding mirroring the web badges. Trailing summary: `42 task(s) awaiting human review (18 GO / 10 DEFER / 14 ?)` + Watchtower link.

**Evidence:**
- `bin/fw review-queue` lists 42 tasks: 18 GO, 10 DEFER, 14 unknown — matches /approvals state
- `--help` documents usage and sort order
- Discoverable via `fw help` (added to top-level command list)
- Inline fallback for `extract_recommendation_verdict` when running outside the framework repo (consumer projects without web/ on path)

## Decisions

### 2026-04-27 — top-level command vs subcommand of `fw approvals`
- **Chose:** Top-level `fw review-queue` (sibling to `fw approvals`)
- **Why:** `fw approvals` is bound to the Tier 0 approval queue (pending/status/expire). The Awaiting-Human-Review queue is a different concept (Human ACs on work-completed tasks). Cohabiting under `approvals` would muddy the namespace.
- **Rejected:** `fw approvals review-queue` — namespace dilution. `fw task review-queue` — the queue is bigger than per-task action and reads more naturally as a top-level verb.



## Updates

### 2026-04-27T10:52:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1536-fw-review-queue-cli-command--list-awaiti.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-9149f405
- **Timestamp:** 2026-04-27T11:00:31Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-04-27T11:00:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
