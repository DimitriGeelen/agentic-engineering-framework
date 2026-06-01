---
id: T-1397
name: "T-1268 B1: pending-updates registry (.context/working/pending-updates.yaml + fw pending register/list/resolve)"
description: >
  T-1268 B1: pending-updates registry (.context/working/pending-updates.yaml + fw pending register/list/resolve)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw, lib/pending.sh]
related_tasks: []
created: 2026-04-23T13:56:41Z
last_update: 2026-04-23T14:01:22Z
date_finished: 2026-04-23T14:01:22Z
---

# T-1397: T-1268 B1: pending-updates registry (.context/working/pending-updates.yaml + fw pending register/list/resolve)

## Context

First build unit after T-1268 GO decision (inception closed 2026-04-23T12:09:55Z,
partial-scope GO: B1+B4 registry + B5+B6 TermLink prebuild matrix).

This task ships ONLY B1 — the registry primitive. B2 (`fw doctor` integration),
B3 (Watchtower page), B4 (reminder cron) are follow-ons. B5+B6 are in a
different repo (/opt/termlink).

**What:** Append-only registry where an agent can record "I tried to do X but
was blocked by a gate or cross-project barrier — here is the copy-pasteable
command needed to complete it." Commands remain pending until resolved.

**Why:** Today, when a framework gate blocks an agent from completing an action
across projects or machines, the agent prints a command and moves on. There
is no ledger — the command is lost if the user doesn't act before session end,
and there is no instrumentation to measure resolution rate. See
`docs/reports/T-1268-cross-machine-update-friction.md` Spike A: 0 explicit
copy-pasteable markers in 30 handovers + bypass log.

**Not in this task:**
- `fw doctor` surfacing (B2)
- Watchtower UI (B3)
- Cron reminders (B4)

## Acceptance Criteria

### Agent
- [x] `lib/pending.sh` exists with `do_pending` dispatcher for `register`, `list`, `resolve`, `help`
- [x] `bin/fw pending` routes to `lib/pending.sh do_pending`
- [x] `fw pending register --command 'CMD' --reason 'WHY' --task T-XXX [--host HOST]` appends an entry to `.context/working/pending-updates.yaml` with auto-generated `U-NNN` id, status `pending`
- [x] `fw pending list` prints pending entries; `--status all` shows everything
- [x] `fw pending resolve U-NNN [--note 'outcome']` flips status to `resolved`, stamps `resolved_date`
- [x] File auto-creates on first write with a schema header
- [x] Registry entries are append-only (resolved entries kept, only flagged)
- [x] Unit test (`tests/unit/fw_pending.bats`) covers register → list → resolve happy path and list-filter
- [x] `bash -n lib/pending.sh` passes; `bats tests/unit/fw_pending.bats` passes (7/7)
- [x] CLAUDE.md Quick Reference gains `fw pending {register,list,resolve}` rows

## Verification

bash -n lib/pending.sh
bash -n bin/fw
test -f lib/pending.sh
grep -q 'pending)' bin/fw
grep -q 'do_pending' bin/fw
_t=$(mktemp); bats tests/unit/fw_pending.bats >"$_t" 2>&1; _r=$?; grep -q "^ok " "$_t" && [ "$_r" -eq 0 ] || { cat "$_t"; rm -f "$_t"; exit 1; }; rm -f "$_t"
grep -q "fw pending register" CLAUDE.md
grep -q "fw pending list" CLAUDE.md
grep -q "fw pending resolve" CLAUDE.md

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

### 2026-04-23T13:56:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1397-t-1268-b1-pending-updates-registry-conte.md
- **Context:** Initial task creation

### 2026-04-23T14:01:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
