---
id: T-1100
name: "Inception: reconcile two isolation patterns (vendored .agentic-framework dir vs project-detecting shim) (G-031)"
description: >
  Inception task — pick canonical isolation model (or document when to use each), then write migration path. Two patterns coexist: (a) old vendored plain .agentic-framework/ directory tracked in project git, visible in proxmox-ring20-management; (b) new project-detecting shim that routes via cwd, applied by fw upgrade step 4c, visible in ring20-dashboard. Both work, neither is documented as canonical. Decide: are they complementary (vendoring is a stronger pin layered on the shim), or is one deprecated? If deprecated, write migration. If complementary, document when to use each. Origin: G-031. Trigger: cross-session ring20-dashboard onboarding incident 2026-04-11 — both the consumer-project agent AND the recommending evaluator (this session) had wrong mental models about which is canonical.

status: captured
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-1093, T-1094, T-1099]
created: 2026-04-11T12:16:16Z
last_update: 2026-04-11T12:16:16Z
date_finished: null
---

# T-1100: Inception: reconcile two isolation patterns (vendored .agentic-framework dir vs project-detecting shim) (G-031)

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
