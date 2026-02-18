---
id: T-182
name: "Reframe handover messaging from emergency panic to calm wrap-up"
description: >
  From sprechloop brief: /opt/001-sprechloop/.context/briefs/framework-single-handover-design.md.
  Task system captures all essential state continuously. Handover is a navigation aid, not a
  safety net. Reframe critical-level messages from panic ("WILL be lost", "imminent", "exhaustion")
  to calm wrap-up ("session wrapping up", "task files already have all essential state").
  String/comment changes only — zero logic changes. 4 files affected.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T21:45:43Z
last_update: 2026-02-18T21:45:43Z
date_finished: null
---

# T-182: Reframe handover messaging from emergency panic to calm wrap-up

## Context

Brief: /opt/001-sprechloop/.context/briefs/framework-single-handover-design.md. Builds on T-175 (D-028). Impact assessment completed — string/comment changes only across 4 files, zero logic changes.

## Impact Assessment

| File | Lines | Change | Risk |
|------|-------|--------|------|
| budget-gate.sh | 123,127,226-230 | "BUDGET GATE — Context Critical" + "WILL be lost" → "SESSION WRAPPING UP" + "task files have all essential state" | Low (display strings) |
| checkpoint.sh | 102-103,107,182 | "CRITICAL" + "Compaction imminent" → "Session wrapping up" + calm framing; comment update | Low (display strings + comment) |
| CLAUDE.md | 448-452 | Critical Protocol: replace panic framing with brief's proposed text | Medium (loaded every session) |
| lib/templates/claude-project.md | 448-452 | Mirror CLAUDE.md | Low (template) |

**NOT changed:** No logic, no thresholds, no behavioral changes. Historical files untouched.

## Acceptance Criteria

- [ ] budget-gate.sh: no "imminent" or "WILL be lost" in critical messages (both paths)
- [ ] checkpoint.sh: no "imminent" in critical message, no "emergency" in comment
- [ ] CLAUDE.md: Critical Protocol reframed with calm wrap-up language
- [ ] lib/templates/claude-project.md: mirrors CLAUDE.md
- [ ] No emergency/panic language in any of the 4 files
- [ ] Three open questions from brief decided

## Verification

grep -qv "imminent" agents/context/budget-gate.sh
grep -qv "WILL be lost" agents/context/budget-gate.sh
grep -qv "imminent" agents/context/checkpoint.sh
grep -qvi "emergency" CLAUDE.md
grep -q "SESSION WRAPPING UP" agents/context/budget-gate.sh
grep -q "wrapping up" agents/context/checkpoint.sh

## Decisions

### 2026-02-18 — Checkpoint mode (--checkpoint)
- **Chose:** Keep as-is
- **Why:** Different purpose (mid-session snapshots, doesn't replace LATEST.md). Not emergency-related.
- **Rejected:** Remove (still has value for long sessions)

### 2026-02-18 — fw doctor task freshness check
- **Chose:** Not now (Option C — status quo)
- **Why:** Brief recommends: "empirical evidence shows task discipline holds without mechanical enforcement." Brief instruction: "Do NOT add mechanical task-freshness enforcement yet."
- **Rejected:** Commit-cadence check (Option A), time-based reminder (Option B)

### 2026-02-18 — Auto-handover at critical vs block + instruct
- **Chose:** Keep auto-handover
- **Why:** L-013/L-038: agents cannot be trusted to act on warnings. T-136 built specifically because agent ignored critical warnings.
- **Rejected:** Block-only + instruct (reverts to trusting agent discipline, which failed empirically)

## Updates

### 2026-02-18T21:45:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-182-reframe-handover-messaging-from-emergenc.md
- **Context:** Initial task creation
