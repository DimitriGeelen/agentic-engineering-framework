---
id: T-191
name: "Component Fabric — structural topology system for codebase self-awareness"
description: >
  Deep inception (5-10 sessions): Design and validate a universal structural topology system
  ("Component Fabric") that gives any project governed by AEF machine-readable self-awareness
  of its own codebase. Components, dependencies, UI elements, interaction flows, and data
  paths should be tracked, enforced, and queryable — so agents can navigate, debug, enhance,
  and impact-assess without reading all code. Adaptive granularity, proactive enforcement +
  retroactive validation, universal (not AEF-specific).

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: [component-fabric, architecture, enforcement, topology, universal]
related_tasks: [T-120, T-130, T-190]
created: 2026-02-19T09:56:36Z
last_update: 2026-02-19T09:56:36Z
date_finished: null
---

# T-191: Component Fabric — structural topology system for codebase self-awareness

## Problem Statement

As AEF-governed codebases grow, the **cost of understanding the system for any change approaches the cost of the change itself**. The framework has excellent temporal memory (tasks, episodic, handovers — what happened and when) but almost no spatial memory (what exists, where, how it connects). To understand any component, an agent must read the code, trace dependencies manually, and hope CLAUDE.md's conceptual descriptions are current.

This problem is acute for:
- **Bug investigation**: tracing trigger chains across hooks, scripts, and UI without a dependency map
- **Impact analysis**: knowing what breaks when a component changes, without grepping every file
- **UI development**: agents cannot observe user interaction; UI elements and flows must be machine-readable
- **Onboarding**: fresh agents/sessions need the system's shape in seconds, not minutes of reading
- **Regression tracing**: connecting a commit to its downstream effects structurally, not manually

**For whom:** All agents and humans working on any project governed by AEF.
**Why now:** At ~50 scripts, 1 web UI, 15+ agents, the framework is approaching the complexity threshold. Building this now means it grows WITH the system rather than being retrofitted.

## Assumptions

1. A structural topology (component + dependency registry) provides more navigation value than enhanced grep/search
2. Adaptive granularity (file-level default, deeper where earned) avoids over-documentation
3. UI elements and interaction flows CAN be made machine-readable without visual rendering
4. Retroactive validation (cron-based drift detection) is sufficient alongside proactive enforcement
5. The overhead of maintaining component registration is low enough to not impede development velocity
6. This can be file-based and portable (D4) — no infrastructure dependencies

## Exploration Plan

This inception spans 5-10 sessions. Research artifacts saved to `docs/reports/T-191-cf-*.md`.

### Phase 1: Research & Landscape (Sessions 1-2)
- **1a.** Web research: existing approaches to architectural knowledge management, living documentation, dependency tracking in AI-assisted development. Save to `docs/reports/T-191-cf-research-landscape.md`.
- **1b.** Analyze AEF's own codebase: map the current topology manually for one subsystem (e.g., budget management chain). Document what information is needed and what's missing. Save to `docs/reports/T-191-cf-aef-topology-sample.md`.
- **1c.** Research UI component documentation patterns: how frameworks (Storybook, design systems) make UI elements machine-readable. Save to `docs/reports/T-191-cf-research-ui-patterns.md`.

### Phase 2: Use Case Deep Dives (Sessions 3-4)
- **2a.** For each of the 6 use cases (navigate, impact, UI identify, onboard, regress, completeness), define: what query does the agent ask? What data structure answers it? What's the minimum viable schema?
- **2b.** Interview/discuss with human: prioritize use cases, validate scenarios with real examples from our history.
- **2c.** Synthesize use case requirements into a requirements doc. Save to `docs/reports/T-191-cf-requirements.md`.

### Phase 3: Data Model & Granularity Design (Sessions 5-6)
- **3a.** Design the component card schema (what fields, what's required vs optional, how granularity escalation works).
- **3b.** Design the dependency graph model (edges: calls, triggers, reads, writes, renders, listens).
- **3c.** Design the UI element model (identity, interaction flows, API mappings).
- **3d.** Prototype: manually create component cards for 5-10 AEF components, test against use cases. Save to `docs/reports/T-191-cf-data-model.md`.

### Phase 4: Enforcement & Tooling Design (Sessions 7-8)
- **4a.** Design enforcement points: what gates/hooks ensure new components are registered?
- **4b.** Design retroactive validation: cron-based drift detection, orphan component scanning.
- **4c.** Design querying: how agents ask questions of the topology (`fw fabric query "what calls checkpoint.sh?"`).
- **4d.** Design adaptive granularity triggers: what signals promote a component from coarse to detailed documentation?
- **4e.** Save to `docs/reports/T-191-cf-enforcement-design.md`.

### Phase 5: Decision & Build Plan (Sessions 9-10)
- **5a.** Synthesize all research and design into a final architecture proposal.
- **5b.** Identify build tasks (decompose into implementable units).
- **5c.** Go/No-Go decision with full evidence chain.
- **5d.** Save to `docs/reports/T-191-cf-architecture-proposal.md`.

## Technical Constraints

- Must be file-based (D4 Portability) — no vector databases, no external services
- Must work for ANY project using AEF, not just the framework repo itself
- Must be deterministic (D2 Reliability) — topology queries return consistent results
- Must not significantly increase session context consumption (agent reads component cards on-demand, not all at once)
- Must handle multiple languages (bash, python, JavaScript, HTML/CSS, YAML)

## Scope Fence

**IN scope:**
- Component registry data model and schema
- Dependency tracking (code, data, event, UI flows)
- UI element identification and interaction flow documentation
- Enforcement mechanisms (proactive + retroactive)
- Querying/discovery interface for agents
- Adaptive granularity model
- Universal design (any AEF-governed project)

**OUT of scope:**
- Implementing the full system (this is inception — build tasks come after GO)
- Auto-generating topology from static analysis (may be a build task, but research the approach first)
- Visual diagram rendering (Mermaid etc. is a presentation choice, not the core model)
- Integration with external tools (IDEs, CI/CD — future enhancement)

## Acceptance Criteria

- [ ] Problem statement validated with concrete examples from AEF history
- [ ] All 6 assumptions tested with evidence
- [ ] Use cases validated with real scenarios
- [ ] Data model prototyped and tested against use cases
- [ ] Enforcement model designed with both proactive and retroactive mechanisms
- [ ] UI element model designed and validated
- [ ] All research persisted in docs/reports/T-191-cf-*.md (minimum 5 documents)
- [ ] Architecture proposal documented with build task decomposition
- [ ] Go/No-Go decision made with full rationale

## Go/No-Go Criteria

**GO if:**
- A file-based, low-overhead topology model demonstrably answers all 6 use cases
- The enforcement overhead is proportional to the value (doesn't slow development)
- The adaptive granularity model works in prototype (coarse → detailed progression)
- UI element identification is feasible without visual rendering

**NO-GO if:**
- The minimum viable schema is too complex for agents to maintain alongside development
- File-based approach can't handle the query patterns needed (would require a database)
- The overhead of registration exceeds the value of navigation for small/medium projects
- UI flows can't be documented in a way agents can reliably reason about

## Verification

test -f docs/reports/T-191-cf-research-landscape.md
test -f docs/reports/T-191-cf-requirements.md
test -f docs/reports/T-191-cf-data-model.md
test -f docs/reports/T-191-cf-architecture-proposal.md

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
