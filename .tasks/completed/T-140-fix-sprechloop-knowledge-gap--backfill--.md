---
id: T-140
name: Fix sprechloop knowledge gap — backfill + enforce knowledge capture
description: >
  Inception: Fix sprechloop knowledge gap — backfill + enforce knowledge capture

status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T08:00:18Z
last_update: 2026-02-18T08:07:21Z
date_finished: 2026-02-18T08:07:21Z
---

# T-140: Fix sprechloop knowledge gap — backfill + enforce knowledge capture

## Problem Statement

Sprechloop tasks are thin — no Decisions section, weak AC prompts, no verification guidance. Watchtower Knowledge pages empty (0 patterns, 0 decisions, 1 learning across 21 tasks). Root cause: create-task.sh uses a hardcoded heredoc for non-inception tasks instead of the default.md template file. The template has all the right sections but is never applied.

## Assumptions

1. Fixing create-task.sh to use default.md will give future tasks rich structure (VALIDATED: template comparison confirms)
2. Existing 21 completed tasks contain extractable knowledge (VALIDATED: agents mined 14 learnings, 8 decisions, 5 patterns)

## Exploration Plan

1. Compare templates — DONE (heredoc vs default.md)
2. Mine completed tasks — DONE (14L, 8D, 5P extracted)
3. Design fix — DONE (use default.md like inception.md, add test script)

## Scope Fence

IN: Fix create-task.sh template wiring, backfill sprechloop knowledge, add test script
OUT: New enforcement gates (P-012), watchtower UI changes

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- [Criterion 1]
- [Criterion 2]

**NO-GO if:**
- [Criterion 1]
- [Criterion 2]

## Verification

# Inception task — no code verification needed

## Decisions

**Decision**: GO

**Rationale**: Root cause: create-task.sh heredoc bypasses default.md template. Fix wiring + backfill + add tests.

**Date**: 2026-02-18T08:07:20Z
## Decision

**Decision**: GO

**Rationale**: Root cause: create-task.sh heredoc bypasses default.md template. Fix wiring + backfill + add tests.

**Date**: 2026-02-18T08:07:20Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-02-18T08:06:46Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Root cause found: create-task.sh uses hardcoded heredoc instead of default.md template. Fix the wiring — no new controls needed. Also backfill sprechloop knowledge from mined task data.

### 2026-02-18T08:07:07Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Root cause: create-task.sh heredoc bypasses default.md template. Fix wiring + backfill + add tests.

### 2026-02-18T08:07:20Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Root cause: create-task.sh heredoc bypasses default.md template. Fix wiring + backfill + add tests.

### 2026-02-18T08:07:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
