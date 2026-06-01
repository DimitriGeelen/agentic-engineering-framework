---
id: T-608
name: "Frictionless Tier 0 human confirmation — prove human acted without terminal switching"
description: >
  Current Tier 0 flow: hook blocks agent → human switches terminal → cd to project → paste command.
  Maximum friction for minimum governance value. Need: in-band confirmation that provably came from
  a human, not the agent. Explore: Claude Code permission prompts, challenge-response, Watchtower
  web UI approval button, TermLink out-of-band channel. Hard constraint: agent must not be able to
  bypass or fake the confirmation. Related: T-557 (inception decide gate), T-559 (boundary gate).

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: [bin/fw, web/templates/task_detail.html]
related_tasks: []
created: 2026-03-25T15:26:08Z
last_update: 2026-04-13T13:21:35Z
date_finished: 2026-04-13T13:21:35Z
---

# T-608: Frictionless Tier 0 human confirmation — prove human acted without terminal switching

## Problem Statement

Tier 0 gates (destructive commands, inception decisions) require human authority. Current flow forces the human to switch terminals, cd to the project, and paste a command. This is maximum friction for a governance action that should be a single keypress. The challenge: prove the confirmation came from a human, not the agent faking it.

## Assumptions

- A1: Claude Code's tool permission prompt (Allow/Deny) is human-initiated but can be set to "always allow"
- A2: Hooks in Claude Code are non-interactive (can't read stdin)
- A3: The agent can read any file the framework writes (no file-based secrets)
- A4: An out-of-band channel (Watchtower web UI, TermLink) could provide unfakeable confirmation

## Exploration Plan

1. **Spike 1: Claude Code hook capabilities** — Can a PreToolUse hook present an interactive prompt? What control does the hook have over the approval flow? (1hr)
2. **Spike 2: Watchtower approval surface** — LEADING APPROACH (human direction). Expand existing Human AC display into interactive approval cards. Details below. (2hr)
3. **Spike 3: Challenge-response with timing** — Hook generates challenge, human types response in Claude Code chat. Can the agent read and replay it? What prevents this? (1hr)
4. **Spike 4: TermLink approval channel** — Separate TermLink session that only the human can interact with. Agent sends request, human approves in another terminal. (1hr)

### Spike 2 Detail: Watchtower Approval Surface (human-directed)

**Concept:** Watchtower already shows Human ACs in task detail views. Expand this into a full interactive approval interface:

**UI components:**
- Each Human AC becomes an expandable card with: approve/reject buttons, feedback text area, status badge
- Tier 0 pending approvals appear as a prominent notification/queue
- Mobile-responsive — approve from phone while agent works on desktop

**Data flow:**
1. Agent hits Tier 0 gate → writes pending approval to `.context/approvals/T-XXX.yaml`
2. Watchtower shows pending approval prominently (badge, notification)
3. Human clicks approve/reject + optional feedback in browser
4. Watchtower writes response to approval ledger via API endpoint
5. Agent pickup: cron scans approval ledger every 30s, OR agent checks `fw approvals pending`

**Unfakeability guarantee:** Agent can READ `.context/approvals/` but cannot POST to Watchtower's HTTP endpoints (the web server writes the files, not the agent). The approval ledger becomes a write-once surface that only the web UI can modify.

**Scope expansion — also solves Human AC backlog:**
- 26 tasks with unchecked Human ACs could all be processed through Watchtower
- Each AC gets approve + feedback, agent picks up responses
- Eliminates the "come back to Claude and tell me you verified it" friction

**Pickup mechanism options:**
- A: Human types "check approvals" in Claude Code prompt
- B: Cron job scans `.context/approvals/` every 30s, writes to inbox
- C: PostToolUse hook checks for new approvals periodically
- Option B preferred — zero friction for both human and agent

## Technical Constraints

- Claude Code hooks run as shell commands, stdout/stderr shown to user, non-interactive
- Agent can read all files in PROJECT_ROOT and /tmp
- Agent can execute any Bash command the user allows
- The confirmation mechanism must work without internet (no external auth services)
- Must work on both Linux and macOS

## Scope Fence

**IN:** Tier 0 confirmation flow, inception decide confirmation, Human AC approval/feedback via Watchtower
**OUT:** General authentication, multi-user access control, remote approval workflows, full Watchtower redesign

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] All 4 spikes explored or ruled out with rationale
- [x] Recommendation written with go/no-go

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read the research artifact and recommendation in this task
  2. Evaluate go/no-go criteria against findings
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-608 go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- At least one approach provides provably-human confirmation with <5 second friction
- The approach cannot be bypassed by the agent without human involvement
- Implementation fits in one session (<4 hours)

**NO-GO if:**
- All approaches are either fakeable by the agent or require >30 seconds of human effort
- The only secure approach requires infrastructure not yet built (e.g., full auth system)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Recommendation

**Recommendation:** GO
**Rationale:** Watchtower approval surface — unfakeable, <1s friction, mobile, solves Human   AC backlog

## Decisions

**Decision**: GO

**Rationale**: Watchtower approval surface — unfakeable, <1s friction, mobile, solves Human
  AC backlog

**Date**: 2026-03-25T16:49:25Z
## Decision

**Decision**: GO

**Rationale**: Watchtower approval surface — unfakeable, <1s friction, mobile, solves Human
  AC backlog

**Date**: 2026-03-25T16:49:25Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-25T15:29:49Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-25T16:49:25Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Watchtower approval surface — unfakeable, <1s friction, mobile, solves Human
  AC backlog

### 2026-03-27T17:34:07Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-03-27 — artifact-reference [audit-fix]
- **Research artifact:** docs/reports/T-608-tier0-approval-surface.md

### 2026-04-06T22:29:32Z — status-update [task-update-agent]
- **Change:** horizon: next → later

### 2026-04-13T13:21:35Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)
- **Reason:** T-1226: GO decision already recorded

### 2026-04-13T13:21:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** T-1226: GO decision recorded via Watchtower
