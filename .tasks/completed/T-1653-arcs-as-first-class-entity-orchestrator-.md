---
id: T-1653
name: "Arcs as first-class entity (orchestrator-rethink follow-up)"
description: >
  Arcs as first-class entity (orchestrator-rethink follow-up)

status: work-completed
workflow_type: inception
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-05-01T13:31:01Z
last_update: '2026-06-11T22:23:54Z'
date_finished: 2026-05-01T17:08:58Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:54Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1653: Arcs as first-class entity (orchestrator-rethink follow-up)

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
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
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO Phase 1

**Rationale:** Six explicit user requirements + a partially-shadow-implemented model (umbrella tasks + free-form tags + per-task focus) make this a *refactor*, not a green-field design. Phase 1 MVP is ~4h, fully reversible, no new dependencies. The seven design questions (Q1–Q7) all have low-risk recommended answers — see research artefact `docs/reports/T-1653-arcs-as-first-class.md`. Phase 2 (`/arcs` page, arc-specific CLAUDE.md snippets) can land later or be dropped.

**Evidence:**
- Six concrete user requirements captured verbatim in the artefact dialogue log (2026-05-01)
- Existing facilities table shows the gaps are small: namespace convention for tags, arc-level focus state, prompt-injection line, landing-page section, `/tasks?arc=` filter chip
- Migration scope is one arc (`orchestrator-rethink`, seeded from T-1641's related_tasks) — proving the shape before generalising

**Phase 1 MVP scope (~4h):**

1. **Data model:** `.context/arcs/<arc-id>.yaml` with `id, name, description, status (in-progress|closed|abandoned), anchor_task, constituent_tasks: [], created, closed_at, decision`.
2. **CLI:** `bin/fw arc {create|focus|list|show|close|tag}` (7 verbs, ~150 lines bash).
3. **Tag namespace:** canonical `arc:<arc-id>`; legacy `from-T-XXXX` stays one release as alias.
4. **Prompt injection:** extend `agents/handover/handover.sh` to add `## Current Arc` line; SessionStart resume picks it up.
5. **Watchtower:** "Arcs in flight" section on landing page above active tasks; `/tasks?arc=<id>` filter chip with discoverable arc list.
6. **Migration:** auto-create `orchestrator-rethink` arc from T-1641, seed `constituent_tasks` from T-1641/T-1644 `related_tasks`.

**Out of MVP scope (Phase 2, file separately if/when needed):** dedicated `/arcs` page (replaces `/orchestrator`); arc-specific CLAUDE.md snippets; multi-arc focus stack (rejected — start single).

**Full design artefact** (Q1–Q7 alternatives matrix, rejected options, dialogue log): `docs/reports/T-1653-arcs-as-first-class.md`

**Decision options:**
1. **GO Phase 1** — proceed with MVP as described
2. **GO with modifications** — adjust any of Q1–Q7 first (see artefact)
3. **NO-GO** — keep arcs implicit; iterate `/orchestrator` differently
4. **DEFER** — interesting, not now

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

**Decision**: GO

**Rationale**: Recommendation: GO Phase 1

Rationale: Six explicit user requirements + a partially-shadow-implemented model (umbrella tasks + free-form tags + per-task focus) make this a refactor, not a green-field design. Phase 1 MVP is ~4h, fully reversible, no new dependencies. The seven design questions (Q1–Q7) all have low-risk recommended answers — see research artefact `docs/reports/T-1653-arcs-as-first-class.md`. Phase 2 (`/arcs` page, arc-specific CLAUDE.md snippets) can land later or be dropped.

Evidence:
- Six concrete user requirements captured verbatim in the artefact dialogue log (2026-05-01)
- Existing facilities table shows the gaps are small: namespace convention for tags, arc-level focus state, prompt-injection line, landing-page section, `/tasks?arc=` filter chip
- Migration scope is one arc (`orchestrator-rethink`, seeded from T-1641's related_tasks) — proving the shape before generalising

Phase 1 MVP scope (~4h):

1. Data model: `.context/arcs/<arc-id>.yaml` with `id, name, description, status (in-progress|closed|abandoned), anchor_task, constituent_tasks: [], created, closed_at, decision`.
2. CLI: `bin/fw arc {create|focus|list|show|close|tag}` (7 verbs, ~150 lines bash).
3. Tag namespace: canonical `arc:<arc-id>`; legacy `from-T-XXXX` stays one release as alias.
4. Prompt injection: extend `agents/handover/handover.sh` to add `## Current Arc` line; SessionStart resume picks it up.
5. Watchtower: "Arcs in flight" section on landing page above active tasks; `/tasks?arc=<id>` filter chip with discoverable arc list.
6. Migration: auto-create `orchestrator-rethink` arc from T-1641, seed `constituent_tasks` from T-1641/T-1644 `related_tasks`.

Out of MVP scope (Phase 2, file separately if/when needed): dedicated `/arcs` page (replaces `/orchestrator`); arc-specific CLAUDE.md snippets; multi-arc focus stack (rejected — start single).

Full design artefact (Q1–Q7 alternatives matrix, rejected options, dialogue log): `docs/reports/T-1653-arcs-as-first-class.md`

Decision options:
1. GO Phase 1 — proceed with MVP as described
2. GO with modifications — adjust any of Q1–Q7 first (see artefact)
3. NO-GO — keep arcs implicit; iterate `/orchestrator` differently
4. DEFER — interesting, not now

**Date**: 2026-05-01T17:08:58Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-01T17:08:58Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO Phase 1

Rationale: Six explicit user requirements + a partially-shadow-implemented model (umbrella tasks + free-form tags + per-task focus) make this a refactor, not a green-field design. Phase 1 MVP is ~4h, fully reversible, no new dependencies. The seven design questions (Q1–Q7) all have low-risk recommended answers — see research artefact `docs/reports/T-1653-arcs-as-first-class.md`. Phase 2 (`/arcs` page, arc-specific CLAUDE.md snippets) can land later or be dropped.

Evidence:
- Six concrete user requirements captured verbatim in the artefact dialogue log (2026-05-01)
- Existing facilities table shows the gaps are small: namespace convention for tags, arc-level focus state, prompt-injection line, landing-page section, `/tasks?arc=` filter chip
- Migration scope is one arc (`orchestrator-rethink`, seeded from T-1641's related_tasks) — proving the shape before generalising

Phase 1 MVP scope (~4h):

1. Data model: `.context/arcs/<arc-id>.yaml` with `id, name, description, status (in-progress|closed|abandoned), anchor_task, constituent_tasks: [], created, closed_at, decision`.
2. CLI: `bin/fw arc {create|focus|list|show|close|tag}` (7 verbs, ~150 lines bash).
3. Tag namespace: canonical `arc:<arc-id>`; legacy `from-T-XXXX` stays one release as alias.
4. Prompt injection: extend `agents/handover/handover.sh` to add `## Current Arc` line; SessionStart resume picks it up.
5. Watchtower: "Arcs in flight" section on landing page above active tasks; `/tasks?arc=<id>` filter chip with discoverable arc list.
6. Migration: auto-create `orchestrator-rethink` arc from T-1641, seed `constituent_tasks` from T-1641/T-1644 `related_tasks`.

Out of MVP scope (Phase 2, file separately if/when needed): dedicated `/arcs` page (replaces `/orchestrator`); arc-specific CLAUDE.md snippets; multi-arc focus stack (rejected — start single).

Full design artefact (Q1–Q7 alternatives matrix, rejected options, dialogue log): `docs/reports/T-1653-arcs-as-first-class.md`

Decision options:
1. GO Phase 1 — proceed with MVP as described
2. GO with modifications — adjust any of Q1–Q7 first (see artefact)
3. NO-GO — keep arcs implicit; iterate `/orchestrator` differently
4. DEFER — interesting, not now

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d74f26fb
- **Timestamp:** 2026-06-02T14:58:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-01T17:08:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
