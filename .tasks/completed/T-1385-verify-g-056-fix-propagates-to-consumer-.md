---
id: T-1385
name: "Verify G-056 fix propagates to consumer via fw upgrade dry-run on /003-NTB-ATC-Plugin + /opt/002-Claude-Partner-Network"
description: >
  Verify G-056 fix propagates to consumer via fw upgrade dry-run on /003-NTB-ATC-Plugin + /opt/002-Claude-Partner-Network

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-22T20:39:20Z
last_update: 2026-04-22T20:41:07Z
date_finished: 2026-04-22T20:41:07Z
---

# T-1385: Verify G-056 fix propagates to consumer via fw upgrade dry-run on /003-NTB-ATC-Plugin + /opt/002-Claude-Partner-Network

## Context

Verifies T-1383 / G-056 fix detects drift on actual consumer projects without modifying them. TermLink dispatch to dev-box agent (tl-bubfbc3w) was considered but the session has no pickup/data_plane capabilities — it is a stale registration. Verification via read-only `fw upgrade --dry-run` against each consumer instead.

## Acceptance Criteria

### Agent
- [x] `fw upgrade --dry-run /003-NTB-ATC-Plugin` reports `WOULD UPDATE resume.md (drift from template detected)` at step 7/10 (verified 2026-04-22T21:57Z)
- [x] `fw upgrade --dry-run /opt/002-Claude-Partner-Network` reports same drift at step 7/10 (verified 2026-04-22T21:57Z)
- [x] No consumer files modified (dry-run only — respects no-cross-repo-edits rule)
- [x] Future action noted: when each consumer agent re-launches, a non-dry `fw upgrade` will auto-refresh their resume.md with .bak preserved

## Verification

bin/fw upgrade --dry-run /003-NTB-ATC-Plugin >/tmp/t1385-ntb.out 2>&1 && grep -q 'WOULD UPDATE.*resume.md' /tmp/t1385-ntb.out
bin/fw upgrade --dry-run /opt/002-Claude-Partner-Network >/tmp/t1385-cpn.out 2>&1 && grep -q 'WOULD UPDATE.*resume.md' /tmp/t1385-cpn.out

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

### 2026-04-22T20:39:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1385-verify-g-056-fix-propagates-to-consumer-.md
- **Context:** Initial task creation

### 2026-04-22T20:41:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
