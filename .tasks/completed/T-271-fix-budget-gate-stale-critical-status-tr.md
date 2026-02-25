---
id: T-271
name: "Fix budget-gate stale critical status trap"
description: >
  Budget-gate.sh line 104 has a stale-critical trap: when .budget-status says critical, the fast path ALWAYS intercepts regardless of age, so the slow path (which re-reads the actual transcript) never runs. After compaction or new session, the old critical status persists forever. Fix: when status is stale AND critical, force slow path re-read instead of blindly blocking.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [bugfix, budget, enforcement]
components: [C-007]
related_tasks: [T-138, T-139, T-228]
created: 2026-02-25T06:34:08Z
last_update: 2026-02-25T20:36:17Z
date_finished: 2026-02-25T20:36:17Z
---

# T-271: Fix budget-gate stale critical status trap

## Context

Budget-gate.sh Bug 3 fix (stale critical still blocks) created a trap: once .budget-status reaches critical, the fast path always intercepts regardless of age, so the slow path (which re-reads actual transcript tokens) never runs. After compaction or new session, the stale critical persists forever, blocking all work. Ref: T-228 enforcement bypass analysis, L-014 (stale caching danger).

## Acceptance Criteria

### Agent
- [x] Fast path only uses cached status when fresh (< STATUS_MAX_AGE)
- [x] Stale critical triggers FORCE_RECHECK=1 (falls through to slow path)
- [x] Slow path bypasses every-Nth-call skip when FORCE_RECHECK=1
- [x] Slow path re-reads actual transcript and corrects stale status
- [x] Fresh critical still blocks as before (no regression)

## Verification

# Fast path condition no longer includes || critical
grep -q 'if \[ "${STATUS_AGE}" -lt "$STATUS_MAX_AGE" \]; then' agents/context/budget-gate.sh
# FORCE_RECHECK variable exists
grep -q 'FORCE_RECHECK=1' agents/context/budget-gate.sh
# Slow path skip respects FORCE_RECHECK
grep -q 'FORCE_RECHECK' agents/context/budget-gate.sh
# Script still has critical blocking logic
grep -q 'exit 2' agents/context/budget-gate.sh
# Script parses without syntax errors
bash -n agents/context/budget-gate.sh

## Decisions

### 2026-02-25 — Stale critical handling
- **Chose:** Force slow path re-read when stale critical detected (FORCE_RECHECK flag)
- **Why:** Preserves fresh critical blocking (no regression) while allowing stale critical to be re-validated from actual transcript
- **Rejected:** Removing Bug 3 fix entirely (would let stale critical be bypassed during 90s window); adding session ID tracking (more complex, not needed)

## Updates

### 2026-02-25T06:34:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-271-fix-budget-gate-stale-critical-status-tr.md
- **Context:** Initial task creation

### 2026-02-25T20:36:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
