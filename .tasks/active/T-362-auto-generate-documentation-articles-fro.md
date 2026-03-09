---
id: T-362
name: "Auto-generate documentation articles from Component Fabric"
description: >
  Inception: Auto-generate documentation articles from Component Fabric

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-08T21:55:31Z
last_update: 2026-03-08T22:03:47Z
date_finished: null
---

# T-362: Auto-generate documentation articles from Component Fabric

## Problem Statement

127 components in the fabric, only 24 linked to 7 hand-written articles. 103 components have no documentation beyond a purpose field — 60% of which are broken/placeholder. New components get registered but never documented. We need a system that generates documentation automatically from existing structured data (cards, source code, CLAUDE.md, episodic memory).

## Assumptions

1. Component cards + source headers + CLAUDE.md contain enough data for useful reference docs — VALIDATED (agent 2: 80% mechanical extraction)
2. Existing framework patterns (episodic.sh, handover.sh) can be extended for doc generation — VALIDATED (agent 3: heredoc assembly + embedded Python)
3. Deep-dive articles follow a consistent template that can be parameterized — VALIDATED (agent 1: 4-section pattern, ~103 lines)
4. 60% of purpose fields need fixing before generation produces quality output — VALIDATED (agent 2)

## Exploration Plan

1. ~~Analyze existing article structure~~ — Done (agent 1): 4-section template identified
2. ~~Survey available data in fabric~~ — Done (agent 2): 80/20 mechanical/judgment split
3. ~~Check existing generation patterns~~ — Done (agent 3): heredoc + Python proven
4. Design two-layer system — Done: see `docs/reports/T-362-auto-doc-generation.md`

## Technical Constraints

- No external API dependencies for Layer 1 (mechanical generation)
- Layer 2 (article generation) needs LLM access — can output prompt files as fallback
- Generation must be idempotent (re-run produces same output for unchanged inputs)
- Must not modify source code or component cards (read-only generation)

## Scope Fence

**IN:** Design the auto-generation system, identify build tasks, go/no-go decision.
**OUT:** Actually building the generators (spawn as separate build tasks).

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested (3 research agents)
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Layer 1 can generate useful reference docs from current card data — CONFIRMED
- Generation is idempotent — design ensures this (deterministic extraction)
- Generated docs integrate with Watchtower — CONFIRMED (markdown2 already available)

**NO-GO if:**
- Card data too sparse for basic reference docs — NOT the case (deps are 100% complete)
- Generation > 5 min for all 127 components — NOT the case (simple extraction)
- Output quality worse than reading source — NOT the case (aggregates multiple sources)

## Verification

test -f docs/reports/T-362-auto-doc-generation.md

## Decisions

**Decision**: GO

**Rationale**: All assumptions validated by 3 research agents. Two-layer design: Layer 1 (mechanical reference docs) covers 80% of value, Layer 2 (AI-assisted articles) adds narrative depth. Prerequisite: fix 60% broken purpose fields. See docs/reports/T-362-auto-doc-generation.md

**Date**: 2026-03-08T22:03:13Z
## Decision

**Decision**: GO

**Rationale**: All assumptions validated by 3 research agents. Two-layer design: Layer 1 (mechanical reference docs) covers 80% of value, Layer 2 (AI-assisted articles) adds narrative depth. Prerequisite: fix 60% broken purpose fields. See docs/reports/T-362-auto-doc-generation.md

**Date**: 2026-03-08T22:03:13Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-08T22:03:13Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** All assumptions validated by 3 research agents. Two-layer design: Layer 1 (mechanical reference docs) covers 80% of value, Layer 2 (AI-assisted articles) adds narrative depth. Prerequisite: fix 60% broken purpose fields. See docs/reports/T-362-auto-doc-generation.md
