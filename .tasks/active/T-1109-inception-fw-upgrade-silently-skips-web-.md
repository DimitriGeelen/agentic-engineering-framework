---
id: T-1109
name: "Inception: fw upgrade silently skips web/ sync — consumer terminal + blueprints missing despite include list"
description: >
  RCA inception. Live evidence 2026-04-11: /opt/025-WokrshopDesigner ran fw upgrade today (last_upgrade 2026-04-11T10:50:34Z, .framework.yaml says version 1.5.246) but the vendored .agentic-framework/VERSION file still says 1.1.16, and web/blueprints/terminal.py is missing. 4 of 5 inspected consumer projects (025, 051, 050, openclaw) have the same failure. lib/update.sh:183-192 includes 'web' in the rsync list, so theoretically web/blueprints/terminal.py should have been copied. Yet the consumer has no terminal.py and its Watchtower on :3001 returns 404 on /terminal. Two contradictory signals: (a) upgrade reports success + updates the yaml + writes last_upgrade timestamp; (b) actual vendored files are stale. TWO separate but possibly related issues: (1) WHY does fw upgrade claim success without syncing web/ (matches G-024 but code looks correct) — possible causes: alternate code path, rsync error silenced, nested .agentic-framework (Pattern 6 from T-1100), source tmpdir pointing at wrong version, dry-run flag stuck; (2) WHY does .framework.yaml/VERSION file drift — two different writers, two different reads. Investigate: (i) trace every upgrade code path in bin/fw + lib/upgrade.sh + lib/update.sh + lib/init.sh + any agents/upgrade/*; (ii) reproduce on a throwaway consumer; (iii) identify the chokepoint where upgrade sync SHOULD converge; (iv) design invariant test that fails CI if any file in upstream web/ is missing from a consumer's vendored web/ after upgrade; (v) recommend structural fix with validation plan. Per T-1105 chokepoint+test discipline. Related: G-024, T-1094 (fw upgrade docs), T-1100 (5 isolation patterns including Pattern 6 nested), T-1106 (Bug 2 PID path — another consumer-vs-framework path inconsistency). Deliverable: docs/reports/T-NNNN-web-sync-rca.md with code-path trace, reproduction, structural fix design, invariant test design, validation plan.

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-11T20:12:21Z
last_update: 2026-04-11T20:12:27Z
date_finished: null
---

# T-1109: Inception: fw upgrade silently skips web/ sync — consumer terminal + blueprints missing despite include list

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

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

### Agent
- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- [Criterion 1]
- [Criterion 2]

**NO-GO if:**
- [Criterion 1]
- [Criterion 2]

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Watchtower reads this section — if it's empty, the human sees nothing.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence from exploration)
     **Evidence:**
     - Finding 1
     - Finding 2
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

### 2026-04-11T20:12:27Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Reason:** Dispatching RCA worker for fw upgrade sync failure
