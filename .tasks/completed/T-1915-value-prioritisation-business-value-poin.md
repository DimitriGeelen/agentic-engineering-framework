---
id: T-1915
name: "value-prioritisation: Business Value Points — directive-weighted prioritisation
  for tasks and arcs (HANDOFF-value-prioritisation-2026-05-15)"
description: >
  Inception: value-prioritisation: Business Value Points — directive-weighted prioritisation
  for tasks and arcs (HANDOFF-value-prioritisation-2026-05-15)

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: [inception, value-drivers, bvp, prioritisation, handoff-ingested]
components: [lib/arc.sh, web/blueprints/arcs.py, agents/audit/audit.sh, 
      CLAUDE.md, FRAMEWORK.md, 005-DesignDirectives.md, 
      .tasks/templates/zzz-default.md, .context/arcs/]
related_tasks: [T-1641, T-1653, T-1668, T-1816, T-1846, T-1849, T-1852, T-1854]
arc_id: value-prioritisation
created: 2026-05-18T22:55:05Z
last_update: '2026-08-16T22:24:48Z'
date_finished: '2026-05-19T06:52:17Z'
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 7
      tier: 4
      effort: 7
    rationale: blast_radius=7 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-20T12:30:23Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:03Z'
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
  - ts: '2026-08-16T22:24:48Z'
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
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1915: value-prioritisation: Business Value Points — directive-weighted prioritisation for tasks and arcs (HANDOFF-value-prioritisation-2026-05-15)

## Problem Statement

Prioritisation in AEF today happens through `horizon` (now/next/later) and arc focus — neither scores work against the four Constitutional Directives (Antifragility, Reliability, Usability, Portability). `fw arc list` returns alpha-by-filename; there is no mechanism to rank arcs against each other, and within an arc there is no way to order constituent tasks by directive-impact. The four directives live as prose in CLAUDE.md and FRAMEWORK.md but have no machine-readable scoring scaffold — they cannot drive prioritisation, promotion, or resource allocation. Trigger: AEF self-assessment against the ACMM maturity model surfaced both the directive-scoring gap and arc-vs-arc ranking gap; Dimitri's 2019 Business Value Points blog post provides a near-fit mechanic.

**Full research artefact:** `.context/handoffs/HANDOFF-value-prioritisation-2026-05-15.md` (§1–§12; this task is T-NEW-1 from that handoff).

## Assumptions

Six load-bearing assumptions (handoff §4a). A1 (arc-grooming dependency) is verified at filing; A2 is verifiable now via `fw audit`; A3/A4/A5/A6 are deferred to build slices for measurement.

- **A1** — HANDOFF-arc-grooming-2026-05-15 reaches §5 GO AND first deliverable ships. **STATUS: VERIFIED at filing** (decision: GO in `.context/arcs/arc-grooming.yaml`; `arc_id:` in `.tasks/templates/zzz-default.md`; four-state lifecycle `ARC_STATES=("draft" "in-progress" "closed" "abandoned")` in `lib/arc.sh`).
- **A2** — Adding new task-frontmatter and arc-YAML fields (`bvp_scores`, `bvp_scores_proposed`, `cost_estimate`, `scoped_drivers`, `proposed_scoped_drivers`) does not break audit YAML-parse. *Verifiable now via T-NEW-3 spike (fw audit on hand-edited task with `bvp_scores:`).*
- **A3** — TermLink can run a continuous low-temperature `bvp-estimator` worker at <5s + <2k tokens per task. *Measured during T-NEW-7 build.*
- **A4** — At arc creation time, the primary agent has enough conversation context to propose meaningful arc-scoped drivers. *Evaluated after first 3 arcs use the workflow.*
- **A5** — Humans will use `fw arc show-suggestions` when arc focus shifts. *Reviewed at next handover cycle (3 months).*
- **A6** — Composite cost formula (0.6 × blast_radius + 0.3 × tier + 0.1 × effort) produces useful quadrant placement. *Reviewed after 30 days of operation.*

Register via:
```
bin/fw assumption add "..." --task T-1915
```

## Exploration Plan

This inception's job is **decision-making, not building**. Per handoff §7 T-NEW-1, the scope is:

1. **Resolve Q1–Q4 with the human** (handoff §6). All four have agent defaults; humans confirm or override.
2. **Record decisions** in research artefact at `docs/reports/T-1915-bvp-inception.md` with timestamps.
3. **Produce the constituent build-task breakdown** (T-NEW-2 through T-NEW-15 from handoff §7) as concrete `fw task create` invocations ready to run after decide-go.
4. **Land decide-go transition** via Watchtower form on the `value-prioritisation` arc YAML (created here as anchor in `draft` state, flips to `in-progress` only after BVP system ships its own `fw arc approve-driver` gate — T-NEW-10).

