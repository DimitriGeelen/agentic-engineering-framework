---
id: T-1444
name: "Structural bugfix — malformed task YAML frontmatter + Watchtower 500-on-auto-trigger-failure (affects vendored installs)"
description: |
  Two coupled symptoms surfaced during T-1442 GO decision (2026-04-25T07:22Z):

  Symptom A (UX): Watchtower POST /inception/T-XXX/decide returns HTTP 500 even when primary fw inception decide succeeded (status moved, ACs ticked, file moved to completed/). Cause - downstream Auto-trigger Episodic Generation choked on Symptom B and the endpoint failed-loud instead of returning 200 with a degraded-state warning. User sees red error toast despite decision having landed.

  Symptom B (data): T-1278 + T-1279 in .tasks/active/ have malformed YAML frontmatter — flow-style components followed by block-style continuation lines. Both already have status work-completed but are stuck in active/ — likely update-task.sh mv path also choked on the parse error. Affects vendored installations because agents/task-create/create-task.sh and update-task.sh propagate to consumer projects.

  Root-cause hypothesis: somewhere in create-task.sh or update-task.sh, components + a related list field are appended in incompatible YAML styles (flow start, block continuation). Need to find the call site, fix the formatter, and clean up the two stuck tasks. Also need to harden the Watchtower decide endpoint to not 500 on side-effect failures.

  Inception scope: investigate root cause across both symptoms; decide whether one fix or two; estimate vendored-install blast radius; produce GO/NO-GO/DEFER with recommendation.

status: captured
workflow_type: inception
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-04-25T07:29:35Z
last_update: 2026-04-25T07:29:35Z
date_finished: null
---

# T-1444: Structural bugfix — malformed task YAML frontmatter + Watchtower 500-on-auto-trigger-failure (affects vendored installs)

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
