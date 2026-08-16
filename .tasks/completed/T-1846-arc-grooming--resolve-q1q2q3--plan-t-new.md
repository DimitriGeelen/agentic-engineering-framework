---
id: T-1846
name: "Arc grooming — resolve Q1/Q2/Q3 + plan T-NEW-2..9 build slices"
description: >
  Inception: Arc grooming — resolve Q1/Q2/Q3 + plan T-NEW-2..9 build slices

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: [inception, governance, schema-migration]
components: ["lib/arc.sh", "web/blueprints/arcs.py", "agents/audit/audit.sh", ".tasks/templates/default.md",
  "FRAMEWORK.md"]
related_tasks: ["T-1641", "T-1653", "T-1661", "T-1662", "T-1668", "T-1671", "T-1816",
  "T-1817"]
arc_id: arc-grooming
created: 2026-05-15T12:43:57Z
last_update: '2026-08-16T22:24:46Z'
date_finished: 2026-05-15T14:49:04Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:00Z'
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
  - ts: '2026-08-16T22:24:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1846: Arc grooming — resolve Q1/Q2/Q3 + plan T-NEW-2..9 build slices

## Problem Statement

The Arc primitive (T-1653 design → T-1661 build → T-1662 Watchtower) is operational but left
eight design questions parked, three of which now block downstream work that wants to score
arcs and rank tasks within arcs (HANDOFF-value-prioritisation-2026-05-15 depends on this).
Arc is also absent from the numbered canonical doc set: `FRAMEWORK.md` has **zero** arc
mentions; there is no `012-ArcSystem.md`. Two parallel sources of "tasks in arc X" exist
today (`tags: [arc:*]` on task frontmatter vs `constituent_tasks:` on arc YAML — only one
of four arcs populates the latter, and `arc_show` ignores it); lifecycle has only
two states implemented (no `draft`, no `abandoned`); no stale-arc audit, no anchor-task
existence check.

The full research artefact lives at `.context/handoffs/HANDOFF-arc-grooming-2026-05-15.md`
and at `docs/reports/T-1846-arc-grooming-inception.md` (dialogue log). This task is the
inception that resolves three open governance questions (Q1, Q2, Q3) and produces nine
build-task slices (T-NEW-2..9 in the handoff) as concrete `fw task create` invocations
before any build work commences.

## Assumptions

A1 — The four currently-in-progress arcs are quiescent enough during the migration window.
  Verified: `git log --since="1 hour ago" .tasks/` shows only T-1845 completion churn,
  no `arc:*`-tagged-task editing.

A2 — Adding `arc_id:` and new lifecycle states does not break audit YAML-parse.
  Verified: `grep -rn 'unknown.*field\|schema.*reject' agents/audit/ web/blueprints/`
  returned zero hits.

A3 — `lib/arc.sh` writes status at file-creation, not load-time computation.
  Verified: `lib/arc.sh:232: status: in-progress` is the literal heredoc/template write.

A4 — Framework-agent briefing accurate as of 2026-05-15.
  Verified: three citations spot-checked verbatim — `lib/arc.sh:215-227` (T-1816 YAML
  quoting), `lib/arc.sh:473-492` (§ACD `--demo` gate), `agents/audit/audit.sh:550-555`
  (T-1816 arc YAML parse).

Register additional via `fw assumption add` if new ones surface during Q1/Q2/Q3 dialogue.

## Exploration Plan

1. **Surface Q1/Q2/Q3 to human via `fw task review T-1846`** (Watchtower) — agent does
   NOT act on the documented defaults. Human is the decision-maker.
2. **Capture answers** in `docs/reports/T-1846-arc-grooming-inception.md` `## Dialogue Log`
   with timestamps.
3. **Produce the build slice manifest** — a runnable checklist of `fw task create`
   (and/or `fw work-on --type build`) invocations for T-NEW-2..9, each with title,
   tags, components, related_tasks, dependencies, and a one-line `## Acceptance Criteria`
   stub matching the handoff §7. Output stored as `## Build Slice Manifest` section
   in the inception artefact.
4. **Optionally** spot-check the 3 multi-arc-tagged tasks discovered during §11.5
   (Q3 prevalence) to scope the human's case-by-case resolution.
5. **`fw inception decide T-1846 go --rationale "..."`** only after Q1/Q2/Q3 are
   recorded as final (not provisional).

Time-box: 2 hours for steps 1-4 once Q1/Q2/Q3 answers received. Step 1 (review hand-off)
is the next agent action.

## Technical Constraints

- §ACD enforcement (`--demo` on close, agent-gate under `$CLAUDECODE=1`) must remain
  untouched by any work this inception authorises.
- Single refactor of `lib/arc.sh` state machine — both new states (`draft`, `abandoned`)
  land together to avoid touching the state machine twice (D2).
- Existing four in-progress arcs stay `in-progress` — no force-migration of their state (D3).
- Migration script (T-NEW-3) must be idempotent: running it twice produces no further
  changes the second time.
