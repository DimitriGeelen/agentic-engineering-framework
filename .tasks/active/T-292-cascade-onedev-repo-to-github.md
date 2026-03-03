---
id: T-292
name: "Cascade OneDev repo to GitHub"
description: >
  Inception: Cascade OneDev repo to GitHub

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-03T20:46:02Z
last_update: 2026-03-03T20:46:02Z
date_finished: null
---

# T-292: Cascade OneDev repo to GitHub

## Problem Statement

The Agentic Engineering Framework repo lives on a self-hosted OneDev instance (internal network). We want automatic cascading (push mirror) to GitHub so the repo is publicly accessible, discoverable, and usable by others — without manual syncing. Research artifact: `docs/reports/T-292-onedev-github-cascade.md`.

## Assumptions

- A-TBD: OneDev 7.1+ Push to Remote step works with GitHub PATs
- A-TBD: GitHub PAT with `repo` scope is sufficient for push mirror
- A-TBD: OneDev CI runner has outbound HTTPS access to github.com

## Exploration Plan

1. **Research** (15 min) — Survey OneDev docs and community for push mirror approaches → DONE, see research artifact
2. **Validate** (5 min) — Confirm OneDev version supports `PushRepository` step
3. **Decide** — Go/No-Go based on findings

## Technical Constraints

- OneDev is on internal network behind Traefik reverse proxy
- GitHub requires authentication for push (PAT or SSH key)
- OneDev CI jobs run in containers — need outbound HTTPS to github.com
- Existing `.onedev-buildspec.yml` has one job (LXC deploy) — new job must coexist

## Scope Fence

**IN scope:** Code mirror (branches + tags) from OneDev → GitHub
**OUT of scope:** Issue sync, PR sync, bidirectional sync, GitHub Actions

## Acceptance Criteria

- [x] Problem statement validated
- [ ] Assumptions tested
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- OneDev supports native Push to Remote step (confirmed: 7.1+)
- GitHub PAT-based auth works for push from CI container
- Implementation is < 1 session of work

**NO-GO if:**
- OneDev CI runner cannot reach github.com (network/firewall)
- Push mirror requires OneDev Enterprise (not available)
- Complexity exceeds value (manual push is acceptable)

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
