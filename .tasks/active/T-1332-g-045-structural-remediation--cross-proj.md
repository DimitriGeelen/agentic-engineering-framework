---
id: T-1332
name: "G-045 structural remediation — cross-project pickup for fleet-rotation secret distribution UX"
description: >
  Inception: G-045 structural remediation — cross-project pickup for fleet-rotation secret distribution UX

status: captured
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-19T13:02:24Z
last_update: 2026-04-19T13:02:24Z
date_finished: null
---

# T-1332: G-045 structural remediation — cross-project pickup for fleet-rotation secret distribution UX

## Problem Statement

When a TermLink hub rotates its shared secret (G-045 class), every agent pointing at that hub loses auth simultaneously and manual out-of-band relay of the new 64-hex becomes the only unblock. Today's session needed 3 cross-agent round-trips to recover two agents (framework-agent @ .201 and 050-email-archive @ .107) from a single .122 hub reboot. The same pattern has recurred for .121/.122 co-rotation. Systemic cost: multi-agent coordination stalls, context is burned, L-018 was miswritten and had to be retracted mid-incident.

Question: **is it worth proposing (via cross-project TermLink pickup) a structural remediation for the fleet-rotation UX, or accept manual relay as cost-of-doing-business?**

## Assumptions

1. Auto-distribution of rotated secrets is possible via some channel (SSH, hub-signed broadcast, or shared secret store) — UNTESTED
2. Agents on the fleet would accept a shared-secret mechanism — UNTESTED
3. The pain is recurring enough to justify structural work (vs 2-3× per year one-off manual relay) — PARTIALLY EVIDENCED (G-045 has triggered twice this week)
4. No existing TermLink roadmap item already addresses this — UNTESTED (check termlink repo)

## Exploration Plan

- **A** (10m): Grep TermLink repo + docs for "rotate", "secret", "key-exchange" — see if roadmap already covers
- **B** (10m): Estimate frequency of G-045-class events in concerns.yaml history — is this 2×/year or 2×/month?
- **C** (5m): Draft the pickup envelope — if we propose, what exactly are we proposing?

## Technical Constraints

- TermLink is a shared cross-project tool (installed machine-wide via Homebrew/cargo) — any structural change lands in their repo, not ours
- Hub auth is shared-secret HMAC today; any redesign touches security-critical code
- Fleet has heterogeneous OS (Linux + macOS) — fix must work on both

## Scope Fence

**IN:** decide whether to send a cross-project TermLink pickup proposing a G-045-class remediation.
**OUT:** implementing the remediation (that's TermLink's call if they accept); broader identity/zero-trust redesign.

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
