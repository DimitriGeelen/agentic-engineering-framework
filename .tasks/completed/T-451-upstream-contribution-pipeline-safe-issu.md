---
id: T-451
name: "Upstream contribution pipeline: safe issue/PR creation from field installations to framework repo"
description: >
  Inception: Upstream contribution pipeline: safe issue/PR creation from field installations to framework repo

status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-12T09:36:54Z
last_update: 2026-03-12T11:03:38Z
date_finished: 2026-03-12T11:03:38Z
---

# T-451: Upstream contribution pipeline: safe issue/PR creation from field installations to framework repo

## Problem Statement

The framework maintainer uses the framework in multiple projects via shared tooling (`fw init`). When working in Project X and discovering a framework bug or improvement, there is no streamlined way to get that issue back to the framework repo. The friction means discoveries get lost.

**Key risks identified:**
- Pushing to wrong remote (project repo instead of framework upstream)
- Overwriting existing PRs
- Cross-contamination (project code in framework PR or vice versa)
- Agent not aware of remote topology after compaction

**For whom:** Framework maintainer (primary), future external contributors (secondary)
**Why now:** Active multi-project usage — real friction experienced today

**Research artifact:** `docs/reports/T-451-upstream-contribution-research.md`

## Assumptions

1. `gh` CLI is available and authenticated in all field installations
2. `.framework.yaml` is the right place for persistent upstream config
3. Issue-only mode (no push) covers 80%+ of upstream reporting needs
4. PR mode needs structural isolation (temp clone) to prevent cross-contamination
5. Fixes should be verified locally before upstream reporting

## Exploration Plan

1. ~~Research: distribution model, git safety, gh CLI, OneDev pattern~~ — DONE
2. Design: command surface and safety model — DONE (in research artifact)
3. Spike: minimal `fw upstream report` (issue-only) — 1 hour
4. Decision: go/no-go on full implementation

## Technical Constraints

- `gh` CLI required (authenticated with `repo` scope)
- `.framework.yaml` must exist in consumer projects (created by `fw init`)
- Self-hosting mode (no `.framework.yaml`) needs fallback to git remote discovery
- No `upstream_repo` field exists in `.framework.yaml` yet — needs `fw init` update
- Tier 0 does NOT protect against wrong-repo pushes (only force push) — safety must be structural

## Scope Fence

**IN scope:**
- `fw upstream report` — issue creation via `gh issue create --repo` (zero push risk)
- `fw upstream config` — persistent upstream repo URL in `.framework.yaml`
- `fw upstream status` — show config, auth, remote topology
- `fw init` update — auto-detect and store `upstream_repo`
- Dry-run default, confirmation prompt, `fw doctor` attachment

**OUT of scope (future tasks if GO):**
- `fw upstream contribute` (PR mode with fork/clone isolation) — separate build task
- `fw upstream share-learning` (harvest extension) — separate build task
- GitHub Actions integration
- Webhook/notification systems

## Acceptance Criteria

- [x] Problem statement validated (real friction in multi-project usage)
- [x] Research completed (distribution model, git safety, gh CLI, isolation strategies)
- [x] Safety model designed (issue-only default, structural isolation for PRs)
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- `gh issue create --repo` works cross-directory (confirmed: yes)
- `.framework.yaml` can store upstream URL without breaking existing installs (confirmed: additive field)
- Issue-only mode is implementable in <2 hours (confirmed: ~50 lines wrapping `gh`)

**NO-GO if:**
- `gh` auth model can't target repos outside current directory (disproved)
- Safety model requires Tier 0 changes for issue-only mode (disproved — no push needed)
- Complexity of even issue-only mode exceeds one session (disproved)

## Verification

test -f docs/reports/T-451-upstream-contribution-research.md

## Decisions

**Decision**: GO

**Rationale**: All GO criteria met: gh issue create --repo works cross-directory, .framework.yaml upstream_repo is additive, issue-only mode is ~50 lines. Ship issue-only first, PR mode as separate task.

**Date**: 2026-03-12T11:03:30Z
## Decision

**Decision**: GO

**Rationale**: All GO criteria met: gh issue create --repo works cross-directory, .framework.yaml upstream_repo is additive, issue-only mode is ~50 lines. Ship issue-only first, PR mode as separate task.

**Date**: 2026-03-12T11:03:30Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-12T11:03:30Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** All GO criteria met: gh issue create --repo works cross-directory, .framework.yaml upstream_repo is additive, issue-only mode is ~50 lines. Ship issue-only first, PR mode as separate task.

### 2026-03-12T11:03:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
