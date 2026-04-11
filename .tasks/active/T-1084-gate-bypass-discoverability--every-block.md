---
id: T-1084
name: "Gate bypass discoverability — every block message must name its bypass"
description: >
  Inception: Gate bypass discoverability — every block message must name its bypass

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-11T09:03:48Z
last_update: 2026-04-11T09:04:59Z
date_finished: null
---

# T-1084: Gate bypass discoverability — every block message must name its bypass

## Problem Statement

When a framework gate blocks an agent action, its error message often does NOT print the exact bypass command. The agent then guesses (often wrong), the user runs the wrong command, gets a confusing error, and the cycle repeats. Observed in T-908 session (/opt/termlink): agent suggested `fw tier0 approve` for an inception commit-msg block; real bypass was `git commit --no-verify`.

**Research artifact:** `docs/reports/T-1084-gate-bypass-discoverability.md`

## Assumptions

- A1: 3+ gates currently lack bypass-command-in-error-output
- A2: Adding the bypass command to error output is mechanical (no infra redesign)
- A3: Copy-pasteable commands (T-609 rule) satisfy the user requirement

## Exploration Plan

1. Audit each of the 10 identified gates: run it in a controlled test, capture block message, assess bypass clarity (0/5/10 min each)
2. Identify gaps (which gates print nothing, which print wrong thing, which are good examples)
3. Design standard error template
4. Scope the fix (LOC per gate)
5. Go/no-go decision

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

### 2026-04-11T09:04:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
