---
id: T-182
name: "Reframe handover from emergency panic to calm wrap-up"
description: >
  From sprechloop brief: framework-single-handover-design.md. The budget gate and checkpoint
  messages use emergency/panic language ("WILL be lost", "imminent", "exhaustion is sudden")
  but task files already capture all essential state. Reframe critical-level from emergency
  panic to calm wrap-up. Also decide three open questions: checkpoint mode, task freshness
  in fw doctor, auto-handover vs manual instruction at critical.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T21:35:33Z
last_update: 2026-02-18T21:35:33Z
date_finished: null
---

# T-182: Reframe handover from emergency panic to calm wrap-up

## Context

Brief: /opt/001-sprechloop/.context/briefs/framework-single-handover-design.md. Builds on T-175 (D-028) which already deprecated --emergency flag.

## Acceptance Criteria

- [x] CLAUDE.md critical protocol reframed — no emergency/panic language
- [x] budget-gate.sh critical messages reframed (both fast-path and slow-path)
- [x] checkpoint.sh critical message reframed, comment updated
- [x] checkpoint.sh call-based critical message reframed
- [x] lib/templates/claude-project.md updated to match CLAUDE.md
- [x] Three open questions decided and recorded in Decisions section

## Verification

# No "imminent" or "WILL be lost" in budget-gate.sh
grep -qv "imminent" agents/context/budget-gate.sh
grep -qv "WILL be lost" agents/context/budget-gate.sh
# No "imminent" in checkpoint.sh
grep -qv "imminent" agents/context/checkpoint.sh
# No "emergency" (case-insensitive) in CLAUDE.md critical section
grep -qvi "emergency" CLAUDE.md
# Calm framing present in budget-gate.sh
grep -q "SESSION WRAPPING UP" agents/context/budget-gate.sh
# Calm framing present in checkpoint.sh
grep -q "wrapping up" agents/context/checkpoint.sh

## Decisions

### 2026-02-18 — Checkpoint mode (--checkpoint)
- **Chose:** Keep as-is
- **Why:** Different purpose — lightweight mid-session snapshots that don't replace LATEST.md. Useful for mid-session recovery points.
- **Rejected:** Remove (still has value as lightweight snapshot for long sessions)

### 2026-02-18 — fw doctor task freshness check
- **Chose:** Not now (Option C from brief — status quo)
- **Why:** Brief's own recommendation: "empirical evidence from sprechloop shows task discipline holds without mechanical enforcement." Brief instruction says "Do NOT add mechanical task-freshness enforcement yet."
- **Rejected:** Commit-cadence check (Option A), time-based reminder (Option B) — unnecessary overhead given current discipline

### 2026-02-18 — Auto-handover at critical vs block + instruct
- **Chose:** Keep auto-handover
- **Why:** L-013/L-038 established that agents cannot be trusted to act on warnings. T-136 was built specifically because the agent ignored critical warnings. Auto-fire is structural enforcement.
- **Rejected:** Block-only + instruct (reverts to trusting agent discipline, which failed empirically)

## Updates

### 2026-02-18T21:35:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-182-reframe-handover-from-emergency-panic-to.md
- **Context:** Initial task creation
