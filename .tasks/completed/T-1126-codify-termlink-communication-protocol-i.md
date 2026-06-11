---
id: T-1126
name: "Codify TermLink communication protocol: inject for interactive, push for async
  — structural enforcement"
description: >
  Inception: Codify TermLink communication protocol: inject for interactive, push
  for async — structural enforcement

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-12T08:21:39Z
last_update: '2026-06-11T22:23:40Z'
date_finished: 2026-04-12T08:39:59Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:40Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1126: Codify TermLink communication protocol: inject for interactive, push for async — structural enforcement

## Problem Statement

Agents default to `termlink remote push` for ALL cross-agent communication.
Push drops files in `/tmp/termlink-inbox/` — async, fire-and-forget. When
the communication requires a response (questions, resend requests, feedback),
push produces zero response because the receiving agent only processes inbox
on cron or when prompted.

**Live evidence (S-2026-0412-0935):** This session sent 2 push messages to
ring20-manager on .109 — observations on U-001/U-002 with 6 questions.
Zero response. Switched to `termlink remote inject` — ring20-manager
processed immediately and resent 3 files within seconds.

**The pattern:**
| Need | Tool | Why |
|------|------|-----|
| Deliver files/pickups (no response needed) | `push` | Async inbox, processed on schedule |
| Ask questions, request actions, get feedback | `inject` | Direct PTY input, agent processes immediately |
| Execute a command on remote session | `exec` | Structured output, synchronous |

**For whom:** Every agent using TermLink for cross-machine coordination.
**Why now:** This pattern was discovered empirically today. Without
codification, agents will keep defaulting to push and getting silence.

## Assumptions

- A1: `push` is genuinely async — receiving agent doesn't see it until prompted (CONFIRMED)
- A2: `inject` is processed as immediate user input (CONFIRMED — 3 files resent in seconds)
- A3: The distinction can be codified in CLAUDE.md §TermLink Integration (likely true)
- A4: A PostToolUse scanner could detect push-for-interactive anti-pattern (needs investigation)

## Exploration Plan

1. **Document the protocol** in CLAUDE.md §TermLink Integration — push vs inject decision matrix
2. **Add to fw termlink dispatch** — when `--interactive` flag is used, use inject not push
3. **Consider structural enforcement** — PostToolUse scanner that warns when `termlink remote push`
   is used in a pattern that looks interactive (e.g., message contains "?", "please respond")
4. **Error escalation** — register as Level D improvement (change ways of working)

## Scope Fence

**IN:** CLAUDE.md rule, fw termlink wrapper improvement, possible scanner.
**OUT:** Changes to TermLink binary itself (that's upstream).

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Live evidence confirms push-for-interactive fails and inject succeeds (CONFIRMED this session)
- The protocol can be expressed as a simple decision matrix (CONFIRMED — 4-row table)
- Codification fits in CLAUDE.md without architectural changes

**NO-GO if:**
- The distinction is too context-dependent to express as a rule
- TermLink upstream changes make push interactive (rendering the rule obsolete)

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

**Decision**: GO

**Rationale**: Live evidence: 2 push attempts got zero response, 1 inject got immediate response. Fix is      
  CLAUDE.md rule, no arch changes, immediate cross-network impact.

**Date**: 2026-04-12T08:39:59Z
## Decision

**Decision**: GO

**Rationale**: Live evidence: 2 push attempts got zero response, 1 inject got immediate response. Fix is      
  CLAUDE.md rule, no arch changes, immediate cross-network impact.

**Date**: 2026-04-12T08:39:59Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-12T08:21:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T08:39:59Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Live evidence: 2 push attempts got zero response, 1 inject got immediate response. Fix is      
  CLAUDE.md rule, no arch changes, immediate cross-network impact.

### 2026-04-12T08:39:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-12T09:27:16Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3288a1b0
- **Timestamp:** 2026-06-02T14:55:20Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
