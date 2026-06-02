---
id: T-1300
name: "Pickup: Ambient strip pattern (T-1117..T-1121) — single-source linked status chrome worth codifying as framework default (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink. Type: feature-proposal.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [pickup, feature-proposal]
components: []
related_tasks: []
created: 2026-04-18T15:21:53Z
last_update: 2026-04-22T05:19:28Z
date_finished: 2026-04-22T05:19:28Z
---

# T-1300: Pickup: Ambient strip pattern (T-1117..T-1121) — single-source linked status chrome worth codifying as framework default (from termlink)

## Problem Statement

Termlink's T-1117..T-1121 arc enhanced its base.html ambient strip into fully-linked operator chrome (focus→/tasks/id, audit→/quality, attention→/tasks, fleet→/fleet, project→/project). Pickup proposes adopting this as a framework default. See `docs/reports/T-1300-ambient-strip-codification.md`.

## Assumptions

1. The framework's base.html has an ambient strip — TESTED TRUE (web/templates/base.html:315-331, 5 spans)
2. The existing spans are NOT linked — TESTED TRUE (plain `<span>` elements)
3. The fleet indicator from termlink applies here — TESTED FALSE (this machine isn't a fleet node; no fleet data source)

## Exploration Plan

10-min time-box (done):
- Grep base.html for ambient-strip skeleton — DONE
- Compare framework spans to termlink's proposal — DONE
- Assess operational cost of missing links — DONE (no operator complaints recorded)

## Technical Constraints

None — pure UI polish; `url_for()` is already in scope for blueprints.

## Scope Fence

**IN:** decision on whether to link the 5 existing ambient-strip spans.
**OUT:** fleet indicator (framework isn't a fleet node); broader navigation refactor; copying termlink's CSS verbatim.

## Acceptance Criteria

### Agent
- [x] Problem statement validated (pickup has concrete prior art in termlink commits; framework has partial implementation)
- [x] Assumptions tested (2 true, 1 false — fleet doesn't apply here)
- [x] Recommendation written with rationale (DEFER — polish, not functional gap)

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** DEFER

**Rationale:** The framework's ambient strip is already functional. Making elements clickable is UX polish, not a functional gap. No operator has complained about needing clicks where spans stand today. Fleet indicator (termlink's novel piece) doesn't apply here — this machine isn't a fleet node. Budget is better spent on real bugs. Revisit when an operator complains or a second project reports the same pain.

**Evidence:**
- `web/templates/base.html:315-331` renders 5 ambient-strip spans (focus, session, audit, attention, project-root) — plain text, not links
- No issue in concerns.yaml or learnings.yaml flags navigation friction caused by unlinked ambient strip
- Fleet dot piece needs a fleet endpoint the framework doesn't have
- Small-scope fallback exists if reconsidered: wrap each span in `<a href="{{ url_for(...) }}">` (~5-line edit)
- Full triage: `docs/reports/T-1300-ambient-strip-codification.md`

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

**Decision**: DEFER

**Rationale**: Recommendation: DEFER

Rationale: The framework's ambient strip is already functional. Making elements clickable is UX polish, not a functional gap. No operator has complained about needing clicks where spans stand today. Fleet indicator (termlink's novel piece) doesn't apply here — this machine isn't a fleet node. Budget is better spent on real bugs. Revisit when an operator complains or a second project reports the same pain.

Evidence:
- `web/templates/base.html:315-331` renders 5 ambient-strip spans (focus, session, audit, attention, project-root) — plain text, not links
- No issue in concerns.yaml or learnings.yaml flags navigation friction caused by unlinked ambient strip
- Fleet dot piece needs a fleet endpoint the framework doesn't have
- Small-scope fallback exists if reconsidered: wrap each span in `<a href="{{ url_for(...) }}">` (~5-line edit)
- Full triage: `docs/reports/T-1300-ambient-strip-codification.md`

**Date**: 2026-04-19T08:59:03Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-19T08:19:52Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-19T08:59:03Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Recommendation: DEFER

Rationale: The framework's ambient strip is already functional. Making elements clickable is UX polish, not a functional gap. No operator has complained about needing clicks where spans stand today. Fleet indicator (termlink's novel piece) doesn't apply here — this machine isn't a fleet node. Budget is better spent on real bugs. Revisit when an operator complains or a second project reports the same pain.

Evidence:
- `web/templates/base.html:315-331` renders 5 ambient-strip spans (focus, session, audit, attention, project-root) — plain text, not links
- No issue in concerns.yaml or learnings.yaml flags navigation friction caused by unlinked ambient strip
- Fleet dot piece needs a fleet endpoint the framework doesn't have
- Small-scope fallback exists if reconsidered: wrap each span in `<a href="{{ url_for(...) }}">` (~5-line edit)
- Full triage: `docs/reports/T-1300-ambient-strip-codification.md`

### 2026-04-22T05:19:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-35d20d9b
- **Timestamp:** 2026-06-02T14:56:33Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