**Time-box:** 1 session for Q1–Q4 dialogue + decision capture. The build slices (T-NEW-2..15) are filed separately *after* decide-go, not during this inception.

## Technical Constraints

- BVP is **advisory, not gating**. Scoring does not block task save, task promotion, or arc creation. The only new gate this inception authorises is `draft → in-progress` driver-decision, itself satisfiable via `--none --justification` (mirrors §ACD bypass shape).
- **No replacement** of `fw arc close --demo` discipline (§ACD T-1668). BVP is additive.
- **Single-repo scope.** No cross-repo drivers or scoring.
- **Four directives are protected** — D1 (Antifragility, weight 9), D2 (Reliability, 7), D3 (Usability, 5), D4 (Portability, 3). Removal verbs must refuse on D1–D4.
- **§ACD agent-gate** must be reused for `fw bvp weight` and `fw arc approve-driver`: refuse under `$CLAUDECODE=1` unless `--i-am-human` or `--from-watchtower`; require `--rationale` (≥30 chars).
- **Auto-promote off by default.** D8: editing `auto_promote.enabled: true` in `policy/value-drivers.yaml` is the human's Sovereignty exercise; framework then enforces the pre-authorised rule.

## Scope Fence

**IN scope for this inception:**
- Decide Q1 (free drivers globally visible vs campaign-scoped)
- Decide Q2 (cost fallback for tasks without blast_radius — T-shirt vs unknown)
- Decide Q3 (`fw arc abandon` auto-trigger for LV/HC quadrant — none vs Watchtower passive)
- Decide Q4 (TermLink estimator SLA during `fw resume` — 10s default)
- File `value-prioritisation` arc shell in `draft` state with T-1915 as anchor
- Produce T-NEW-2..15 build-task breakdown ready to fire

**OUT of scope (deferred to build slices, owned by other tasks):**
- Implementing any of T-NEW-2..15 (those are separate build tasks, filed after decide-go)
- Touching arc lifecycle state machine (owned by HANDOFF-arc-grooming-2026-05-15)
- Cross-repo BVP scoring
- Cost inputs beyond F8's three signals (blast_radius, tier, effort)
- Replacing `fw arc close --demo`

## Open Questions (Q1–Q4)

To be resolved with the human via Watchtower review surface or `fw task review T-1915`:

