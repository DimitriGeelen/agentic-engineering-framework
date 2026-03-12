---
id: T-433
name: "Inception: Cron job registry and administration page in Watchtower"
description: >
  Explore adding a Watchtower page that displays all cron jobs: schedule/frequency,
  status (running/stopped/errored), last run time, next run time. Management controls:
  start, stop, change frequency. For each cron job, use the local LLM to generate rich
  context — what it does, why it exists, its background, dependencies. Currently cron
  jobs are invisible infrastructure. This page makes them observable and manageable.

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: [watchtower, cron, ux, administration, observability]
components: []
related_tasks: [T-398]
created: 2026-03-10T21:13:35Z
last_update: 2026-03-12T06:02:29Z
date_finished: null
---

# T-433: Inception: Cron job registry and administration page in Watchtower

## Problem Statement

Cron jobs are invisible infrastructure. The framework runs scheduled tasks (audit cron every 15 min,
potentially more in future) but there is no UI to see what's scheduled, whether it ran, when it last
fired, or what it does. The only way to know is to SSH in and inspect crontab/systemd timers.

This matters because:
- **Observability (D2):** Silent cron failures go undetected until audit data goes stale
- **Usability (D3):** New users have no idea what background processes exist or what they do
- **Administration:** No way to pause, adjust frequency, or troubleshoot without SSH access

The human requested not just a display page but a management page — start/stop controls, frequency
changes, and LLM-generated documentation per job to provide context and explanation.

## Assumptions

- A1: Cron jobs are currently managed via system crontab or systemd timers (need to verify)
- A2: It is safe to expose start/stop controls through the web UI (need to assess security model)
- A3: The local LLM (Ollama) can generate useful per-job documentation from the script source
- A4: The number of cron jobs is small enough (<20) for a single-page registry
- A5: Job status can be determined from output files, exit codes, or process inspection

## Exploration Plan

| # | Spike | Time-box | Deliverable |
|---|-------|----------|-------------|
| 1 | Inventory existing cron infrastructure | 15min | List of all scheduled jobs, their mechanisms, and metadata |
| 2 | Assess control safety model | 20min | What controls are safe to expose, what needs auth/confirmation |
| 3 | Evaluate LLM documentation approach | 15min | Can Ollama generate useful job descriptions from script source? |
| 4 | Design page wireframe and data model | 20min | Page structure, API endpoints, job registry format |
| 5 | Present options to human | 10min | Go/No-Go decision |

## Technical Constraints

- Watchtower runs as Flask app — cron management requires subprocess calls or systemd D-Bus
- Security: start/stop controls must not allow arbitrary command execution
- LLM documentation generation adds latency — may need caching or pre-generation
- Must work in both local dev (crontab) and LXC production (systemd timers)

## Scope Fence

**IN scope:** Registry display, status monitoring, frequency display, start/stop controls for known
framework cron jobs, LLM-generated documentation per job, Watchtower page and API

**OUT of scope:** General-purpose cron manager (only framework jobs), scheduling new arbitrary jobs,
real-time log streaming, alert/notification system

## Acceptance Criteria

### Agent
- [ ] Problem statement validated (inventory of existing cron infrastructure)
- [ ] Assumptions tested (control safety, LLM doc quality, job count)
- [ ] Design options presented with trade-offs
- [ ] Go/No-Go decision recorded

### Human
- [ ] [REVIEW] Choose design approach for cron administration page
  **Steps:**
  1. Read research artifact at `docs/reports/T-433-cron-registry-inception.md`
  2. Review proposed page design and safety model
  3. Decide: approve, modify scope, or reject
  **Expected:** Clear direction on scope and controls
  **If not:** Discuss specific concerns about safety or scope

## Go/No-Go Criteria

**GO if:**
- Cron infrastructure is inventoried and understood
- A safe control model can be designed (no arbitrary execution risk)
- LLM documentation adds real value beyond script comments
- Implementation fits in one session (~4h)

**NO-GO if:**
- Cron management requires unsafe shell exposure
- Only 1-2 cron jobs exist (not worth a dedicated page)
- Control mechanisms vary too much between dev/prod to unify

## Verification

test -f docs/reports/T-433-cron-registry-inception.md

## Decisions

<!-- Pending exploration -->

## Decision

<!-- Filled at completion via: fw inception decide T-433 go|no-go --rationale "..." -->

## Updates

### 2026-03-10T21:13:35Z — task-created [task-create-agent]
- **Action:** Created inception task from human request
- **Context:** Human wants observable, manageable cron infrastructure with LLM-generated context per job

### 2026-03-12T06:02:29Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
