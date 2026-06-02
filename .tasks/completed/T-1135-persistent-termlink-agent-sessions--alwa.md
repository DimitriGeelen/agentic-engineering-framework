---
id: T-1135
name: "Persistent TermLink agent sessions — always-listening receptionist per project, resume-flow health check, cleanup exemption, cross-agent specialist network"
description: >
  Inception: Persistent TermLink agent sessions — always-listening receptionist per project, resume-flow health check, cleanup exemption, cross-agent specialist network

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-12T09:14:35Z
last_update: 2026-04-13T06:23:19Z
date_finished: 2026-04-12T11:03:47Z
---

# T-1135: Persistent TermLink agent sessions — always-listening receptionist per project, resume-flow health check, cleanup exemption, cross-agent specialist network

## Problem Statement

Two contradictory patterns exist:

1. **Stale session cleanup** (T-866 cron) kills TermLink sessions that have been idle too long, preventing zombie accumulation.
2. **Persistent agent sessions** need to survive indefinitely so other agents across the network can always reach a listening agent on each machine/project.

Today's evidence (S-2026-0412): This session communicated with ring20-manager (.109) via TermLink inject -- questions got immediate answers, files were resent within seconds. But this only works because ring20-manager happened to have an active session. If that session had ended or been cleaned up, there would be nobody to answer.

**The vision:** Every project should have a **persistent TermLink agent session** (a "receptionist") that:
- Is always listening for cross-agent communication
- Survives cleanup crons (exempted by tag or registration)
- Is health-checked on session start (`/resume` flow) and respawned if down
- Acts as a specialist that other agents can consult about the project's domain
- Enables a **networked agent ecosystem** where projects share expertise

**For whom:** Every project running the framework (framework itself, consumer projects, /opt/termlink).
**Why now:** Cross-agent communication via inject proved its value today (T-1126). Making it reliable requires always-on listeners.

## Assumptions

- A1: TermLink sessions can persist across user sessions (tmux backend persists)
- A2: Cleanup cron can be made tag-aware (exempt `persistent:true` sessions)
- A3: A minimal "receptionist" agent can run cheaply (listens for inject, processes commands)
- A4: `fw doctor` or `/resume` can health-check persistent sessions
- A5: Consumer projects benefit equally (each becomes a reachable specialist)
- A6: The hub mesh (.112 hub) can route to persistent sessions across machines

## Exploration Plan

1. **Audit cleanup cron** — how does it decide what's stale? Can it exempt tagged sessions?
2. **Prototype persistent session** — spawn a minimal claude -p with instruction to listen and respond
3. **Design resume-flow check** — on /resume, check if persistent agent is up, respawn if not
4. **Design registration** — .framework.yaml or .termlink-agent.yaml config for persistent session params
5. **Evaluate consumer impact** — how would /opt/termlink or /opt/025 set up their own receptionist?

## Technical Constraints

- TermLink sessions use tmux backend -- tmux persists across SSH disconnects
- Hub mesh routes by session name -- persistent session needs stable, discoverable name
- Claude -p workers consume API tokens while active -- receptionist cost model matters
- Multiple projects on same machine need distinct session names

## Scope Fence

**IN:** Design the persistent session architecture, resume-flow integration, cleanup exemption, registration format.
**OUT:** Implementing cross-machine orchestration, building the specialist network protocol, modifying TermLink upstream.

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
- Persistent sessions can survive cleanup cron (tag-based exemption feasible)
- Cost model is acceptable (receptionist agent uses minimal tokens when idle)
- Resume-flow health check is implementable without heavy refactoring
- Cross-project agents agree on session naming convention (coordinated with ring20-manager)

**NO-GO if:**
- Persistent sessions cause resource exhaustion (memory, tmux sessions accumulate)
- API cost of idle listening agents is prohibitive
- TermLink architecture doesn't support stable persistent discovery

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO

**Rationale:** Cross-agent coordination with TermLink project confirms the fix is small (3 code changes in TermLink, ~2 hours), the tags infrastructure is 90% ready, and the cost model is acceptable. The persistent session pattern enables the networked agent ecosystem the human envisions. Both projects have aligned on naming convention, tag-based exemption, and restart event signaling.

**Evidence:**
- TermLink project (T-967) confirmed: cleanup is PID-based, no tag awareness yet
- Tags infrastructure already exists (`--tags persistent` works for registration + discovery)
- Fix: 3 code changes in supervisor.rs, manager.rs, remote_store.rs
- Cost: ~2KB disk + 1 FD per session (TermLink overhead), ~150MB per Claude Code process
- Naming convention agreed: `{project}-agent` with tags `persistent,receptionist`
- Counter-proposal accepted: emit `session.needs_restart` event (observable, not silent)
- Framework side: `/resume` health check, `fw doctor` report, `.framework.yaml` config

**Build decomposition (after GO):**
1. TermLink upstream: tag-aware cleanup exemption (T-967 build tasks)
2. Framework: `/resume` persistent agent health check
3. Framework: `fw doctor` persistent agent report
4. Framework: `.framework.yaml` persistent_session config block
5. Framework: `fw termlink agent start/stop/status` subcommands

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Cross-agent coordination with TermLink project confirms the fix is small (3 code changes in TermLink, ~2 hours), the tags infrastructure is 90% ready, and the cost mo...

**Date**: 2026-04-12T11:03:47Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Cross-agent coordination with TermLink project confirms the fix is small (3 code changes in TermLink, ~2 hours), the tags infrastructure is 90% ready, and the cost mo...

**Date**: 2026-04-12T11:03:47Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-12T09:16:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T11:03:47Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Cross-agent coordination with TermLink project confirms the fix is small (3 code changes in TermLink, ~2 hours), the tags infrastructure is 90% ready, and the cost mo...

### 2026-04-12T11:03:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bd834abd
- **Timestamp:** 2026-06-02T14:55:24Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
