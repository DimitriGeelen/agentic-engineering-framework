---
id: T-1905
name: "Watchtower /arcs kanban — feature parity with /tasks (more fields, inline editing,
  filters)"
description: >
  Inception: Watchtower /arcs kanban — feature parity with /tasks (more fields, inline
  editing, filters)

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-05-18T19:42:03Z
last_update: '2026-05-19T21:45:04Z'
date_finished: '2026-05-18T21:09:38Z'
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1905: Watchtower /arcs kanban — feature parity with /tasks (more fields, inline editing, filters)

## Problem Statement

**For whom:** the human, when reviewing the /arcs kanban.

**What:** T-1904 shipped a 4-column lifecycle kanban replacing T-1853 tabs. User followed up: cards should show more status fields, be inline-editable like `/tasks`, support filtering, and have a see-all view. The just-shipped kanban is layout-complete but feature-thin compared to `/tasks`.

**Why now:** the kanban just shipped — momentum is right to scope the polish slice before context drifts.

**Research artefact:** [docs/reports/T-1905-arcs-kanban-feature-parity.md](../../docs/reports/T-1905-arcs-kanban-feature-parity.md) — full inventory of `/tasks` features, mapping to arc data model, status transition matrix, and 4-slice decomposition.

## Assumptions

1. The `inline_select` Jinja macro at `web/templates/_partials/inline_select.html` is structurally reusable for arc cards (proves at slice-2).
2. Arc status transitions can be safely gated client-side by limiting the `<select>` options — closed/abandoned require server-side enforcement too (proves at slice-3).
3. Slice-3 cannot ship without T-1902 (`/arcs/<slug>/close`) because clicking "close" in an inline-status select must route there, not POST a direct status flip.

## Exploration Plan

Inventory completed in research artefact. Validated assumptions structurally:

- ✅ `inline_select` is reusable — already used 8 times across `/tasks` kanban + table views
- ✅ `lib/arc.sh` has CLI verbs for every transition we'd surface (`fw arc focus`, `fw arc abandon`, `fw arc close --from-watchtower`)
- ✅ Slice-3 depends on T-1902 — design is "redirect to close-surface, do not flip" → T-1902 must ship first

No prototype needed at inception phase; build slices are concrete enough to estimate.

## Technical Constraints

- T-1848 D-Immutability: arc `id`, `slug`, `created` fields are never editable post-creation
- T-1671 §ACD: closing an arc is a strategic decision routed through the T-1902 close-review surface — never a direct inline edit
- T-1855: stale-arc badge (already present on cards) derives from constituent-task commit timestamps via `arc_id:` frontmatter (NOT `tags:[arc:...]`, post-T-1850)
- Slice-3 (inline status select) is structurally blocked until T-1902 ships

## Scope Fence

**IN scope:**
- Four ordered build slices (T-1906 read-only enrichment, T-1907 inline name + focus toggle, T-1908 inline status with gated transitions, T-1909 filters + see-all view) — see research artefact for details

**OUT of scope:**
- Bulk arc operations (per-arc decisions warrant per-arc UI)
- Inline editing of `decision` / `headline_mechanic` (decision-level fields, not data fields)
- Auto-status-flip rules (separate inception)
- Changing T-1671 §ACD or T-1848 D-Immutability axioms

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
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

**Recommendation:** DEFER

**Rationale:**

User followed up on T-1904 (just-shipped 4-column kanban): wants the arc cards to mirror /tasks card capability — more status fields visible, inline editing same as /tasks, filtering UI, and the ability to see all arcs (not just one state). T-1904 shipped the layout; this scopes the next slice: what fields, what inline edits make sense for arcs (status flip? focus toggle? close-decision?), what filters (by task count, by stale, by recent activity). DEFER because feature parity with /tasks is multiple discrete capabilities — needs decomposition into ordered build slices (probably 3-4) with user input on which matter most. Inception explores: (a) inventory /tasks card features, (b) which apply to arcs structurally (e.g. arc has no started-work vs captured distinction; arc-close is gated by T-1671 so inline-close is structurally illegal), (c) propose 3-4 build slices in priority order.

**Evidence:**

<!-- Add evidence bullets as exploration progresses (file paths,
     commit hashes, test results). The filing-time recommendation
     can be revised before fw inception decide. -->

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

### 2026-05-18T19:43:03Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
