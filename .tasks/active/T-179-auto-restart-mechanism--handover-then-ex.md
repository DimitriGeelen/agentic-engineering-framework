---
id: T-179
name: "Auto-restart mechanism — handover then exit then auto-resume"
description: >
  Investigate automatic session restart after handover so context recovery is seamless without human intervention. Approaches to explore: (1) Wrapper script around claude that monitors exit status file, (2) Shell trap that catches exit and runs claude --continue/--resume, (3) .context/working/.restart-requested flag set by budget gate before forcing exit, (4) fswatch/inotifywait monitoring the flag file, (5) Systemd user unit. Key questions: Can Claude Code exit cleanly from within a session? What does claude --continue vs --resume do? Can we pass initial commands (e.g., auto-run /resume)? What's the UX — does the user see a brief flash or seamless continuation? Relates to T-174 (Option B architecture), T-173 (budget gate handover fix), T-175 (stronger emergency handover).

status: captured
workflow_type: inception
owner: claude-code
horizon: next
tags: []
related_tasks: []
created: 2026-02-18T19:27:34Z
last_update: 2026-02-18T19:27:34Z
date_finished: null
---

# T-179: Auto-restart mechanism — handover then exit then auto-resume

## Problem Statement

With compaction disabled (T-174), sessions end when the budget gate forces handover at critical. The user must then manually run `claude -c` to start a new session. This breaks autonomous workflow. Can we make the transition seamless — handover completes, session ends, new session starts automatically with `fw resume`? Preliminary research in docs/reports/T-179-session-restart-mechanisms.md found: `claude -c` resumes most recent session, no native auto-restart exists, external tool `claude-auto-resume` exists on GitHub, flag-file approach (`.context/working/.session-ended` + wrapper script) is viable.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- [Criterion 1]
- [Criterion 2]

**NO-GO if:**
- [Criterion 1]
- [Criterion 2]

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