- **Q1 — Free drivers: globally visible vs campaign-scoped?** Agent default: globally visible always; temporal scoping handled as a weight-change pattern (D9's audit-trail covers it).
- **Q2 — Cost fallback when blast_radius unknown: T-shirt vs "unknown"?** Agent default: T-shirt fallback (S=2, M=4, L=6, XL=8); auto-recompute from real `blast_radius` after first commit.
- **Q3 — `fw arc abandon` auto-trigger for LV/HC quadrant: auto vs Watchtower passive?** Agent default: no auto-trigger; surface as Watchtower recommendation with one-click pre-filled action. Sovereignty stays with the human.
- **Q4 — TermLink estimator SLA during `fw resume`: how many seconds?** Agent default: 10s hard cap; on timeout, task resumes flagged `unscored: true`, async sweep picks it up.

## Proposed Build-Task Breakdown (post decide-go)

Per handoff §7. Each maps to a separate `fw task create --type build` invocation, filed AFTER `fw inception decide T-1915 go`. Dependencies between them are documented in the handoff.

- **T-NEW-2** — `policy/value-drivers.yaml` schema + initial content (protected D1–D4, free-driver section, auto_promote off)
- **T-NEW-3** — Task + arc frontmatter schema extensions (`bvp_scores`, `bvp_scores_proposed`, `cost_estimate`, `scoped_drivers`, `proposed_scoped_drivers`)
- **T-NEW-4** — `fw bvp` read-only CLI verbs (rank, detail, arcs, --quadrant)
- **T-NEW-5** — `fw bvp weight` + `fw bvp driver` mutating verbs + weight history audit
- **T-NEW-6** — Scoring rubric document (`policy/bvp-scoring-rubric.md`)
- **T-NEW-7** — TermLink `bvp-estimator` worker (needs-split: 7a harness+trigger, 7b sweep+resume fallback)
- **T-NEW-8** — `fw bvp confirm` verb
- **T-NEW-9** — Document primary-agent arc-scoped-driver suggestion workflow
- **T-NEW-10** — `fw arc approve-driver` + `fw arc show-suggestions` verbs
- **T-NEW-11** — Per-driver coherence audit check
- **T-NEW-12** — Watchtower `/bvp` tab (needs-split: 12a static scatter, 12b live sliders)
- **T-NEW-13** — Watchtower `/arcs/<id>` extensions (BVP display, coherence warnings, approve buttons)
- **T-NEW-14** — Opt-in auto-promote policy gate (needs-split: 14a logic+log, 14b enabling+trigger)
- **T-NEW-15** — Canonical doc `040-ValueDrivers.md` + FRAMEWORK.md glossary/Quick Reference updates

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

**GO if:**
- A1 (arc-grooming dependency) is verified — decision: GO in `.context/arcs/arc-grooming.yaml`, `arc_id:` in template, four-state lifecycle in `lib/arc.sh` (all VERIFIED at filing).
- §11.5 pre-action checks pass — cited paths exist, no newer supersedes, A2 plausible (verifiable in T-NEW-3 spike).
- The four directives (D1–D4) remain the protected drivers; weights 9/7/5/3 reflect priority order.
- The BVP system is additive — no replacement of `fw arc close --demo` or any existing gate.
- Q1–Q4 have human-confirmed answers (or human accepts agent defaults).

**NO-GO if:**
- Arc-grooming dependency is not satisfied (would already have blocked filing).
- Q1–Q4 cannot reach a resolution and the human declines to accept defaults.
- A2 fails when tested (audit YAML-parse rejects unknown fields) — would require a schema-update prerequisite slice the handoff doesn't yet author.

**DEFER if:**
- BVP infrastructure cost (TermLink worker A3, rubric quality A4) is deemed too speculative without an MVP measurement step first — in which case file a narrower T-NEW-7 spike under a separate inception.

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

HANDOFF-value-prioritisation-2026-05-15 §5 verdict GO-WITH-MODIFICATIONS. The 'modification' is external sequencing (depends_on_handoffs: HANDOFF-arc-grooming-2026-05-15), which is now satisfied: arc-grooming reached §5 GO and shipped its first deliverable (arc_id field landed in .tasks/templates/zzz-default.md, four-state lifecycle in lib/arc.sh ARC_STATES, decide-go recorded in .context/arcs/arc-grooming.yaml). §11.5 pre-action checks all PASS — cited paths exist, no newer supersedes, A1 verified. Inception scope: resolve Q1-Q4 with human, record decisions in research artefact, and produce constituent build-task slices (T-NEW-2..15 from the handoff). BVP is greenfield (F2), additive (no replacement of existing mechanics), and reuses §ACD gate shape (F6) — the design has clear runway. Inception triggers fire per §12 (>3 new files, new policy/ subsystem, new CLI verbs, new TermLink worker, new canonical doc) — not bypassable to direct build.

**Evidence:**

- Handoff saved verbatim at `.context/handoffs/HANDOFF-value-prioritisation-2026-05-15.md` (1280+ lines, §1–§12)
- §11.5 dual-condition check PASS: `decision: "GO ..."` in `.context/arcs/arc-grooming.yaml`; `arc_id:` field present in `.tasks/templates/zzz-default.md`; `ARC_STATES=("draft" "in-progress" "closed" "abandoned")` in `lib/arc.sh:67`
- Cited paths verified extant: `005-DesignDirectives.md`, `010-TaskSystem.md`, `FRAMEWORK.md`, `lib/arc.sh`, `web/blueprints/arcs.py`, `agents/audit/audit.sh`
- No newer handoff supersedes this one (single grep match is the handoff itself)
- F2 confirmed: directives have no machine-readable scoring scaffold today (greenfield)
- F6 reuse opportunity: §ACD gate shape at `lib/arc.sh:430-468` and `:473-492` is the template for `fw arc approve-driver` and `fw bvp weight`
- §12 inception triggers fire: >3 new files (policy/, audit logs, canonical doc, Watchtower blueprint, TermLink worker), new subsystem (policy/), multiple new CLI verbs, schema additions, novel auto-promote policy-as-code gate
- 4 open Q's documented with agent defaults (Q1: globally visible; Q2: T-shirt fallback; Q3: passive Watchtower surface; Q4: 10s SLA)

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

### 2026-05-18T22:57:29Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9bbbd247
- **Timestamp:** 2026-06-02T15:00:26Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
