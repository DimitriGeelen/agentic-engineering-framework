---
id: T-549
name: "OpenClaw deep-dive — ingest existing project, evaluate architecture, extract value, capture framework learnings"
description: >
  Inception: OpenClaw deep-dive — ingest existing project, evaluate architecture, extract value, capture framework learnings

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: [agents/context/check-project-boundary.sh, bin/fw]
related_tasks: []
created: 2026-03-23T11:32:07Z
last_update: 2026-04-13T13:22:17Z
date_finished: 2026-04-13T13:22:17Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-549: OpenClaw deep-dive — ingest existing project, evaluate architecture, extract value, capture framework learnings

## Problem Statement

Can the Agentic Engineering Framework ingest an existing large-scale open-source project (OpenClaw — 331K+ stars, 21K+ commits, Node.js/TypeScript), bootstrap governance over it, and produce a structured evaluation that identifies, evaluates, carves out, and adopts valuable architectural elements?

This is a **dual-purpose evaluation:**
1. **OpenClaw value extraction** — identify architecture, design patterns, components, and functionality worth adopting for our projects
2. **Framework stress test** — can our framework bootstrap into an unknown codebase and produce excellent-quality context fabric and component maps? What breaks, what's missing?

**For whom:** Framework development (validate ingestion capability) + project strategy (evaluate OpenClaw's worth).
**Why now:** Framework init flow is stable (T-460, T-489), component fabric is mature, TermLink enables persistent remote sessions. First real test of the framework on a foreign codebase.

## What is OpenClaw

- **Repo:** https://github.com/openclaw/openclaw
- **Stack:** Node.js 24+, TypeScript, pnpm monorepo
- **What:** Personal AI assistant — local-first, multi-platform (WhatsApp, Telegram, Slack, Discord, Signal, iMessage, 15+ channels)
- **Architecture:** WebSocket control plane (gateway on :18789), Pi agent runtime (RPC), multi-agent routing, isolated workspaces
- **Components:** Gateway/control UI, channel integrations, macOS/iOS/Android apps, browser control, Canvas (A2UI), skills platform, cron/webhooks
- **Scale:** 331K+ stars, 64.5K+ forks, 21.5K commits, MIT license
- **Install:** `npm install -g openclaw@latest` or clone + `pnpm install && pnpm build`

## Assumptions

- A-001: The framework can bootstrap (`fw init`) into a Node.js/TypeScript monorepo without modification
- A-002: Component fabric can meaningfully map a project of this scale (~hundreds of source files)
- A-003: SSH access to 192.168.10.107 can be configured for TermLink persistence
- A-004: OpenClaw's architecture has extractable patterns worth adopting (WebSocket control plane, multi-agent routing, skills platform)
- A-005: A Claude Code session in the OpenClaw project (with pickup prompt) can self-govern using the framework's init tasks
- A-006: Learnings from this exercise will surface concrete improvement items for framework and TermLink

## Exploration Plan

### Phase 1: Infrastructure Setup (from THIS project, via TermLink)
1. Configure SSH to 192.168.10.107
2. Create `/opt/openclaw-evaluation/` on .107
3. Clone OpenClaw repo
4. Initialize framework: `fw init`
5. Run `fw doctor`, iterate until clean
6. Bootstrap component fabric — register key components, run `fw fabric drift` until coverage is good
7. Verify context fabric quality

### Phase 2: Handoff (STOP from this project)
1. Generate pickup prompt with full context for the OpenClaw evaluation session
2. User starts NEW Claude Code session in `/opt/openclaw-evaluation/` on .107
3. That session uses the pickup prompt to understand goals and current state

### Phase 3: Evaluation (in OpenClaw project, user-driven)
1. New session creates inception tasks INSIDE the OpenClaw project:
   - Architecture mapping (gateway, control plane, agent runtime)
   - Design pattern inventory (WebSocket control, multi-agent routing, workspace isolation)
   - Component evaluation (which are well-built, which are fragile)
   - Value extraction strategy (what to carve out for our projects)
2. Execute evaluation tasks under framework governance
3. Produce structured evaluation report

### Phase 4: Meta-Learning (back in THIS project)
1. Capture framework learnings (what worked/broke during init on foreign codebase)
2. Capture TermLink learnings (remote persistence, session management)
3. Create improvement tasks for framework and TermLink

## Technical Constraints

- **Target machine:** 192.168.10.107 (Proxmox LXC, hosts Ollama)
- **SSH:** Needs key-based access configured (currently blocked — no key installed)
- **Disk:** OpenClaw repo is ~170MB+ (monorepo with node_modules after install)
- **Node.js:** Needs Node 22.16+ or 24+ on .107 for OpenClaw to build
- **TermLink:** Must be installed on .107 for persistent sessions
- **Framework:** Must be installed on .107 (`fw` available in PATH)
- **Network:** .107 needs internet access for git clone and npm install

## Scope Fence

**IN scope (this inception, Phase 1-2):**
- Infrastructure setup on .107
- Framework init + fabric quality iteration
- Pickup prompt generation for handoff

**IN scope (OpenClaw project, Phase 3 — user-driven):**
- Full architecture/design/component evaluation
- Value extraction strategy and execution
- Evaluation report

**IN scope (back here, Phase 4):**
- Meta-learnings for framework + TermLink improvement

**OUT of scope:**
- Actually running OpenClaw as a service (we're evaluating code, not deploying)
- Contributing back to OpenClaw
- Building OpenClaw's native apps (macOS, iOS, Android)
- Modifying OpenClaw's source code

## Acceptance Criteria

- [x] Problem statement validated
- [x] Infrastructure on .107 operational (SSH, clone, fw init, doctor passes)
- [x] Component fabric maps OpenClaw at meaningful quality
- [x] Pickup prompt generated for handoff session
- [x] Assumptions tested
- [x] Go/No-Go decision made (GO — proceed with full evaluation)

## Go/No-Go Criteria

**GO if:**
- Framework bootstraps cleanly into OpenClaw (fw doctor passes, fabric maps key components)
- OpenClaw architecture has identifiable patterns worth evaluating
- TermLink persistence works for remote session management
- Pickup prompt is sufficient for an independent session to continue

**NO-GO if:**
- .107 infrastructure cannot be set up (SSH, disk, Node.js blockers)
- Framework init produces poor-quality fabric (can't meaningfully map a Node/TS monorepo)
- OpenClaw codebase is too large/complex for meaningful evaluation within reasonable time
- TermLink remote persistence is unreliable

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Recommendation

**Recommendation:** GO
**Rationale:** Infrastructure confirmed: SSH to .107, OpenClaw cloned, fw init complete (doctor 0 failures), CLAUDE.md has governance sections (1015 lines), git hooks installed, 6 onboarding tasks ready. TermLink compiling from source. Pickup prompt generated with full framework + TermLink enablement.

## Decisions

**Decision**: GO

**Rationale**: Infrastructure confirmed: SSH to .107, OpenClaw cloned, fw init complete (doctor 0 failures), CLAUDE.md has governance sections (1015 lines), git hooks installed, 6 onboarding tasks ready. TermLink compiling from source. Pickup prompt generated with full framework + TermLink enablement.

**Date**: 2026-03-23T11:52:34Z
## Decision

**Decision**: GO

**Rationale**: Infrastructure confirmed: SSH to .107, OpenClaw cloned, fw init complete (doctor 0 failures), CLAUDE.md has governance sections (1015 lines), git hooks installed, 6 onboarding tasks ready. TermLink compiling from source. Pickup prompt generated with full framework + TermLink enablement.

**Date**: 2026-03-23T11:52:34Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-23T11:52:34Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Infrastructure confirmed: SSH to .107, OpenClaw cloned, fw init complete (doctor 0 failures), CLAUDE.md has governance sections (1015 lines), git hooks installed, 6 onboarding tasks ready. TermLink compiling from source. Pickup prompt generated with full framework + TermLink enablement.

### 2026-03-27T17:34:07Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-03-27 — artifact-reference [audit-fix]
- **Research artifact:** docs/reports/T-549-openclaw-architecture-mapping.md

### 2026-04-06T22:29:32Z — status-update [task-update-agent]
- **Change:** horizon: next → later

### 2026-04-13T13:21:28Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)
- **Reason:** T-1226: GO decision already recorded

### 2026-04-13T13:22:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** T-1226: GO decision recorded via Watchtower

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d2523f74
- **Timestamp:** 2026-06-02T15:03:31Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
