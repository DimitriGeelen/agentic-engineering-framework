---
id: T-1925
name: "BVP T-NEW-9: document primary-agent arc-scoped-driver suggestion workflow in CLAUDE.md + AGENTS.md (D5/D6, R5 mitigation)"
description: >
  Documentation slice — defines the workflow primary agents follow when an arc is created: after body is filled but before driver approval, agent reads body and proposes arc-scoped drivers to proposed_scoped_drivers:. R5 mitigation — "manufacturing drivers is worse than proposing zero" verbatim in docs.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [bvp, build, slice-9, docs]
components: [CLAUDE.md, AGENTS.md]
related_tasks: [T-1915, T-1916, T-1918]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-19T07:44:00Z
date_finished: 2026-05-19T07:44:00Z
---

# T-1925: BVP T-NEW-9 — arc-scoped-driver suggestion workflow docs

## Context

No CLI verb here — pure documentation slice. Sets the workflow primary agents follow.

**Source:** Handoff §7 T-NEW-9; artefact §6 row 9; §2 R5 (manufactured-drivers failure mode); §4 D5 (timing), D6 (asymmetric caps), D7-reframe (`fw arc show-suggestions` is a workflow verb, not debug).

**R5 mitigation lands here** — the "manufacturing drivers is worse than proposing zero" sentence must appear verbatim.

## Acceptance Criteria

### Agent
- [x] CLAUDE.md gains a new §Arc-Scoped Driver Suggestion Workflow (T-1925, arc-006) documenting the 5-step workflow under §Agent Behavioral Rules (placed adjacent to §Arc Completion Discipline)
- [x] AGENTS.md mirrors the workflow inline (single section appended before FRAMEWORK.md pointer)
- [x] Both docs include the verbatim sentence: "Manufacturing drivers to look thorough is worse than proposing zero and recommending --none."
- [x] Both docs include the D6 quality criterion: "Rationale must explain what each driver distinguishes that globals don't."
- [x] Both docs surface `fw arc show-suggestions` as a workflow verb (D7-reframe) — explicitly framed as "workflow verb the human runs when focus shifts to an arc, not a debug verb"
- [x] Worked example included in both docs: hypothetical `replay-debug` arc with 3 plausible candidate drivers (determinism/replay-fidelity/forensic-detail) AND 3 bad candidates (reliability/usability/correctness) for contrast

## Verification

grep -q "proposed_scoped_drivers" CLAUDE.md
grep -q "proposed_scoped_drivers" AGENTS.md
grep -qi "manufacturing" CLAUDE.md
grep -qi "manufacturing" AGENTS.md

## Evolution

### 2026-05-19 — Bad-candidates anti-example added beyond AC
- **What changed:** AC asked for "2-3 plausible scoped drivers". Added a deliberate anti-example pair (`reliability/usability/correctness`) showing what NOT to propose — these duplicate global D1-D4 and would dilute scoring. R5 mitigation gets stronger with contrast.
- **Plan impact:** None — strictly additive. The anti-example anchors the verbatim "Manufacturing drivers..." rule in concrete shape.
- **Triggered:** None.

## Recommendation

**Recommendation:** GO

**Rationale:** Documentation slice ships. 6/6 Agent ACs satisfied; 4/4 Verification commands pass. Both CLAUDE.md and AGENTS.md carry the 5-step workflow, R5 verbatim rule, D6 quality criterion, `fw arc show-suggestions` workflow-verb framing, and worked example with positive + negative candidates. Establishes the protocol primary agents follow when arc focus shifts.

**Evidence:**
- `grep -q "proposed_scoped_drivers" CLAUDE.md` → match
- `grep -q "proposed_scoped_drivers" AGENTS.md` → match
- `grep -q "manufacturing" CLAUDE.md` → match (verbatim R5 sentence)
- `grep -q "manufacturing" AGENTS.md` → match (same)
- `grep -q "what each driver distinguishes that globals don't"` → match in both
- `grep -q "fw arc show-suggestions"` → match in both (workflow-verb framing)
- `grep -q "replay-debug"` → match in both (worked example anchor)

Unlocks: T-1926 (CLI for `fw arc show-suggestions`/`approve-driver` — docs already cite it as a workflow verb).

## Decisions

## Updates

### 2026-05-19T07:41:20Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a8b2b38e
- **Timestamp:** 2026-06-02T15:00:30Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-19T07:44:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
