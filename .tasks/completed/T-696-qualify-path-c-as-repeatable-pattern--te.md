---
id: T-696
name: "Qualify Path C as repeatable pattern — template + second experiment"
description: >
  Inception: Qualify Path C as repeatable pattern — template + second experiment

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: [T-679, T-678, T-549, T-124]
created: 2026-03-29T07:51:25Z
last_update: 2026-04-13T06:23:24Z
date_finished: 2026-03-29T07:58:45Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-696: Qualify Path C as repeatable pattern — template + second experiment

## Problem Statement

Path C (external codebase ingestion) has been proven once on vnx-orchestration (T-678/T-679) with 10 friction points found, 8 fixed. But it exists only as a research report — not as a codified, repeatable pattern. A new agent starting a deep-dive would need to read a 107-line report, understand TermLink, and reconstruct the workflow from scratch.

**For whom:** Any agent (or human) wanting to analyze an external codebase under framework governance.
**Why now:** T-679 GO decision was made 2026-03-28. The workflow is fresh, corrections are documented, and friction fixes are deployed. Codifying now preserves institutional knowledge before it decays.

## Assumptions

A-1: A task template is sufficient to make Path C repeatable (vs. a full `fw ingest` CLI command)
A-2: TermLink is a hard requirement — no non-TermLink fallback needed
A-3: The T-679 workflow is complete — no missing phases or steps
A-4: A second experiment on a different repo will validate the template without major new friction

## Exploration Plan

1. **Spike 1: Template design** (~30 min) — Draft a `.tasks/templates/path-c-deep-dive.md` template with pre-filled phases, TermLink commands, and checkboxes. Compare against existing templates (`zzz-default.md`, onboarding templates).

2. **Spike 2: Gap analysis** (~20 min) — Walk through the T-679 workflow doc and identify any steps that are implicit/tribal vs. explicit. Check if all 8 fixed friction points are actually deployed.

3. **Spike 3: Second experiment design** (~15 min) — Select a candidate external repo. Define what "clean execution" means (success criteria for the template test).

## Technical Constraints

- TermLink required (spawn, interact, inject, signal, clean)
- Target repo must be cloneable locally (SSH or HTTPS)
- Framework hooks must survive in consumer project (settings.json)
- `fw init --force` must work on existing non-framework repos

## Scope Fence

**IN scope:**
- Task template for Path C deep-dives
- Gap analysis of current workflow doc
- Candidate selection for second experiment
- Go/no-go on template approach vs. CLI command

**OUT of scope:**
- Building `fw ingest` CLI command (that would be a build task if GO)
- Actually running the second experiment (separate task)
- TermLink product changes (T-682)
- Fixing remaining friction points F-4, F-6

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested (A-1: template sufficient YES, A-2: TermLink hard req YES, A-3: workflow complete with 7 minor gaps, A-4: second experiment feasible)
- [x] Recommendation written with rationale
- [x] Task template created: `.tasks/templates/path-c-deep-dive.md`
- [x] Research artifact: `docs/reports/T-696-path-c-qualification.md`

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read the research artifact and recommendation in this task
  2. Evaluate go/no-go criteria against findings
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-XXX go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Template captures all 3 phases with explicit, copy-pasteable commands
- Gap analysis reveals no missing steps that would block a fresh agent
- A suitable second experiment candidate exists
- Template approach is cheaper than CLI command and still repeatable

**NO-GO if:**
- Template is too complex (>100 lines of instructions, agent would need tribal knowledge anyway)
- Gap analysis reveals fundamental workflow issues that invalidate T-679
- TermLink dependency makes Path C impractical for most users

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: Template approach approved — codify Path C as repeatable pattern, run second experiment to validate

**Date**: 2026-03-29T07:58:45Z

## Recommendation

- **Recommendation:** GO
- **Rationale:** Template approach is correct — cheap, flexible, captures all 3 phases with copy-pasteable commands. Gap analysis found 7 implicit steps in T-679 doc, all addressed in template. Friction fixes verified deployed. Second experiment needed as separate follow-up task.
- **Evidence:**
  - Template created: `.tasks/templates/path-c-deep-dive.md` (3 phases, 8 key rules, friction log)
  - T-679 gap analysis: 7 gaps found, all documentable, none blocking
  - Friction fixes F-1/F-7 and F-9 verified in code
  - Research artifact: `docs/reports/T-696-path-c-qualification.md`

## Decision

**Decision**: GO

**Rationale**: Template approach approved — codify Path C as repeatable pattern, run second experiment to validate

**Date**: 2026-03-29T07:58:45Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-29T07:52:32Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-29T07:58:45Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Template approach approved — codify Path C as repeatable pattern, run second experiment to validate

### 2026-03-29T07:58:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-06T22:29:21Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-28156e4a
- **Timestamp:** 2026-06-02T15:04:24Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
