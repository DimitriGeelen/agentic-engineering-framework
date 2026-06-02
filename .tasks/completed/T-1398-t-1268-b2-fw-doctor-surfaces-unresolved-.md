---
id: T-1398
name: "T-1268 B2: fw doctor surfaces unresolved pending-updates entries"
description: >
  T-1268 B2: fw doctor surfaces unresolved pending-updates entries

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw]
related_tasks: []
created: 2026-04-23T14:02:50Z
last_update: 2026-04-23T14:05:15Z
date_finished: 2026-04-23T14:05:15Z
---

# T-1398: T-1268 B2: fw doctor surfaces unresolved pending-updates entries

## Context

T-1268 B2. B1 (T-1397) shipped the `fw pending` registry at
`.context/working/pending-updates.yaml`. Without surfacing, the registry
is invisible — an agent registers a blocked action, session ends, nothing
pings the human. B2 makes `fw doctor` count unresolved entries and emit
a WARN with "Run: fw pending list" pointer.

## Acceptance Criteria

### Agent
- [x] `fw doctor` reports nothing when pending-updates.yaml is absent (no-op, no warning)
- [x] `fw doctor` reports nothing when all entries are resolved (clean registry, no warning)
- [x] `fw doctor` emits a WARN with the count and "Run: fw pending list" when there are 1+ unresolved entries
- [x] `fw doctor` warning increments the overall warnings counter (so summary "warnings" reflects pending entries)
- [x] Smoke test via bats (`tests/unit/fw_doctor_pending.bats`): register → run doctor → see warning → resolve → run doctor → no warning
- [x] `bash -n bin/fw` passes
- [x] `bats tests/unit/fw_doctor_pending.bats` passes (3/3)

## Verification

bash -n bin/fw
grep -q 'Pending-updates registry' bin/fw
grep -q 'pending_updates' bin/fw
_t=$(mktemp); bats tests/unit/fw_doctor_pending.bats >"$_t" 2>&1; _r=$?; tail -5 "$_t"; grep -q "^ok " "$_t" && [ "$_r" -eq 0 ] || { cat "$_t"; rm -f "$_t"; exit 1; }; rm -f "$_t"

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

### 2026-04-23T14:02:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1398-t-1268-b2-fw-doctor-surfaces-unresolved-.md
- **Context:** Initial task creation

### 2026-04-23T14:05:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cea2dde6
- **Timestamp:** 2026-06-02T14:57:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -f`
