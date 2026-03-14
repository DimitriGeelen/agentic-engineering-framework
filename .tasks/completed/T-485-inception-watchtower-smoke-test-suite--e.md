---
id: T-485
name: "Inception: Watchtower smoke test suite — endpoint + content validation on startup"
description: >
  Watchtower needs a post-startup smoke test that validates: (1) all endpoints return 200, (2) key content is present on each page, (3) tests auto-update when routes/templates change, (4) integrated into fw serve flow. From macOS field testing — errors on fresh project installs.

status: work-completed
workflow_type: inception
owner: agent
horizon: now
tags: [watchtower, testing, reliability]
components: []
related_tasks: []
created: 2026-03-14T15:22:55Z
last_update: 2026-03-14T15:34:06Z
date_finished: 2026-03-14T15:34:06Z
---

# T-485: Inception: Watchtower smoke test suite — endpoint + content validation on startup

## Problem Statement

69 endpoints across 18 blueprints with no post-startup validation beyond `/health`. Fresh macOS installs exposed Python 3.9 type hint errors and missing data issues that only surface when clicking through pages manually. Need automated smoke tests that: (1) validate all endpoints return 200, (2) check key content markers, (3) auto-discover new routes, (4) integrate into fw doctor/audit/serve.

## Assumptions

- A1: Flask test client can exercise all routes without a live server — **VALIDATED** (test_app.py already does this)
- A2: Content markers from endpoint map are stable enough for assertions — **VALIDATED** (templates change infrequently, markers are structural)
- A3: fw doctor and fw audit are the right integration points — **VALIDATED** (audit already checks /health, doctor has modular check pattern)

## Exploration Plan

3 parallel spikes completed:
1. **Spike 1:** Map all endpoints — 69 routes, content markers, data dependencies
2. **Spike 2:** Evergreen strategy — Option C hybrid recommended (runtime discovery + manifest for critical routes)
3. **Spike 3:** Integration points — fw doctor (primary) + fw audit deployment gate + optional fw serve --smoke

## Scope Fence

**IN:** Phase 1 smoke test script (web/smoke_test.py), fw doctor integration, fw audit deployment gate
**OUT:** Full manifest for all 69 routes (Phase 3), CI integration (separate task), streaming endpoint tests

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Flask test client can exercise routes without running server (YES)
- Phase 1 implementable in <4 hours (YES, ~2 hours estimated)

**NO-GO if:**
- Routes require live server to test (NO — test client works)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: Flask test client validated, 69 endpoints mapped, hybrid phased approach

**Date**: 2026-03-14T15:34:06Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-14T15:32:55Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 3 spikes confirm: Flask test client works without running server, 69 endpoints mapped, hybrid approach (runtime discovery + content markers for critical routes). Phase 1 is ~2 hours, zero maintenance.

### 2026-03-14T15:33:04Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 3 spikes confirm: Flask test client works without running server, 69 endpoints mapped, hybrid approach. Phase 1 low-effort high-value.

### 2026-03-14T15:33:18Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Flask test client validated, 69 endpoints mapped, hybrid approach phased

### 2026-03-14T15:33:23Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Flask test client validated, 69 endpoints mapped, hybrid approach phased

### 2026-03-14T15:34:06Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Flask test client validated, 69 endpoints mapped, hybrid phased approach

### 2026-03-14T15:34:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
