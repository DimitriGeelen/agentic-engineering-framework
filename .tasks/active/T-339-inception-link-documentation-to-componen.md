---
id: T-339
name: "Inception: link documentation to Component Fabric endpoints"
description: >
  Explore how documentation pages (guides, concept explanations, deep-dives) can be linked to their corresponding Component Fabric entries, creating bidirectional navigation between what-it-is (docs) and where-it-is (code). Use cases: doc page links to fabric component, fabric component links to relevant docs, Watchtower shows docs alongside component details.

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-08T08:20:49Z
last_update: 2026-03-08T21:38:47Z
date_finished: null
---

# T-339: Inception: link documentation to Component Fabric endpoints

## Problem Statement

Zero bidirectional links exist between documentation (7 deep-dives, launch article, CLAUDE.md sections) and Component Fabric entries (127 cards). A user reading about "the healing loop" cannot navigate to the code. A user viewing a component in Watchtower sees no reference to explanatory docs. This creates two disconnected views of the same system.

## Assumptions

1. Adding an optional `docs` field to component cards won't break existing fabric tooling (drift, blast-radius, traverse, query) — **VALIDATED**: all tooling uses `.get()` with defaults, no strict schema
2. At least 5 of 7 deep-dives map cleanly to specific components — **VALIDATED**: 7/7 map cleanly
3. Watchtower component detail template can render doc links with minimal changes — **VALIDATED**: template is simple Jinja2, adding a section is trivial

## Exploration Plan

1. ~~Check if fabric tooling has strict schema validation~~ — Done, no strict schema
2. ~~Check deep-dive → component mapping feasibility~~ — Done, 7/7 clean
3. ~~Assess 4 design options~~ — Done, see research artifact

## Technical Constraints

None. This is YAML field additions and template changes.

## Scope Fence

**IN:** Add `docs` field to component cards, populate for 7 deep-dives, show in Watchtower component detail page.
**OUT:** Doc-side component links (frontmatter in .md files), full `/docs` index page, CLAUDE.md section→component linking. These are follow-ups if Option A proves useful.

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Adding `docs` field doesn't break fabric tooling — CONFIRMED
- Watchtower can render doc links with minimal template changes — CONFIRMED
- At least 5/7 deep-dives map cleanly to components — CONFIRMED (7/7)

**NO-GO if:**
- Schema validation breaks — NOT the case
- Mapping is too many-to-many — NOT the case (each deep-dive maps to 2-5 components)
- No demand signal — demand exists (this was captured as a task)

## Verification

test -f docs/reports/T-339-doc-fabric-linking.md

## Decisions

**Decision**: GO

**Rationale**: All 3 assumptions validated. docs field safe to add (no strict schema), 7/7 deep-dives map to components, Watchtower template change is trivial. Option A (docs field in cards) recommended. See docs/reports/T-339-doc-fabric-linking.md

**Date**: 2026-03-08T21:32:58Z
## Decision

**Decision**: GO

**Rationale**: All 3 assumptions validated. docs field safe to add (no strict schema), 7/7 deep-dives map to components, Watchtower template change is trivial. Option A (docs field in cards) recommended. See docs/reports/T-339-doc-fabric-linking.md

**Date**: 2026-03-08T21:32:58Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-08T21:30:32Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-08T21:32:58Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** All 3 assumptions validated. docs field safe to add (no strict schema), 7/7 deep-dives map to components, Watchtower template change is trivial. Option A (docs field in cards) recommended. See docs/reports/T-339-doc-fabric-linking.md
