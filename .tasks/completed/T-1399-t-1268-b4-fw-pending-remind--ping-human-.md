---
id: T-1399
name: "T-1268 B4: fw pending remind — ping human for pending entries older than 24h"
description: >
  T-1268 B4: fw pending remind — ping human for pending entries older than 24h

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [lib/pending.sh]
related_tasks: []
created: 2026-04-23T14:06:44Z
last_update: '2026-06-11T22:23:47Z'
date_finished: 2026-04-23T14:09:47Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1399: T-1268 B4: fw pending remind — ping human for pending entries older than 24h

## Context

T-1268 B4. With B1 (T-1397) shipping the registry and B2 (T-1398) making
`fw doctor` surface unresolved entries, humans still only see unresolved
entries when they *run* `fw doctor`. B4 adds a proactive reminder:
`fw pending remind` detects entries older than N hours (default 24h) that
are still `pending` and fires an `fw_notify` summary, so long-ignored
entries get a push notification.

B4 ships the CLI + a cron registry entry (status: paused) — humans can
activate it via Watchtower if they want scheduled reminders. Not
auto-activated because cron spam is a per-project choice.

## Acceptance Criteria

### Agent
- [x] `fw pending remind` prints a summary of entries with `status=pending` older than `FW_PENDING_REMIND_STALE_HOURS` (default 24)
- [x] When 0 stale entries, `fw pending remind` prints a clean "No stale pending entries" message and exits 0 without firing a notification
- [x] When 1+ stale entries and `NTFY_ENABLED=true`, the command invokes `fw_notify` with count + first entry id + task
- [x] Cron registry entry `pending-remind-daily` exists in `.context/cron-registry.yaml` with `status: paused` (human opts in)
- [x] Unit test (`tests/unit/fw_pending_remind.bats`) covers: no file → 0 stale; fresh entries → 0 stale; aged entry (simulated) → reported; resolved entry → never reported
- [x] CLAUDE.md Quick Reference row for `fw pending remind`
- [x] `bash -n lib/pending.sh` passes
- [x] `bats tests/unit/fw_pending_remind.bats` passes (5/5)

## Verification

bash -n lib/pending.sh
grep -q 'do_pending_remind' lib/pending.sh
grep -q 'remind)' lib/pending.sh
_t=$(mktemp); bats tests/unit/fw_pending_remind.bats >"$_t" 2>&1; _r=$?; tail -5 "$_t"; grep -q "^ok " "$_t" && [ "$_r" -eq 0 ] || { cat "$_t"; rm -f "$_t"; exit 1; }; rm -f "$_t"
grep -q "pending-remind-daily" .context/cron-registry.yaml
grep -q "fw pending remind" CLAUDE.md

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

### 2026-04-23T14:06:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1399-t-1268-b4-fw-pending-remind--ping-human-.md
- **Context:** Initial task creation

### 2026-04-23T14:09:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cd751be3
- **Timestamp:** 2026-06-02T14:57:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -f`
