---
id: T-1925
name: "BVP T-NEW-9: document primary-agent arc-scoped-driver suggestion workflow in CLAUDE.md + AGENTS.md (D5/D6, R5 mitigation)"
description: >
  Documentation slice — defines the workflow primary agents follow when an arc is created: after body is filled but before driver approval, agent reads body and proposes arc-scoped drivers to proposed_scoped_drivers:. R5 mitigation — "manufacturing drivers is worse than proposing zero" verbatim in docs.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [bvp, build, slice-9, docs]
components: [CLAUDE.md, AGENTS.md]
related_tasks: [T-1915, T-1916, T-1918]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-19T07:00:00Z
date_finished: null
---

# T-1925: BVP T-NEW-9 — arc-scoped-driver suggestion workflow docs

## Context

No CLI verb here — pure documentation slice. Sets the workflow primary agents follow.

**Source:** Handoff §7 T-NEW-9; artefact §6 row 9; §2 R5 (manufactured-drivers failure mode); §4 D5 (timing), D6 (asymmetric caps), D7-reframe (`fw arc show-suggestions` is a workflow verb, not debug).

**R5 mitigation lands here** — the "manufacturing drivers is worse than proposing zero" sentence must appear verbatim.

## Acceptance Criteria

### Agent
- [ ] CLAUDE.md gains a new section under arc management documenting the suggestion workflow (5 steps from D5)
- [ ] AGENTS.md mirrors the workflow for non-Claude agent providers
- [ ] Both docs include the verbatim sentence: "Manufacturing drivers to look thorough is worse than proposing zero and recommending --none."
- [ ] Both docs include the D6 quality criterion: "Rationale must explain what each driver distinguishes that globals don't."
- [ ] Both docs surface `fw arc show-suggestions` as a workflow verb the human uses when arc focus shifts (D7-reframe — not a debug verb)
- [ ] Worked example included: a hypothetical arc with 2-3 plausible scoped drivers + their rationales

## Verification

grep -q "proposed_scoped_drivers" CLAUDE.md
grep -q "proposed_scoped_drivers" AGENTS.md
grep -q "manufacturing" CLAUDE.md
grep -q "manufacturing" AGENTS.md

## Decisions

## Updates