- `lib/arc.sh:232` is the literal status write — changes to `arc_create` template affect
  only new arcs.

## Scope Fence

**IN scope:**
- Resolve Q1 (arc_id validation tier), Q2 (committable migration report), Q3 (multi-arc
  tag handling) with the human.
- Produce the build-slice manifest for T-NEW-2..9.
- Create the arc YAML at `.context/arcs/arc-grooming.yaml` as the workspace for the
  slices (post-decide-go).

**OUT of scope:**
- Implementing any of T-NEW-2..9 (those are separate build tasks, filed AFTER decide-go).
- Resolving the other five parked T-1653 questions (multi-arc focus Q5, prompt injection
  Phase B Q6, arc nesting Q7-other, decisions cross-linking Q8, anchor-task-as-board-state).
  Those stay parked in `docs/reports/T-1653-arcs-as-first-class.md`.
- Any value-driver / scoring / prioritisation mechanic — that is a separate handoff
  (HANDOFF-value-prioritisation-2026-05-15) and a separate inception.
- The `draft → in-progress` driver-decision GATE (the value-prioritisation work's job).
  This inception adds the `draft` STATE; the gate that polices entry/exit is downstream.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested (A1, A2, A3, A4 verified in §11.5 pre-action checks; recorded
      in Problem Statement / Assumptions sections)
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale
- [x] Research artefact exists at `docs/reports/T-1846-arc-grooming-inception.md`
      (created at filing time; updated as dialogue produces findings — C-001 discipline)
- [x] Handoff stored verbatim at `.context/handoffs/HANDOFF-arc-grooming-2026-05-15.md`
- [x] Q1, Q2, Q3 answers recorded in research artefact `## Dialogue Log` with timestamps
      (Q1=Tier-1 block, Q2=committable report, Q3=delegated → both T-1717/T-1719 →
      `arc_id: embeddings-strategy`)
- [x] Build-slice manifest produced in research artefact `## 4 Build-slice manifest`
      with 10 slices (T-NEW-1.5 + T-NEW-2..9), each carrying type, dependencies,
      one-line scope; concrete `fw task create` invocations remain to be authored
      per slice at filing time post decide-go
- [x] **D-Immutability** structural principle captured (§3a) — arc records are
      immutable like task records; abandonment is a status; arc IDs never renumber

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw task review T-1846`
     (opens Watchtower with recommendation, the full handoff, and Q1/Q2/Q3)
  2. Answer each of Q1, Q2, Q3 — defaults from the handoff are listed alongside
     each question; explicit choice required, not just acceptance-of-default
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, Q1/Q2/Q3 answers captured in the inception artefact
  **If not:** Ask agent for clarification on specific findings or to re-scope

## Go/No-Go Criteria

**GO if:**
- Human answers Q1, Q2, Q3 with explicit choices (defaults OK if human accepts them)
- Build-slice manifest (T-NEW-2..9) is concrete and runnable: each slice has title,
  tags, components, related_tasks, dependencies, and stub ACs traceable to handoff §7
- Pre-action checks §11.5 still hold at decide-go time (no drift in cited paths,
  arc statuses, or assumption verifications)

**NO-GO if:**
- Q3 reveals materially more multi-arc-tagged tasks than the §11.5 scan suggested (3),
  enough to make case-by-case resolution unrealistic
- Pre-action check A2 (schema-reject) fails on re-verification — would require an
  audit-schema slice to precede T-NEW-2 and balloons scope
- Human declines either of the new states (`draft`, `abandoned`) — would invalidate
  D2 single-refactor decision

**DEFER if:**
- A1 (quiescent window) cannot be guaranteed at execution time — wait for next quiet
  window
- HANDOFF-value-prioritisation-2026-05-15 is not yet ready and human prefers to scope
  both together

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

**Recommendation:** GO

**Rationale:**

Per HANDOFF-arc-grooming-2026-05-15 §5 GO with §11.5 pre-action checks all PASS: 12 paths exist, T-1653/1661/1662 work-completed, 4 arcs in-progress, A1-A4 hold (citations at lib/arc.sh:215-227, 473-492; audit.sh:550-555 match briefing verbatim), only 3 multi-arc-tagged tasks (Q3 trivially resolvable). §12 triggers fire (>3 new files, fw arc abandon verb, tags->arc_id schema migration) so this MUST be inception. Scope: resolve Q1/Q2/Q3 with human, then file T-NEW-2..9 as build slices. No build artefacts before decide-go.

**Evidence:**

- Full research artefact: `.context/handoffs/HANDOFF-arc-grooming-2026-05-15.md`
- Inception dialogue artefact: `docs/reports/T-1846-arc-grooming-inception.md`
- §11.5 pre-action checks all PASS (paths, task statuses, A1-A4, tools).
- F1: `grep -c -i 'arc' FRAMEWORK.md` returns 0 (canonical doc gap confirmed)
- F2 evidence cross-link: L-371 (denormalised registry cache anti-pattern from T-1817)
  surfaced by `fw work-on` knowledge retrieval — directly supports D1 deprecation.
- F3 evidence: `lib/arc.sh:232: status: in-progress` (literal status write at create time;
  A3 confirmed)
- F4 evidence: no stale-arc check in `agents/audit/audit.sh`; T-1816 only adds YAML-parse
  validation
- F6 verified: dispatch-safety, orchestrator-rethink, embeddings-strategy,
  project-shape-resilience all `status: in-progress`
- F8 verified: `lib/arc.sh:473-492` is the §ACD `--demo` gate verbatim
- Q3 prevalence: 3 multi-arc-tagged tasks across `.tasks/{active,completed}/`
  (small enough to handle case-by-case in T-NEW-3's report)

## Decisions

### 2026-05-15 — D-Immutability (arc records never deleted)

- **Chose:** Arc YAML records in `.context/arcs/` are immutable. Abandonment is a
  status update on the `status:` field; the file persists. Arc IDs (once allocated
  via T-NEW-1.5) are never renumbered, never reused.
- **Why:** Matches existing task semantics (tasks in completed/ are never deleted).
  Preserves cross-arc traceability (G-064 closure pilots, predecessor chains).
  Eliminates the deleted-arc cascade failure mode that drove the original
  audit-warning-only stance on Q1.
- **Rejected:** Allow deletion via `fw arc delete` or rm — would break references
  retroactively and create unfixable hostage states for any task pointing at the
  deleted arc.
- **Edge case acknowledged:** Truly-mistaken-creation-zero-references — manual rm
  is acceptable when nothing yet points at it; once referenced, `fw arc abandon`.
- **Decided-by:** human-initiated, agent-agreed
- **Operationalises:** Q1 flip to Tier-1 block, T-NEW-1.5, T-NEW-5a, T-NEW-6
- **Reversibility:** costly (loosening immutability later is theoretically possible
  but would invalidate the validation contract this enables)

### 2026-05-15 — Q1 flip: Tier-1 block (not audit warning)

- **Chose:** `arc_id:` referencing a non-existent arc → Tier-1 block at task save.
- **Why:** Predicated on D-Immutability. With immutability, valid references stay
  valid forever; the original handoff fear (deleted-arc cascade creates hostage
  state) cannot occur. Block-on-save gives faster feedback and structural rather
  than 30-min-cron enforcement.
- **Rejected:** Audit warning (original handoff §6 default). Superseded by
  D-Immutability changing the cost calculus.
- **Decided-by:** human
- **Operationalises:** T-NEW-2 validation hook
- **Reversibility:** cheap (loosen to warning is a one-config flip)

### 2026-05-15 — T-NEW-1.5 added: sequential arc-NNN IDs

- **Chose:** Adopt `arc-NNN` sequential immutable IDs for arcs (matching task ID
  model). Add as T-NEW-1.5 slice in the build manifest.
- **Why:** Slug-as-identity breaks on rename and on intentional name reuse. Sequential
  IDs match how tasks work (T-NNNN, never renumbered). Bounded migration cost
  (4 existing arcs map to arc-001..004).
- **Rejected:** Keep slug-as-identity — simpler short term, but the rename brittleness
  and the lack of D-Immutability anchor undermine validation guarantees.
- **Decided-by:** human-initiated, agent-agreed
- **Operationalises:** identity stability for D-Immutability; gives T-NEW-2 a stable
  validation target
- **Reversibility:** moderate (renaming back to slug-as-identity post-allocation
  would require coordinated rewrite across `lib/arc.sh`, Watchtower routing,
  any task already migrated)

### 2026-05-15 — Q3 per-task: T-1717 and T-1719 → arc_id: embeddings-strategy

- **Chose:** Both dual-arc-tagged tasks get `arc_id: embeddings-strategy` as
  canonical home. Cross-link to orchestrator-rethink survives via the
  `G-064-closure-pilot` regular tag and existing `related_tasks` chain.
- **Why:** Read both task bodies — T-1717 is "Embeddings generation strategy for
  context and component fabric" (workflow_type: inception); pain points are all
  retrieval-related; components touched are embeddings-substrate hooks. T-1719
  is the explicit `T-1717-implementation` build slice. Both are embeddings-strategy
  work that happens to advance orchestrator-rethink's G-064 closure.
- **Rejected:** Alphabetical-auto (would land same answer accidentally — fine, but
  for principled reasons not the alphabet). Block-and-ask-human (delegated to
  agent by human). Add secondary_arc_ids field (scope creep).
- **Decided-by:** agent (delegated by human "you decide")
- **Reversibility:** cheap (post-migration edit of frontmatter)

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-15T12:46:53Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-21cd6ae1
- **Timestamp:** 2026-06-02T14:59:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
