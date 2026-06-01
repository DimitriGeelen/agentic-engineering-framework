---
id: T-1313
name: "Pickup: Anti-pattern detected: umbrella inceptions bundling N independent decisions (T-1112 NO-GO) (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink, task T-1112. Type: pattern.

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [pickup, pattern]
components: []
related_tasks: []
created: 2026-04-18T20:23:38Z
last_update: 2026-04-22T11:14:12Z
date_finished: 2026-04-22T11:13:46Z
---

# T-1313: Pickup: Anti-pattern detected: umbrella inceptions bundling N independent decisions (T-1112 NO-GO) (from termlink)

## Problem Statement

Termlink (sourced from T-1112) reports a recurring anti-pattern: "umbrella inceptions" that bundle N independent decisions into a single go/no-go gate. Symptom: T-1112 went NO-GO because two of its three sub-questions were undecidable; the one tractable sub-question was lost. The framework already has a written rule against this — CLAUDE.md "Task Sizing Rules" line: "One inception = one question. Umbrella inceptions that bundle independent explorations create all-or-nothing decisions and coarse progress tracking."

**Research artifact:** `docs/reports/T-1313-umbrella-inception-anti-pattern.md`

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
- [x] Problem statement validated (rule already in CLAUDE.md "Task Sizing Rules")
- [x] Assumptions tested (no enforcement gate exists; rule is advisory)
- [x] Recommendation written with rationale (DEFER — codified, no enforcement appetite)

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** DEFER (already codified)

**Rationale:** The rule is already in CLAUDE.md ("One inception = one question. Umbrella inceptions that bundle independent explorations create all-or-nothing decisions and coarse progress tracking."). T-1112's NO-GO is exactly the failure mode the rule predicts. Adding a structural enforcement gate (e.g., "block decide if >N sub-questions detected in problem statement") is hard — what counts as a sub-question is a judgment call, not a regex. Better to let the existing rule + episodic evidence (T-1112 NO-GO) reinforce the discipline.

**Evidence:**
- CLAUDE.md "Task Sizing Rules" already names the anti-pattern
- T-1112 NO-GO is itself the evidence the rule is being enforced via human judgment at decide time
- Structural enforcement would require parsing problem statements for "and" / multiple questions — high false-positive risk
- Codification cost > benefit; leave as advisory

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

**Decision**: DEFER

**Rationale**: Recommendation: DEFER (already codified)

Rationale: The rule is already in CLAUDE.md ("One inception = one question. Umbrella inceptions that bundle independent explorations create all-or-nothing decisions and coarse progress tracking."). T-1112's NO-GO is exactly the failure mode the rule predicts. Adding a structural enforcement gate (e.g., "block decide if >N sub-questions detected in problem statement") is hard — what counts as a sub-question is a judgment call, not a regex. Better to let the existing rule + episodic evidence (T-1112 NO-GO) reinforce the discipline.

Evidence:
- CLAUDE.md "Task Sizing Rules" already names the anti-pattern
- T-1112 NO-GO is itself the evidence the rule is being enforced via human judgment at decide time
- Structural enforcement would require parsing problem statements for "and" / multiple questions — high false-positive risk
- Codification cost > benefit; leave as advisory

**Date**: 2026-04-18T22:48:31Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-18T21:04:56Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-18T22:48:31Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Recommendation: DEFER (already codified)

Rationale: The rule is already in CLAUDE.md ("One inception = one question. Umbrella inceptions that bundle independent explorations create all-or-nothing decisions and coarse progress tracking."). T-1112's NO-GO is exactly the failure mode the rule predicts. Adding a structural enforcement gate (e.g., "block decide if >N sub-questions detected in problem statement") is hard — what counts as a sub-question is a judgment call, not a regex. Better to let the existing rule + episodic evidence (T-1112 NO-GO) reinforce the discipline.

Evidence:
- CLAUDE.md "Task Sizing Rules" already names the anti-pattern
- T-1112 NO-GO is itself the evidence the rule is being enforced via human judgment at decide time
- Structural enforcement would require parsing problem statements for "and" / multiple questions — high false-positive risk
- Codification cost > benefit; leave as advisory

### 2026-04-22T11:13:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
