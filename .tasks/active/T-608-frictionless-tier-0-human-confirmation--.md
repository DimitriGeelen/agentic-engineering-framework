---
id: T-608
name: "Frictionless Tier 0 human confirmation — prove human acted without terminal switching"
description: >
  Current Tier 0 flow: hook blocks agent → human switches terminal → cd to project → paste command.
  Maximum friction for minimum governance value. Need: in-band confirmation that provably came from
  a human, not the agent. Explore: Claude Code permission prompts, challenge-response, Watchtower
  web UI approval button, TermLink out-of-band channel. Hard constraint: agent must not be able to
  bypass or fake the confirmation. Related: T-557 (inception decide gate), T-559 (boundary gate).

status: captured
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-25T15:26:08Z
last_update: 2026-03-25T15:26:08Z
date_finished: null
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
2. **Spike 2: Out-of-band approval** — Watchtower web UI button that writes a signed approval token. Agent polls for token. Human clicks button in browser. (2hr)
3. **Spike 3: Challenge-response with timing** — Hook generates challenge, human types response in Claude Code chat. Can the agent read and replay it? What prevents this? (1hr)
4. **Spike 4: TermLink approval channel** — Separate TermLink session that only the human can interact with. Agent sends request, human approves in another terminal. (1hr)

## Technical Constraints

- Claude Code hooks run as shell commands, stdout/stderr shown to user, non-interactive
- Agent can read all files in PROJECT_ROOT and /tmp
- Agent can execute any Bash command the user allows
- The confirmation mechanism must work without internet (no external auth services)
- Must work on both Linux and macOS

## Scope Fence

**IN:** Tier 0 confirmation flow, inception decide confirmation
**OUT:** General authentication, multi-user access control, remote approval workflows

## Acceptance Criteria

### Agent
- [ ] Problem statement validated
- [ ] All 4 spikes explored or ruled out with rationale
- [ ] Recommendation written with go/no-go

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
