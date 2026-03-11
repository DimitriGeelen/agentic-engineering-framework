---
id: T-442
name: "Cron job: pull OneDev PRs and convert to tasks (local-only)"
description: >
  Inception: Cron job: pull OneDev PRs and convert to tasks (local-only)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-11T23:45:59Z
last_update: 2026-03-11T23:45:59Z
date_finished: null
---

# T-442: Cron job: pull OneDev PRs and convert to tasks (local-only)

## Problem Statement

OneDev PRs sit unnoticed until manually checked. Need automatic bridge from OneDev PRs to framework tasks so they appear on the task board. Must be local-only (not propagate to GitHub).

## Assumptions

1. [VALIDATED] OneDev API accessible from this machine — confirmed, returns 200
2. [VALIDATED] No auth needed for reading PRs — confirmed, public project
3. [VALIDATED] `fw task create` works non-interactively — confirmed with `--owner` flag

## Exploration Plan

1. [DONE] API connectivity spike — test OneDev REST API
2. [DONE] Task creation spike — test `fw task create` without TTY
3. [DONE] Research artifact — document design options

## Technical Constraints

- OneDev at `https://onedev.docker.ring20.geelenandcompany.com`
- API endpoint: `/~api/pulls`
- No auth required for read access
- Script must be in `.gitignore` to prevent GitHub propagation

## Scope Fence

**IN:** Cron polls OneDev for open PRs, creates tasks for new ones, tracks seen PRs
**OUT:** Updating tasks when PRs merge/close (can add later), commenting on PRs from framework

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Decisions

### 2026-03-11 — GO decision
- **Chose:** GO — build the cron job
- **Why:** All 3 spikes passed. API accessible without auth, task creation works non-interactively, local-only via .gitignore
- **Rejected:** No-go (all technical risks resolved)

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-11T23:55:55Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** API accessible without auth, task creation works non-interactively, local-only via .gitignore
